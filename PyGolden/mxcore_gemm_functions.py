import numpy as np
from math import isclose, isnan, isinf, ceil
from mpmath import mp
import sys
import struct
from .fp9 import *
from .fp_accumulator import *
from .scale import *
from .utils import *
from .mxcore_utils import *
from .mxcore_utils import _acc_to_fp32_u32, extend_vector_bytes_for_header, bits_to_hex_lines
from .norm_round import *
from .fp_functions import *
from .globals import get_constants

MEMORY_EXPORT = True

def mxcore_gemm(fp9_matrix_a, fp9_matrix_b, scale_matrix_a, scale_matrix_b, hardware_vector_size=8, vector_size=8, num_compute_units=8, num_out_buffers=4, data_type="FP8", acc_data_type="FP32", BLOCK_SIZE=32, result_mx_block_size=None, memory_data_width=32, mem_file=None, res_file=None, res_mx_file=None, header_path=None, allow_fp9_special_values=False, set_max_fp9=False, set_min_fp9=False, scale_range=[-127, 128], is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, use_external_data=False, dataflow_file=None, mem_debug_file=None, preload_matrix=None, block_poison_enable=False):
    """
    Compute the vector-matrix multiplication of FP9 values

    Args:
        a (2d list): Matrix of fp9 values of size M x K
        b (2d list): Matrix of fp9 values of size K x N
        scale_a (2d list): Scales for Matrix A (M x K/BlockSize)
        scale_b (2d list): Scales for Matrix B (K/BlockSize x N)
        vector_size (int): Vector size handled by each MXDOTP unit in MXCore
        num_compute_units (int): Number of compute units in MXCore
        num_out_buffers (int): Output reuse factor of MXCore

    Returns:
        c (2d list): The output matrix of fp32 values of size M x N.
    """

    constants = get_constants(hardware_vector_size)
    sop_increments = [vector_size]
    if result_mx_block_size is None:
        result_mx_block_size = BLOCK_SIZE

    print("Computing the Matrix-Matrix Multiplication...")
    print(f"Configuration: VS = {hardware_vector_size}, #MXU = {num_compute_units}, #OBuff = {num_out_buffers}")
    print(f"Matrix A: {len(fp9_matrix_a)} x {len(fp9_matrix_a[0])}, Matrix B: {len(fp9_matrix_b)} x {len(fp9_matrix_b[0])}, Scale A: {len(scale_matrix_a)} x {len(scale_matrix_a[0])}, Scale B: {len(scale_matrix_b)} x {len(scale_matrix_b[0])}")

    # Compute using the MXCore datapath
    mdim = len(fp9_matrix_a)
    kdim = len(fp9_matrix_a[0])
    ndim = len(fp9_matrix_b[0])
    result_matrix = [[FPAccumulator(value=0.0, data_type=acc_data_type) for _ in range(ndim)] for _ in range(mdim)]
    row_starts = range(0, mdim, num_out_buffers)
    col_starts = range(0, ndim, num_compute_units)

    trace = []  # dataflow trace: one entry per (M-tile, N-tile, K-chunk)

    for row_start in row_starts:
        for col_start in col_starts:
            accumulator = [[FPAccumulator(value=0.0, data_type=acc_data_type) for _ in range(num_compute_units)] for _ in range(num_out_buffers)]
            if preload_matrix is not None:
                rows_t = min(num_out_buffers, mdim - row_start)
                cols_t = min(num_compute_units, ndim - col_start)
                for i in range(rows_t):
                    for j in range(cols_t):
                        accumulator[i][j] = preload_matrix[row_start + i][col_start + j]
            partial_products = [[FPAccumulator(value=0.0, data_type=acc_data_type) for _ in range(num_compute_units)] for _ in range(num_out_buffers)]

            k_start = 0
            sop_inc_idx = 0
            while k_start < kdim:
                inc = sop_increments[sop_inc_idx % len(sop_increments)]
                sop_inc_idx += 1
                if k_start + inc > kdim:
                    inc = kdim - k_start

                scale_idx = k_start // BLOCK_SIZE
                matrix_chunk_a = [fp9_matrix_a[row_start + i][k_start:k_start + inc] for i in range(min(num_out_buffers, mdim - row_start))]
                matrix_chunk_b = [[fp9_matrix_b[k_start + k][col_start + j] for k in range(inc)] for j in range(min(num_compute_units, ndim - col_start))]
                rows_in_tile = len(matrix_chunk_a)
                cols_in_tile = len(matrix_chunk_b)
                # Snapshot accumulator state before this K-chunk's partial products
                acc_in_snap = [[accumulator[i][j] for j in range(cols_in_tile)] for i in range(rows_in_tile)]
                sa_snap = [scale_matrix_a[row_start + i][scale_idx] for i in range(rows_in_tile)]
                sb_snap = [scale_matrix_b[scale_idx][col_start + j] for j in range(cols_in_tile)]
                for i in range(len(matrix_chunk_a)):
                    for j in range(len(matrix_chunk_b)):
                        partial_products[i][j] = sum_fp9_sop_fp32(
                            constants,
                            matrix_chunk_a[i],
                            matrix_chunk_b[j],
                            accumulator[i][j],
                            scale_matrix_a[row_start + i][scale_idx],
                            scale_matrix_b[scale_idx][col_start + j],
                            data_type=data_type,
                            acc_data_type=acc_data_type,
                        )
                # Snapshot partial products after this K-chunk for the trace
                acc_out_snap = [[partial_products[i][j] for j in range(cols_in_tile)] for i in range(rows_in_tile)]
                trace.append({
                    'row_start': row_start, 'col_start': col_start,
                    'k_start': k_start, 'k_end': k_start + inc,
                    'scale_idx': scale_idx,
                    'matrix_chunk_a': matrix_chunk_a,
                    'matrix_chunk_b': matrix_chunk_b,
                    'scales_a': sa_snap, 'scales_b': sb_snap,
                    'acc_input': acc_in_snap, 'acc_output': acc_out_snap,
                })
                accumulator = [row[:] for row in partial_products]
                k_start += inc

            for i in range(len(accumulator)):
                if row_start + i >= mdim:
                    break
                for j in range(len(accumulator[0])):
                    if col_start + j >= ndim:
                        break
                    result_matrix[row_start+i][col_start+j] = accumulator[i][j] 

    final_result = result_matrix

    if MEMORY_EXPORT:
        write_to_memory_file(
            fp9_matrix_a=fp9_matrix_a,
            fp9_matrix_b=fp9_matrix_b,
            scale_matrix_a=scale_matrix_a,
            scale_matrix_b=scale_matrix_b,
            result_matrix=final_result,
            preload_matrix=preload_matrix,
            data_type=data_type,
            acc_data_type=acc_data_type,
            vector_size=vector_size,
            num_compute_units=num_compute_units,
            num_out_buffers=num_out_buffers,
            memory_data_width=memory_data_width,
            BLOCK_SIZE=BLOCK_SIZE,
            result_mx_block_size=result_mx_block_size,
            mem_file=mem_file,
            res_file=res_file,
            res_mx_file=res_mx_file,
            mem_debug_file=mem_debug_file,
            block_poison_enable=block_poison_enable,
        )
        write_to_c_header(
            fp9_matrix_a=fp9_matrix_a,
            fp9_matrix_b=fp9_matrix_b,
            scale_matrix_a=scale_matrix_a,
            scale_matrix_b=scale_matrix_b,
            result_matrix=final_result,
            preload_matrix=preload_matrix,
            data_type=data_type,
            acc_data_type=acc_data_type,
            vector_size=vector_size,
            num_compute_units=num_compute_units,
            num_out_buffers=num_out_buffers,
            BLOCK_SIZE=BLOCK_SIZE,
            result_mx_block_size=result_mx_block_size,
            memory_data_width=memory_data_width,
            header_path=header_path,
            block_poison_enable=block_poison_enable,
        )

    if dataflow_file is not None:
        write_to_dataflow_debug(
            trace=trace,
            mdim=mdim, kdim=kdim, ndim=ndim,
            vector_size=vector_size,
            num_compute_units=num_compute_units,
            num_out_buffers=num_out_buffers,
            BLOCK_SIZE=BLOCK_SIZE,
            data_type=data_type,
            acc_data_type=acc_data_type,
            dataflow_file=dataflow_file,
        )


def write_to_memory_file(fp9_matrix_a, fp9_matrix_b, scale_matrix_a, scale_matrix_b, result_matrix, preload_matrix=None, data_type="FP8", acc_data_type="FP32", vector_size=8, num_compute_units=8, num_out_buffers=4, memory_data_width=32, BLOCK_SIZE=32, result_mx_block_size=None, mem_file=None, res_file=None, res_mx_file=None, mem_debug_file=None, block_poison_enable=False):
    mdim = len(fp9_matrix_a)
    kdim = len(fp9_matrix_a[0])
    ndim = len(fp9_matrix_b[0])
    num_chunks = ceil(kdim / vector_size)
    num_scale_blocks = ceil(kdim / BLOCK_SIZE)
    bytes_per_line = memory_data_width // 8
    bits_per_elem = 4 if data_type == "FP4" else 8

    memory_lines = []
    result_lines = []
    result_mx_lines = []

    row_tiles = list(range(0, mdim, num_out_buffers))
    col_tiles = list(range(0, ndim, num_compute_units))

    def rows_in_tile(row_start):
        return min(num_out_buffers, mdim - row_start)

    def cols_in_tile(col_start):
        return min(num_compute_units, ndim - col_start)

    if result_mx_block_size is None:
        result_mx_block_size = BLOCK_SIZE

    def pack_scale_bytes_to_lines(scale_binaries):
        lines = []
        for k in range(0, len(scale_binaries), bytes_per_line):
            word = scale_binaries[k:k+bytes_per_line]
            if len(word) < bytes_per_line:
                word += ['00000000'] * (bytes_per_line - len(word))
            binary = ''.join([b[-8:] for b in word[::-1]])
            lines.append(f"{int(binary, 2):08x}")
        return lines

    def pack_uint8_to_lines(byte_list):
        lines = []
        for k in range(0, len(byte_list), bytes_per_line):
            group = byte_list[k:k+bytes_per_line]
            while len(group) < bytes_per_line:
                group.append(0)
            word = sum(b << (8 * j) for j, b in enumerate(group))
            lines.append(f"{word:08x}")
        return lines

    # -------- Write Vectors A --------------- #
    for row_start in row_tiles:
        n_rows = rows_in_tile(row_start)
        for chid in range(num_chunks):
            actual_vs = min(vector_size, kdim - chid * vector_size)
            chunk_bins = []
            for i in range(n_rows):
                vec_a = fp9_matrix_a[row_start + i][chid*vector_size : chid*vector_size + actual_vs]
                chunk_bins.append(vec_to_bin(vec_a, data_type=data_type))

            vec_bits = actual_vs * bits_per_elem
            is_word_aligned = (vec_bits % memory_data_width == 0)

            if is_word_aligned:
                for bins in chunk_bins:
                    memory_lines.extend(vec_to_hex(bins, memory_data_width=memory_data_width))
            else:
                all_bits = ''.join(''.join(bins) for bins in chunk_bins)
                memory_lines.extend(bits_to_hex_lines(all_bits, memory_data_width=memory_data_width))

    # -------- Write Vectors B --------------- #
    for col_start in col_tiles:
        n_cols = cols_in_tile(col_start)
        for chid in range(num_chunks):
            actual_vs = min(vector_size, kdim - chid * vector_size)
            chunk_bins = []
            for j in range(n_cols):
                vec_b = [fp9_matrix_b[chid*vector_size + k][col_start + j] for k in range(actual_vs)]
                chunk_bins.append(vec_to_bin(vec_b, data_type=data_type))

            vec_bits = actual_vs * bits_per_elem
            is_word_aligned = (vec_bits % memory_data_width == 0)

            if is_word_aligned:
                for bins in chunk_bins:
                    memory_lines.extend(vec_to_hex(bins, memory_data_width=memory_data_width))
            else:
                all_bits = ''.join(''.join(bins) for bins in chunk_bins)
                memory_lines.extend(bits_to_hex_lines(all_bits, memory_data_width=memory_data_width))

    # -------- Write Scales A --------------- #
    for row_start in row_tiles:
        n_rows = rows_in_tile(row_start)
        all_scales = []
        for scale_idx in range(num_scale_blocks):
            for i in range(n_rows):
                all_scales.append(scale_matrix_a[row_start + i][scale_idx].binary)
        memory_lines.extend(pack_scale_bytes_to_lines(all_scales))

    # -------- Write Scales B --------------- #
    for col_start in col_tiles:
        n_cols = cols_in_tile(col_start)
        all_scales = []
        for scale_idx in range(num_scale_blocks):
            for j in range(n_cols):
                all_scales.append(scale_matrix_b[scale_idx][col_start + j].binary)
        memory_lines.extend(pack_scale_bytes_to_lines(all_scales))

    # -------- Write Preload Accumulator (if enabled) --------------- #
    if preload_matrix is not None:
        for row_start in row_tiles:
            for col_start in col_tiles:
                for i in range(rows_in_tile(row_start)):
                    for j in range(cols_in_tile(col_start)):
                        word = _acc_to_fp32_u32(preload_matrix[row_start + i][col_start + j])
                        memory_lines.append(f"{word:08x}")

    # ---------- Write FP32 Result Matrix -----------#
    for row_start in row_tiles:
        for col_start in col_tiles:
            for i in range(rows_in_tile(row_start)):
                for j in range(cols_in_tile(col_start)):
                    word = _acc_to_fp32_u32(result_matrix[row_start + i][col_start + j])
                    result_lines.append(f"{word:08x}")

    # ---------- Write MXFP8 Result Matrix -----------#
    mx_row_segments = []
    n_quantizer = max(1, num_compute_units // result_mx_block_size)
    for row_start in row_tiles:
        for col_start in col_tiles:
            n_cols = cols_in_tile(col_start)
            n_rows_t = rows_in_tile(row_start)
            for i in range(n_rows_t):
                row_idx = row_start + i
                for q in range(n_quantizer):
                    q_start = q * result_mx_block_size
                    q_cols = min(result_mx_block_size, n_cols - q_start)
                    segment = [_acc_to_fp32_u32(result_matrix[row_idx][col_start + q_start + j]) for j in range(q_cols)]
                    block_fp32 = segment + [0] * (result_mx_block_size - q_cols)
                    scale, poisoned = block_scale(block_fp32, data_type="FP8ALT" if data_type == "FP8ALT" else "FP8")
                    quantize_fn = quantize_e5m2 if data_type != "FP8ALT" else quantize_e4m3
                    nan_byte = 0x7D if data_type != "FP8ALT" else 0x7F
                    if poisoned and block_poison_enable:
                        quantized_all = [nan_byte] * len(block_fp32)
                    else:
                        quantized_all = [quantize_fn(v, scale) for v in block_fp32]
                    mx_row_segments.append((quantized_all[:q_cols], scale))

    all_mx_data = []
    all_mx_scales = []
    for row_bytes, scale in mx_row_segments:
        all_mx_data.extend(row_bytes)
        all_mx_scales.append(scale)
    result_mx_lines.extend(pack_uint8_to_lines(all_mx_data))
    result_mx_lines.extend(pack_uint8_to_lines(all_mx_scales))

    # ---------- Line Count Assertions -----------#
    def _compute_expected_lines():
        exp = {}
        a_lines = 0
        for rs in row_tiles:
            nr = rows_in_tile(rs)
            for chid in range(num_chunks):
                avs = min(vector_size, kdim - chid * vector_size)
                vb = avs * bits_per_elem
                if vb % memory_data_width == 0:
                    a_lines += nr * ceil(vb / memory_data_width)
                else:
                    a_lines += ceil(nr * vb / memory_data_width)
        b_lines = 0
        for cs in col_tiles:
            nc = cols_in_tile(cs)
            for chid in range(num_chunks):
                avs = min(vector_size, kdim - chid * vector_size)
                vb = avs * bits_per_elem
                if vb % memory_data_width == 0:
                    b_lines += nc * ceil(vb / memory_data_width)
                else:
                    b_lines += ceil(nc * vb / memory_data_width)
        sa_lines = sum(ceil(rows_in_tile(rs) * num_scale_blocks / bytes_per_line) for rs in row_tiles)
        sb_lines = sum(ceil(cols_in_tile(cs) * num_scale_blocks / bytes_per_line) for cs in col_tiles)
        preload_lines = mdim * ndim if preload_matrix is not None else 0
        exp['unpadded'] = a_lines + b_lines + sa_lines + sb_lines + preload_lines

        exp['result'] = mdim * ndim

        total_mx_bytes = sum(rows_in_tile(rs) * cols_in_tile(cs) for rs in row_tiles for cs in col_tiles)
        n_segments = sum(rows_in_tile(rs) * len(col_tiles) for rs in row_tiles) * n_quantizer
        exp['result_mx'] = ceil(total_mx_bytes / bytes_per_line) + ceil(n_segments / bytes_per_line)
        return exp

    exp = _compute_expected_lines()
    checks = [
        ("data_memory", len(memory_lines), exp['unpadded']),
        ("result FP32", len(result_lines), exp['result']),
        ("result_mx", len(result_mx_lines), exp['result_mx']),
    ]
    for label, actual, expected in checks:
        assert actual == expected, (
            f"Line count mismatch in {label}: got {actual}, expected {expected} "
            f"(M={mdim}, K={kdim}, N={ndim}, VS={vector_size}, NPE={num_compute_units}, "
            f"Reuse={num_out_buffers}, BS={BLOCK_SIZE})"
        )

    # ---------- Write Files -----------#
    if mem_file:
        with open(mem_file, "w") as f:
            for line in memory_lines:
                f.write(line + "\n")
    if res_file:
        with open(res_file, "w") as f:
            for line in result_lines:
                f.write(line + "\n")
    if res_mx_file:
        with open(res_mx_file, "w") as f:
            for line in result_mx_lines:
                f.write(line + "\n")

    if mem_debug_file is not None:
        write_to_memory_debug(
            fp9_matrix_a=fp9_matrix_a,
            fp9_matrix_b=fp9_matrix_b,
            scale_matrix_a=scale_matrix_a,
            scale_matrix_b=scale_matrix_b,
            result_matrix=result_matrix,
            preload_matrix=preload_matrix,
            data_type=data_type,
            acc_data_type=acc_data_type,
            vector_size=vector_size,
            num_compute_units=num_compute_units,
            num_out_buffers=num_out_buffers,
            memory_data_width=memory_data_width,
            BLOCK_SIZE=BLOCK_SIZE,
            result_mx_block_size=result_mx_block_size,
            mem_debug_file=mem_debug_file,
        )

def write_to_c_header(fp9_matrix_a, fp9_matrix_b, scale_matrix_a, scale_matrix_b, result_matrix, preload_matrix=None, data_type="FP8", acc_data_type="FP32", vector_size=8, num_compute_units=8, num_out_buffers=4, BLOCK_SIZE=32, result_mx_block_size=None, memory_data_width=32, header_path=None, block_poison_enable=False):
    mdim      = len(fp9_matrix_a)
    kdim      = len(fp9_matrix_a[0])
    ndim      = len(fp9_matrix_b[0])
    num_chunks = ceil(kdim / vector_size)
    num_scale_blocks = ceil(kdim / BLOCK_SIZE)
    if result_mx_block_size is None:
        result_mx_block_size = BLOCK_SIZE

    row_starts = range(0, mdim, num_out_buffers)
    col_starts = range(0, ndim, num_compute_units)

    vector_a_bytes   = []  # int8_t
    vectors_b_bytes  = []  # int8_t
    scale_a_bytes    = []  # uint8_t
    scale_b_bytes    = []  # uint8_t
    result_floats    = []  # float
    result_hex       = []  # hex strings
    result_mx_bytes  = []  # mxfp8

    # ---- Vector A ---- #
    for row_start in row_starts:
        rows_in_tile = min(num_out_buffers, mdim - row_start)
        for chid in range(num_chunks):
            actual_vs = min(vector_size, kdim - chid * vector_size)
            for i in range(rows_in_tile):
                vec_bits = vec_to_bin(
                    fp9_matrix_a[row_start + i][chid*vector_size : chid*vector_size + actual_vs],
                    data_type=data_type
                )
                extend_vector_bytes_for_header(vector_a_bytes, vec_bits, data_type=data_type)

    # ---- Vector B ---- #
    for col_start in col_starts:
        cols_in_tile = min(num_compute_units, ndim - col_start)
        for chid in range(num_chunks):
            actual_vs = min(vector_size, kdim - chid * vector_size)
            for j in range(cols_in_tile):
                vec_bits = vec_to_bin(
                        [fp9_matrix_b[chid*vector_size + k][col_start + j] for k in range(actual_vs)],
                        data_type=data_type
                )
                extend_vector_bytes_for_header(vectors_b_bytes, vec_bits, data_type=data_type)

    # ---- Scales A ---- #
    for row_start in row_starts:
        rows_in_tile = min(num_out_buffers, mdim - row_start)
        for scale_idx in range(num_scale_blocks):
            for i in range(rows_in_tile):
                scale_a_bytes.append(bin8_to_u8(scale_matrix_a[row_start + i][scale_idx].binary))

    # ---- Scales B ---- #
    for col_start in col_starts:
        cols_in_tile = min(num_compute_units, ndim - col_start)
        for scale_idx in range(num_scale_blocks):
            for j in range(cols_in_tile):
                scale_b_bytes.append(bin8_to_u8(scale_matrix_b[scale_idx][col_start + j].binary))

    # ---- Golden Result ---- #
    row_tiles = range(0, mdim, num_out_buffers)
    col_tiles = range(0, ndim, num_compute_units)

    result_ints = []
    for row_start in row_tiles:
            rows_in_tile = min(num_out_buffers, mdim - row_start)
            for col_start in col_tiles:
                cols_in_tile = min(num_compute_units, ndim - col_start)
                for i in range(rows_in_tile):
                    for j in range(cols_in_tile):
                        v = getattr(result_matrix[row_start + i][col_start + j], "value", None)
                        if v is None:
                            b = result_matrix[row_start + i][col_start + j].binary
                            v = bin32_to_float(b)
                            h = b
                        else:
                            bits = struct.unpack(">I", struct.pack(">f", float(v)))[0]
                            h = f"{bits:08X}"
                        result_floats.append(float(v))
                        result_hex.append(h)
                        result_ints.append(int(h, 16))

    result_scale_mx = []
    result_mx_all = []
    # Process in tile-major order (M-tile → N-tile → row-in-tile), matching the RTL's write order.
    n_quantizer = max(1, num_compute_units // result_mx_block_size)
    for row_start in row_starts:
        for col_start in col_starts:
            n_cols = min(num_compute_units, ndim - col_start)
            for i in range(min(num_out_buffers, mdim - row_start)):
                row_idx = row_start + i
                for q in range(n_quantizer):
                    q_start = q * result_mx_block_size
                    q_cols = min(result_mx_block_size, n_cols - q_start)
                    segment = [_acc_to_fp32_u32(result_matrix[row_idx][col_start + q_start + j]) for j in range(q_cols)]
                    block_fp32 = segment + [0] * (result_mx_block_size - q_cols)
                    scale, poisoned = block_scale(block_fp32, data_type="FP8ALT" if data_type == "FP8ALT" else "FP8")
                    result_scale_mx.append(scale)
                    quantize_fn = quantize_e5m2 if data_type != "FP8ALT" else quantize_e4m3
                    nan_byte = 0x7D if data_type != "FP8ALT" else 0x7F
                    if poisoned and block_poison_enable:
                        quantized_all = [nan_byte] * len(block_fp32)
                    else:
                        quantized_all = [quantize_fn(v, scale) for v in block_fp32]
                    result_mx_all.extend(quantized_all[:q_cols])

    # Pack bytes into memory_data_width words
    bytes_per_word = memory_data_width // 8
    for i in range(0, len(result_mx_all), bytes_per_word):
        group = result_mx_all[i:i + bytes_per_word]
        while len(group) < bytes_per_word:
            group.append(0)
        word = (group[3] << 24) | (group[2] << 16) | (group[1] << 8) | group[0]
        result_mx_bytes.append(f"{word:08x}")

    # ---- Preload accumulator ---- #
    preload_floats = []
    if preload_matrix is not None:
        for row_start in row_starts:
            for col_start in col_starts:
                rit = min(num_out_buffers, mdim - row_start)
                cit = min(num_compute_units, ndim - col_start)
                for i in range(rit):
                    for j in range(cit):
                        preload_floats.append(float(preload_matrix[row_start + i][col_start + j].value))

    # ---- Extract sizes  ---- #
    A_SIZE          = len(vector_a_bytes)
    B_SIZE          = len(vectors_b_bytes)
    SCALE_A_SIZE    = len(scale_a_bytes)
    SCALE_B_SIZE    = len(scale_b_bytes)
    SCALE_RESULT_SIZE = len(result_scale_mx)
    RESULT_SIZE     = len(result_floats)
    RESULT_MX_SIZE  = len(result_mx_all)
    PRELOAD_SIZE    = len(preload_floats)

    def chunk(iterable, n):
        for i in range(0, len(iterable), n):
            yield iterable[i:i+n]

    with open(header_path, "w") as f:
        f.write("#pragma once\n\n")
        f.write("#define inf INFINITY\n")
        f.write("#define nan NAN\n\n")
        f.write(f"#define PRELOAD {1 if preload_matrix is not None else 0}\n")
        f.write(f"#define A_SIZE {A_SIZE}\n")
        f.write(f"#define B_SIZE {B_SIZE}\n")
        f.write(f"#define SCALE_A_SIZE {SCALE_A_SIZE}\n")
        f.write(f"#define SCALE_B_SIZE {SCALE_B_SIZE}\n")
        f.write(f"#define PRELOAD_SIZE {PRELOAD_SIZE}\n")
        f.write(f"#define SCALE_RESULT_SIZE {SCALE_RESULT_SIZE}\n")
        f.write(f"#define RESULT_SIZE {RESULT_SIZE}\n")
        f.write(f"#define RESULT_MX_SIZE {RESULT_MX_SIZE}\n\n")

        # int8_t vector_a[]
        f.write("int8_t vector_a[A_SIZE] = {\n")
        for row in chunk(vector_a_bytes, 16):
            f.write("  " + ", ".join(f"{x}" for x in row) + ",\n")
        f.write("};\n\n")

        # int8_t vectors_b[]
        f.write("int8_t vectors_b[B_SIZE] = {\n")
        for row in chunk(vectors_b_bytes, 16):
            f.write("  " + ", ".join(f"{x}" for x in row) + ",\n")
        f.write("};\n\n")

        # uint8_t scale_a[]
        f.write("uint8_t scale_a[SCALE_A_SIZE] = {\n")
        for row in chunk(scale_a_bytes, 16):
            f.write("  " + ", ".join(f"{x}" for x in row) + ",\n")
        f.write("};\n\n")

        # uint8_t scale_b[]
        f.write("uint8_t scale_b[SCALE_B_SIZE] = {\n")
        for row in chunk(scale_b_bytes, 16):
            f.write("  " + ", ".join(f"{x}" for x in row) + ",\n")
        f.write("};\n\n")

        # float preload_acc[] (if preload enabled)
        if preload_matrix is not None:
            f.write("float preload_acc[PRELOAD_SIZE] = {\n")
            for row in chunk(preload_floats, 8):
                f.write("  " + ", ".join(f"{x:.8g}" for x in row) + ",\n")
            f.write("};\n\n")

        # float result[]
        f.write("float golden_result[RESULT_SIZE] = {\n")
        for row in chunk(result_floats, 8):
            f.write("  " + ", ".join(f"{x:.8g}" for x in row) + ",\n")
        f.write("};\n\n")

        f.write("float result[RESULT_SIZE];\n\n")

        f.write("uint8_t golden_result_mx[RESULT_MX_SIZE] = {\n")
        for row in chunk(result_mx_all, 16):
            f.write("  " + ", ".join(f"0x{x:02x}" for x in row) + ",\n")
        f.write("};\n\n")

        f.write("uint8_t result_mx[RESULT_MX_SIZE];\n\n")

        f.write("uint8_t golden_scale_result_mx[SCALE_RESULT_SIZE] = {\n")
        for row in chunk(result_scale_mx, 16):
            f.write("  " + ", ".join(f"0x{x:02x}" for x in row) + ",\n")
        f.write("};\n\n")

        f.write("uint8_t scale_result_mx[SCALE_RESULT_SIZE];\n\n")

# ---------------------------------------------------------------------------
# Debug output: dataflow trace (one block per M-tile × N-tile × K-chunk)
# ---------------------------------------------------------------------------

def write_to_dataflow_debug(trace, mdim, kdim, ndim, vector_size, num_compute_units,
                             num_out_buffers, BLOCK_SIZE, data_type, acc_data_type,
                             dataflow_file):
    hex_fmt = "{:x}" if data_type == "FP4" else "{:02x}"

    _ordinals = ["1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th"]

    def _ordinal(n):
        return _ordinals[n - 1] if 1 <= n <= len(_ordinals) else f"{n}th"

    def _vec_str(vec):
        bits = vec_to_bin(vec, data_type=data_type)
        return " ".join(hex_fmt.format(int(b, 2)) for b in bits)

    def _scale_hex(s):
        return f"0x{int(s.binary, 2):02x}"

    def _acc_hex(acc):
        return f"{_acc_to_fp32_u32(acc):08x}"

    with open(dataflow_file, "w") as f:
        f.write("MXCore GEMM Dataflow Debug\n")
        f.write(f"M={mdim}, K={kdim}, N={ndim}  |  "
                f"VS={vector_size}, NPE(MXU)={num_compute_units}, Reuse(O)={num_out_buffers}, BS={BLOCK_SIZE}\n")
        f.write(f"Data type: {data_type}  Accumulator: {acc_data_type}\n\n")

        prev_tile = None
        k_iter = 0

        for entry in trace:
            row_start = entry['row_start']
            col_start = entry['col_start']
            k_start   = entry['k_start']
            k_end     = entry['k_end']
            scale_idx = entry['scale_idx']
            chunk_a   = entry['matrix_chunk_a']
            chunk_b   = entry['matrix_chunk_b']
            scales_a  = entry['scales_a']
            scales_b  = entry['scales_b']
            acc_in    = entry['acc_input']
            acc_out   = entry['acc_output']

            n_rows = len(chunk_a)
            n_cols = len(chunk_b)

            cur_tile = (row_start, col_start)
            if cur_tile != prev_tile:
                f.write(f"{'='*80}\n")
                f.write(f"Output Tile:  M-rows {row_start}-{row_start+n_rows-1}"
                        f"  |  N-cols {col_start}-{col_start+n_cols-1}\n")
                f.write(f"{'='*80}\n\n")
                prev_tile = cur_tile
                k_iter = 0

            k_iter += 1
            f.write(f"{'─'*40}\n")
            f.write(f"{_ordinal(k_iter)} Reuse Iteration"
                    f"  (k={k_start}..{k_end-1}, K-Block {scale_idx})\n")
            f.write(f"{'─'*40}\n\n")

            # ---- A tile ----
            f.write(f"A tile  (Reuse × VS = {n_rows} × {vector_size}, along rows)\n")
            f.write(f"  A[ 0] row {row_start:3d}: {_vec_str(chunk_a[0])}\n")
            if n_rows > 2:
                f.write("  ...\n")
            if n_rows > 1:
                f.write(f"  A[{n_rows-1:2d}] row {row_start+n_rows-1:3d}: {_vec_str(chunk_a[-1])}\n")
            f.write("\n")

            # ---- B tile ----
            f.write(f"B tile  (VS × NPE = {vector_size} × {n_cols}, along columns)\n")
            f.write(f"  B[ 0] col {col_start:3d}: {_vec_str(chunk_b[0])}\n")
            if n_cols > 2:
                f.write("  ...\n")
            if n_cols > 1:
                f.write(f"  B[{n_cols-1:2d}] col {col_start+n_cols-1:3d}: {_vec_str(chunk_b[-1])}\n")
            f.write("\n")

            # ---- Scales ----
            sa0 = _scale_hex(scales_a[0]);  sa_last = _scale_hex(scales_a[-1])
            sb0 = _scale_hex(scales_b[0]);  sb_last = _scale_hex(scales_b[-1])
            sa_str = f"{sa0} ... {sa_last}" if len(scales_a) > 1 else sa0
            sb_str = f"{sb0} ... {sb_last}" if len(scales_b) > 1 else sb0
            f.write(f"Scale A:  {sa_str}\n")
            f.write(f"Scale B:  {sb_str}\n\n")

            # ---- Accumulators (first/last row, first/last col on each shown row) ----
            c_hdr = f"c{col_start} ... c{col_start+n_cols-1}" if n_cols > 1 else f"c{col_start}"

            def _acc_row_line(row_idx):
                c0   = _acc_hex(acc_in[row_idx][0])
                clst = _acc_hex(acc_in[row_idx][-1])
                val  = f"{c0}  ...  {clst}" if n_cols > 1 else c0
                return f"  r{row_start+row_idx:<3d}:  {val}\n"

            def _acc_out_row_line(row_idx):
                c0   = _acc_hex(acc_out[row_idx][0])
                clst = _acc_hex(acc_out[row_idx][-1])
                val  = f"{c0}  ...  {clst}" if n_cols > 1 else c0
                return f"  r{row_start+row_idx:<3d}:  {val}\n"

            def _write_acc(label, row_fn):
                f.write(f"{label} [{n_rows} × {n_cols}]:\n")
                f.write(f"         {c_hdr}\n")
                f.write(row_fn(0))
                if n_rows > 2:
                    f.write("  ...\n")
                if n_rows > 1:
                    f.write(row_fn(n_rows - 1))
                f.write("\n")

            _write_acc("Accumulator Input", _acc_row_line)
            _write_acc("Accumulator Output", _acc_out_row_line)


# ---------------------------------------------------------------------------
# Debug output: memory layout with hex addresses for all three files
# ---------------------------------------------------------------------------

def write_to_memory_debug(fp9_matrix_a, fp9_matrix_b, scale_matrix_a, scale_matrix_b,
                           result_matrix, preload_matrix=None, *, data_type, acc_data_type, vector_size,
                           num_compute_units, num_out_buffers, memory_data_width,
                           BLOCK_SIZE, result_mx_block_size, mem_debug_file):
    mdim = len(fp9_matrix_a)
    kdim = len(fp9_matrix_a[0])
    ndim = len(fp9_matrix_b[0])
    num_chunks = ceil(kdim / vector_size)
    num_scale_blocks = ceil(kdim / BLOCK_SIZE)
    bpl = memory_data_width // 8

    if result_mx_block_size is None:
        result_mx_block_size = BLOCK_SIZE

    bits_per_elem = 4 if data_type == "FP4" else 8

    def _words_for_chunk(chid):
        actual_vs = min(vector_size, kdim - chid * vector_size)
        return ceil(actual_vs * bits_per_elem / memory_data_width)

    row_tiles = list(range(0, mdim, num_out_buffers))
    col_tiles = list(range(0, ndim, num_compute_units))

    def _rows(rs): return min(num_out_buffers, mdim - rs)
    def _cols(cs): return min(num_compute_units, ndim - cs)
    def _addr(line): return line * bpl
    def _h(a): return f"0x{a:04x}"

    with open(mem_debug_file, "w") as f:

        def section(title):
            f.write(f"\n{'='*80}\n{title}\n{'='*80}\n\n")

        f.write("MXCore Memory Layout Debug  (unpadded / contiguous mode)\n")
        f.write(f"M={mdim}, K={kdim}, N={ndim}  |  "
                f"VS={vector_size}, NPE(MXU)={num_compute_units}, Reuse(O)={num_out_buffers}, BS={BLOCK_SIZE}\n")
        f.write(f"Memory width={memory_data_width} bits  ({bpl} bytes/line)  "
                f"Address = line_number × {bpl}\n")
        f.write(f"Data type: {data_type}  ({bits_per_elem} bits/element)\n")

        preload_tag = " | Preload" if preload_matrix is not None else ""
        section(f"data_memory  (layout: A section | B section | Scale A | Scale B{preload_tag})")

        line = 0

        # ---- Matrix A ----
        f.write(f"--- Matrix A  ({mdim}×{kdim})  "
                f"[loop: M-tile → K-chunk → row in tile] ---\n\n")
        for t, row_start in enumerate(row_tiles):
            nr = _rows(row_start)
            tile_start = line
            tile_len = 0
            for chid in range(num_chunks):
                actual_vs = min(vector_size, kdim - chid * vector_size)
                vec_bits = actual_vs * bits_per_elem
                if vec_bits % memory_data_width == 0:
                    tile_len += nr * _words_for_chunk(chid)
                else:
                    tile_len += ceil(nr * vec_bits / memory_data_width)
            tile_end = tile_start + tile_len - 1
            f.write(f"  A Tile {t}  (M-tile rows {row_start}-{row_start+nr-1}  |  "
                    f"{num_chunks} K-chunk(s))\n")
            f.write(f"    {_h(_addr(tile_start))}: A Tile {t} begins\n")
            chunk_line = tile_start
            for chid in range(num_chunks):
                actual_vs = min(vector_size, kdim - chid * vector_size)
                wpv = _words_for_chunk(chid)
                vec_bits = actual_vs * bits_per_elem
                if vec_bits % memory_data_width == 0:
                    chunk_len = nr * wpv
                else:
                    chunk_len = ceil(nr * vec_bits / memory_data_width)
                k0 = chid * vector_size
                k1 = min(k0 + vector_size, kdim) - 1
                partial_tag = f"  (partial, {actual_vs} elems)" if actual_vs < vector_size else ""
                f.write(f"      K-chunk {chid} [k={k0}..{k1}]{partial_tag}: "
                        f"{_h(_addr(chunk_line))} - {_h(_addr(chunk_line + chunk_len - 1))}\n")
                chunk_line += chunk_len
            f.write(f"    {_h(_addr(tile_end))}: A Tile {t} ends\n\n")
            line += tile_len

        # ---- Matrix B ----
        f.write(f"--- Matrix B  ({kdim}×{ndim}, stored as column vectors)  "
                f"[loop: N-tile → K-chunk → col in tile] ---\n\n")
        for t, col_start in enumerate(col_tiles):
            nc = _cols(col_start)
            tile_start = line
            tile_len = 0
            for chid in range(num_chunks):
                actual_vs = min(vector_size, kdim - chid * vector_size)
                vec_bits = actual_vs * bits_per_elem
                if vec_bits % memory_data_width == 0:
                    tile_len += nc * _words_for_chunk(chid)
                else:
                    tile_len += ceil(nc * vec_bits / memory_data_width)
            tile_end = tile_start + tile_len - 1
            f.write(f"  B Tile {t}  (N-tile cols {col_start}-{col_start+nc-1}  |  "
                    f"{num_chunks} K-chunk(s))\n")
            f.write(f"    {_h(_addr(tile_start))}: B Tile {t} begins\n")
            chunk_line = tile_start
            for chid in range(num_chunks):
                actual_vs = min(vector_size, kdim - chid * vector_size)
                wpv = _words_for_chunk(chid)
                vec_bits = actual_vs * bits_per_elem
                if vec_bits % memory_data_width == 0:
                    chunk_len = nc * wpv
                else:
                    chunk_len = ceil(nc * vec_bits / memory_data_width)
                k0 = chid * vector_size
                k1 = min(k0 + vector_size, kdim) - 1
                partial_tag = f"  (partial, {actual_vs} elems)" if actual_vs < vector_size else ""
                f.write(f"      K-chunk {chid} [k={k0}..{k1}]{partial_tag}: "
                        f"{_h(_addr(chunk_line))} - {_h(_addr(chunk_line + chunk_len - 1))}\n")
                chunk_line += chunk_len
            f.write(f"    {_h(_addr(tile_end))}: B Tile {t} ends\n\n")
            line += tile_len

        # ---- Scale A (unpadded: all scales in M-tile contiguous) ----
        f.write(f"--- Scale A  ({bpl} scales/word)  "
                f"[loop: M-tile → (K-block × rows) packed contiguously] ---\n\n")
        for t, row_start in enumerate(row_tiles):
            nr = _rows(row_start)
            total_scales = nr * num_scale_blocks
            tile_start = line
            tile_len = ceil(total_scales / bpl)
            tile_end = tile_start + tile_len - 1
            f.write(f"  SA Tile {t}  (M-tile rows {row_start}-{row_start+nr-1}  |  "
                    f"{num_scale_blocks} K-block(s)  {total_scales} scales → {tile_len} word(s))\n")
            f.write(f"    {_h(_addr(tile_start))}: SA Tile {t} begins\n")
            f.write(f"    {_h(_addr(tile_end))}: SA Tile {t} ends\n\n")
            line += tile_len

        # ---- Scale B (unpadded: all scales in N-tile contiguous) ----
        f.write(f"--- Scale B  ({bpl} scales/word)  "
                f"[loop: N-tile → (K-block × cols) packed contiguously] ---\n\n")
        for t, col_start in enumerate(col_tiles):
            nc = _cols(col_start)
            total_scales = nc * num_scale_blocks
            tile_start = line
            tile_len = ceil(total_scales / bpl)
            tile_end = tile_start + tile_len - 1
            f.write(f"  SB Tile {t}  (N-tile cols {col_start}-{col_start+nc-1}  |  "
                    f"{num_scale_blocks} K-block(s)  {total_scales} scales → {tile_len} word(s))\n")
            f.write(f"    {_h(_addr(tile_start))}: SB Tile {t} begins\n")
            f.write(f"    {_h(_addr(tile_end))}: SB Tile {t} ends\n\n")
            line += tile_len

        # ---- Preload Accumulator ----
        if preload_matrix is not None:
            preload_len = mdim * ndim
            f.write(f"--- Preload Accumulator  ({mdim}×{ndim}, FP32, one word/element)  "
                    f"[tile-row-major order like result] ---\n\n")
            f.write(f"    {_h(_addr(line))}: Preload begins\n")
            f.write(f"    {_h(_addr(line + preload_len - 1))}: Preload ends\n\n")
            line += preload_len

        f.write(f"  Total data_memory: {line} lines  ({_addr(line)} bytes)\n")

        # =====================================================================
        section("result  (FP32, one word/element, tile-major order)")
        # =====================================================================

        f.write("  Order: M-tile → N-tile → row in tile → col in tile\n\n")
        res_line = 0
        for m, row_start in enumerate(row_tiles):
            nr = _rows(row_start)
            for n, col_start in enumerate(col_tiles):
                nc = _cols(col_start)
                tile_words = nr * nc
                ts = res_line;  te = res_line + tile_words - 1
                f.write(f"  Result Tile [{m},{n}]  "
                        f"(rows {row_start}-{row_start+nr-1}, cols {col_start}-{col_start+nc-1}):\n")
                f.write(f"    {_h(_addr(ts))}: Result Tile [{m},{n}] begins\n")
                f.write(f"    {_h(_addr(te))}: Result Tile [{m},{n}] ends\n\n")
                res_line += tile_words
        f.write(f"  Total result: {res_line} lines  ({_addr(res_line)} bytes)\n")

        # =====================================================================
        section("result_mx  (MXFP8 E5M2 data | per-segment scales, unpadded)")
        # =====================================================================

        total_mx_bytes = sum(
            _rows(rs) * _cols(cs)
            for rs in row_tiles for cs in col_tiles
        )
        total_mx_data = ceil(total_mx_bytes / bpl)
        n_quantizer = max(1, num_compute_units // result_mx_block_size)
        n_segments = sum(
            _rows(rs) * len(col_tiles)
            for rs in row_tiles
        ) * n_quantizer
        scale_words = ceil(n_segments / bpl)

        f.write(f"  Tile-major order: M-tile → N-tile → row → cols\n")
        f.write(f"  Total MXFP8 data bytes: {total_mx_bytes}  → {total_mx_data} word(s)\n")
        f.write(f"  Total scales: {n_segments} ({n_quantizer} per row per N-tile)  → {scale_words} word(s)\n\n")

        f.write(f"  Section 1: MXFP8 quantized data\n")
        f.write(f"    {_h(0)}: MXFP8 data begins\n")
        f.write(f"    {_h(_addr(total_mx_data - 1))}: MXFP8 data ends\n\n")

        ss = _addr(total_mx_data)
        se = _addr(total_mx_data + scale_words - 1)
        f.write(f"  Section 2: Shared scales\n")
        f.write(f"    {_h(ss)}: Scale section begins\n")
        f.write(f"    {_h(se)}: Scale section ends\n\n")

        total_mx = total_mx_data + scale_words
        f.write(f"  Total result_mx: {total_mx} lines  ({_addr(total_mx)} bytes)\n")
