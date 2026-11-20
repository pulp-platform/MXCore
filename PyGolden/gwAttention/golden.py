# Copyright 2026 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

import contextlib
import io
import tempfile
from pathlib import Path

import numpy as np

from PyGolden import utils, fp_functions  # noqa: F401
from PyGolden import mxcore_gemm_functions as mg
from PyGolden.fp9 import FP9
from PyGolden.scale import Scale
from PyGolden.mxcore_utils import quantize_bf16, quantize_mx_segments

VS, MXU, OBUFF, BLK = 32, 32, 64, 32
MX_FMT = "FP8"


def bf16_bits(values):
    raw = np.asarray(values, dtype=np.float32).view(np.uint32)
    lsb = (raw >> 16) & 1
    return (((raw + 0x7FFF + lsb) >> 16) & 0xFFFF).astype(np.uint16)


def bf16_to_float(bits):
    return (np.asarray(bits, dtype=np.uint16).astype(np.uint32) << 16).view(np.float32)


def gather_a(x):
    m, k = x.shape
    return np.ascontiguousarray(x.reshape(m // OBUFF, OBUFF, k // VS, VS).transpose(0, 2, 1, 3)).reshape(-1)


def ungather_a(flat, m, k):
    return np.ascontiguousarray(flat.reshape(m // OBUFF, k // VS, OBUFF, VS).transpose(0, 2, 1, 3)).reshape(m, k)


def gather_b(x):
    n, k = x.shape
    return np.ascontiguousarray(x.reshape(n // MXU, MXU, k // VS, VS).transpose(0, 2, 1, 3)).reshape(-1)


def ungather_b(flat, n, k):
    return np.ascontiguousarray(flat.reshape(n // MXU, k // VS, MXU, VS).transpose(0, 2, 1, 3)).reshape(n, k)


def ungather_a_scale(flat, m, k):
    return np.ascontiguousarray(flat.reshape(m // OBUFF, k // VS, OBUFF).transpose(0, 2, 1)).reshape(m, k // VS)


def ungather_b_scale(flat, n, k):
    return np.ascontiguousarray(flat.reshape(n // MXU, k // VS, MXU).transpose(0, 2, 1)).reshape(n, k // VS)


def result_to_rowmajor(flat, m, n):
    return np.ascontiguousarray(flat.reshape(m // OBUFF, n // MXU, OBUFF, MXU).transpose(0, 2, 1, 3)).reshape(m, n)


def rowmajor_to_result(x):
    m, n = x.shape
    return np.ascontiguousarray(x.reshape(m // OBUFF, OBUFF, n // MXU, MXU).transpose(0, 2, 1, 3)).reshape(-1)


def _lines_to_bytes(lines):
    out = []
    for line in lines:
        word = int(line, 16)
        out += [(word >> (8 * i)) & 0xFF for i in range(4)]
    return np.asarray(out, dtype=np.uint8)


def mx_quantize_bf16(flat_bf16):
    words = (np.asarray(flat_bf16, dtype=np.uint16).astype(np.uint32) << 16).tolist()
    segments = [words[i:i + BLK] for i in range(0, len(words), BLK)]
    lines = quantize_mx_segments(segments, MX_FMT, BLK, False, 4)
    n_data = len(words) // 4
    return _lines_to_bytes(lines[:n_data]), _lines_to_bytes(lines[n_data:])[:len(segments)]


def _fp9_rows(data, scale):
    fp9 = [[FP9(MX_FMT, f"{int(x):08b}0") for x in r] for r in data]
    sc = [[Scale(int(x) - 127) for x in r] for r in scale]
    return fp9, sc


def mxcore_gemm_bf16(a_data, a_scale, b_data, b_scale, m, k, n):
    a, sa = _fp9_rows(ungather_a(a_data, m, k), ungather_a_scale(a_scale, m, k))
    b, sb = _fp9_rows(ungather_b(b_data, n, k), ungather_b_scale(b_scale, n, k))
    tmp = Path(tempfile.mkdtemp())
    mg.MEMORY_EXPORT = True
    with contextlib.redirect_stdout(io.StringIO()):
        mg.mxcore_gemm(a, list(map(list, zip(*b))), sa, list(map(list, zip(*sb))),
                       hardware_vector_size=VS, vector_size=VS, num_compute_units=MXU,
                       num_out_buffers=OBUFF, BLOCK_SIZE=BLK, mem_file=tmp / "mem.txt",
                       res_file=tmp / "res.txt", res_mx_file=tmp / "res_mx.txt",
                       header_path=tmp / "data.h")
    words = [int(w, 16) for w in (tmp / "res.txt").read_text().split()]
    return np.asarray([quantize_bf16(w) for w in words], dtype=np.uint16)


def softmax_ref(s_bf16_rowmajor):
    s = bf16_to_float(s_bf16_rowmajor).astype(np.float64)
    e = np.exp(s - s.max(axis=1, keepdims=True))
    return e / e.sum(axis=1, keepdims=True)


class AttentionGolden:

    def __init__(self, sq, sk, d):
        assert sq % OBUFF == 0 and sk % MXU == 0 and sk % OBUFF == 0 and d % MXU == 0 and d % OBUFF == 0
        self.sq, self.sk, self.d = sq, sk, d
        shift = np.log2(np.sqrt(d))
        assert shift == int(shift), "1/sqrt(d) must be a power of two (a shift of the E8M0 scales of Q)"
        self.scale_shift = int(shift)

    def operands(self, q, k, v):
        q_g, k_g, vt_g = gather_a(q), gather_b(k), gather_b(np.ascontiguousarray(v.T))
        out = {"q_bf16": q_g, "k_bf16": k_g, "vt_bf16": vt_g}
        for name, g in (("q", q_g), ("k", k_g), ("vt", vt_g)):
            out[f"{name}_mx"], out[f"{name}_scale"] = mx_quantize_bf16(g)
        out["q_scale_scores"] = (out["q_scale"].astype(np.int16) - self.scale_shift).astype(np.uint8)
        return out

    def scores(self, ops):
        return mxcore_gemm_bf16(ops["q_mx"], ops["q_scale_scores"], ops["k_mx"], ops["k_scale"],
                                self.sq, self.d, self.sk)

    def probabilities_ref(self, s_flat):
        return softmax_ref(result_to_rowmajor(s_flat, self.sq, self.sk))

    def quantize_p(self, p_flat):
        return mx_quantize_bf16(p_flat)

    def output(self, p_mx, p_scale, ops):
        return mxcore_gemm_bf16(p_mx, p_scale, ops["vt_mx"], ops["vt_scale"], self.sq, self.sk, self.d)

    def output_ref(self, p_rowmajor, v):
        return p_rowmajor @ bf16_to_float(v).astype(np.float64)
