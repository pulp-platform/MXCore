import struct
from mpmath import mp, fsum, power, mpf
from math import isnan

from .fp_accumulator import *

PRINT_ENABLED = False
DEBUG = False

def bin8_to_u8(s):    # "00101101" -> 45
    return int(s[-8:], 2)

def bin8_to_i8(s):    # two's complement to signed int8
    v = int(s[-8:], 2)
    return v - 256 if v >= 128 else v

def bin32_to_float(s32):  # "01000000101000000000000000000000" -> 5.0
    b = int(s32[-32:], 2)
    return struct.unpack('!f', struct.pack('!I', b))[0]

def to_signed8(x):
    return x - 256 if x > 127 else x

def vec_to_hex(vec, vector_size=8, memory_data_width=32):
    """
    Converts a vector of binary strings into hex memory lines (padded mode).
    Each call pads the final word to memory_data_width bits.
    vector_size is accepted for backward compat but len(vec) is used.
    """
    full_binary = ''.join(vec)
    if len(full_binary) % memory_data_width != 0:
        full_binary += '0' * (memory_data_width - (len(full_binary) % memory_data_width))

    hex_lines = []
    for i in range(0, len(full_binary), memory_data_width):
        chunk = full_binary[i:i+memory_data_width]
        hex_str = f"{int(chunk, 2):08x}"
        hex_lines.append(hex_str)
    hex_lines.reverse()
    return hex_lines


def bits_to_hex_lines(bit_string, memory_data_width=32):
    """
    Convert an accumulated binary string into hex memory lines.
    Pads the final word to memory_data_width. No per-vector reversal.
    Used for unpadded/contiguous packing of partial vectors.
    """
    if not bit_string:
        return []
    if len(bit_string) % memory_data_width != 0:
        bit_string += '0' * (memory_data_width - (len(bit_string) % memory_data_width))
    hex_lines = []
    for i in range(0, len(bit_string), memory_data_width):
        chunk = bit_string[i:i+memory_data_width]
        hex_lines.append(f"{int(chunk, 2):08x}")
    return hex_lines

def vec_to_bin(vec, data_type="FP8"):
    if data_type == "FP8":
        return [fp9.binary[0:8] for fp9 in vec]
    elif data_type == "FP8ALT":
        return [f"{fp9.sign}{fp9.exponent:04b}{fp9.mantissa:03b}" for i, fp9 in enumerate(vec)]
    elif data_type == "FP4":
        # Keep FP4 elements as individual 4-bit tokens in source order.
        return [f"{fp9.sign}{fp9.exponent:02b}{(fp9.mantissa >> 2):01b}" for fp9 in vec]
    elif data_type == "INT8":
        return [fp9.binary[0:8] for fp9 in vec]
    else:
        raise ValueError(f"Unsupported data_type for vec_to_bin: {data_type}")

def _acc_to_fp32_u32(acc):
    bits = struct.unpack(">I", struct.pack(">f", float(acc.value)))[0]
    return bits

def quantize_bf16(fp32_bits):
    sign = (fp32_bits >> 31) & 1
    exp = (fp32_bits >> 23) & 0xFF
    mant = fp32_bits & 0x7FFFFF
    if exp == 0xFF and mant != 0:
        return (sign << 15) | 0x7FC0
    rounded = fp32_bits + 0x7FFF + ((fp32_bits >> 16) & 1)
    return (rounded >> 16) & 0xFFFF

def quantize_result_to_bf16(res_file, res_bf16_file, memory_data_width=32):
    with open(res_file) as f:
        fp32_words = [int(line.strip(), 16) for line in f if line.strip()]
    halfwords = [quantize_bf16(w) for w in fp32_words]
    halfwords_per_line = memory_data_width // 16
    lines = []
    for k in range(0, len(halfwords), halfwords_per_line):
        group = halfwords[k:k + halfwords_per_line]
        group += [0] * (halfwords_per_line - len(group))
        word = sum(h << (16 * j) for j, h in enumerate(group))
        lines.append(f"{word:0{memory_data_width // 4}x}")
    with open(res_bf16_file, "w") as f:
        for line in lines:
            f.write(line + "\n")
    return len(fp32_words), len(lines)

def extend_vector_bytes_for_header(dst, vec_bits, data_type="FP8"):
    if data_type == "FP4":
        packed_bytes = vec_to_hex(
            vec_bits,
            vector_size=len(vec_bits),
            memory_data_width=8,
        )
        for byte_hex in packed_bytes:
            dst.append(bin8_to_i8(f"{int(byte_hex, 16):08b}"))
    else:
        dst.extend(bin8_to_i8(b[-8:].zfill(8)) for b in vec_bits)

def fp32_to_mxfp8(fp32_binary: str) -> str:
    assert len(fp32_binary) == 32, "Input must be 32-bit binary string"

    # Constants
    FP32_BIAS = 127
    E5M2_BIAS = 15

    # Parse fields
    sign = int(fp32_binary[0], 2)
    exp_in = int(fp32_binary[1:9], 2)
    mant_in = int(fp32_binary[9:], 2)

    # Special cases
    if exp_in == 0 and mant_in == 0:
        return f"{sign:1b}" + "00000" + "00"   # zero
    if exp_in == 0xFF and mant_in != 0:
        return "0" + "11111" + "01"            # NaN (canonical qNaN)
    if exp_in == 0xFF and mant_in == 0:
        return f"{sign:1b}" + "11110" + "11"   # Inf → max finite (saturate)
    
    # Unbiased exponent
    unbiased_exp = exp_in - FP32_BIAS
    full_mant = (1 << 23) | mant_in  # 1 + 23 bits = 24 bits
    # Overflow → clamp
    if unbiased_exp > 15:
        return f"{sign:1b}" + "11110" + "11"
    # Underflow too small for subnormals
    if unbiased_exp < -14:
        return f"{sign:1b}" + "00000" + "00"
    # Subnormal
    if unbiased_exp == -14:
        shifted = full_mant >> 1
        top3 = (shifted >> 21) & 0x7
        guard = (shifted >> 20) & 0x1
        sticky = 1 if (shifted & ((1 << 20) - 1)) != 0 else 0
        roundbit = guard & (sticky | (top3 & 0x1))
        mant_3bit = top3 + roundbit
        mant_final = mant_3bit & 0x3
        if mant_final == 0:
            return f"{sign:1b}" + "00000" + "00"
        else:
            return f"{sign:1b}" + "00000" + f"{mant_final:02b}"
    # Normal case
    exp_out = unbiased_exp + E5M2_BIAS
    top3 = (full_mant >> 21) & 0x7
    guard = (full_mant >> 20) & 0x1
    sticky = 1 if (full_mant & ((1 << 20) - 1)) != 0 else 0
    roundbit = guard & (sticky | (top3 & 0x1))
    mant_3bit = top3 + roundbit
    mant_final = mant_3bit & 0x3
    exp_out += (mant_3bit >> 2) & 0x1  # add carry
    # Saturate if overflow
    if exp_out >= 31:
        return f"{sign:1b}" + "11110" + "11"

    return f"{sign:1b}" + f"{exp_out:05b}" + f"{mant_final:02b}"

def fp32_to_fields(fp32_val):
        """Split FP32 into sign, exp, mant"""
        sign = (fp32_val >> 31) & 0x1
        exp = (fp32_val >> 23) & 0xFF
        mant = fp32_val & 0x7FFFFF
        return sign, exp, mant

def block_scale(block, data_type="FP8"):
        emax = 15 if data_type == "FP8" else 8
        max_exp = max([(fp32_to_fields(x)[1]) for x in block])
        is_special = any((fp32_to_fields(x)[1] == 0xFF) for x in block)
        scaled = max_exp - (127 + emax)
        scale_emax = 127
        if scaled > scale_emax:
            return scale_emax & 0xFF, True
        if scaled < -scale_emax:
            return (-scale_emax) & 0xFF, is_special
        return scaled & 0xFF, is_special

def _quantize_mxfp8(fp32_val, scale, mant_bits, exp_bits, bias, exp_max, exp_min, sat_byte, nan_byte, full_field_reserved):
    sign, exp, mant = fp32_to_fields(fp32_val)

    if exp == 0 and mant == 0:
        return sign << 7
    if exp == 0xFF and mant != 0:
        return (sign << 7) | nan_byte
    if exp == 0xFF and mant == 0:
        return (sign << 7) | sat_byte

    is_subnorm_in = (exp == 0)
    unbiased_exp = (1 - 127) if is_subnorm_in else (exp - 127)
    full_mant = mant if is_subnorm_in else ((1 << 23) | mant)
    scaled_exp = unbiased_exp - to_signed8(scale)

    if scaled_exp > exp_max:
        return (sign << 7) | sat_byte

    w = mant_bits + 1
    shift_raw = exp_min - scaled_exp
    shift_amt = 0 if shift_raw <= 0 else min(shift_raw, 24)
    shifted = full_mant >> shift_amt
    rounded = (shifted >> (23 - w + 1)) & ((1 << w) - 1)
    guard = (shifted >> (23 - w)) & 1
    sticky = 1 if (shifted & ((1 << (23 - w)) - 1)) else 0
    roundbit = guard & (sticky | (rounded & 1))
    rounded += roundbit

    if shift_amt == 0:
        carry = (rounded >> w) & 1
        final_exp = scaled_exp + bias + carry
        mant_out = rounded & ((1 << mant_bits) - 1)
        max_exp_field = (1 << exp_bits) - 1
        if full_field_reserved:
            reserved = final_exp >= max_exp_field
        else:
            reserved = final_exp > max_exp_field or (final_exp == max_exp_field and mant_out == (1 << mant_bits) - 1)
        if reserved:
            return (sign << 7) | sat_byte
        return (sign << 7) | ((final_exp & max_exp_field) << mant_bits) | mant_out
    else:
        if rounded & (1 << mant_bits):
            return (sign << 7) | (1 << mant_bits)
        return (sign << 7) | (rounded & ((1 << mant_bits) - 1))

def quantize_e5m2(fp32_val, scale):
    return _quantize_mxfp8(fp32_val, scale, mant_bits=2, exp_bits=5, bias=15, exp_max=15, exp_min=-14,
                            sat_byte=0x7B, nan_byte=0x7D, full_field_reserved=True)

def quantize_e4m3(fp32_val, scale):
    return _quantize_mxfp8(fp32_val, scale, mant_bits=3, exp_bits=4, bias=7, exp_max=8, exp_min=-6,
                            sat_byte=0x7E, nan_byte=0x7F, full_field_reserved=False)

def format_matrix_A(matrix, name, vector_size=8, memory_data_width=32, data_type="FP8"):
        """Pretty-print Matrix A rows using same packing as memory_lines"""
        lines = []
        nrows, ncols = len(matrix), len(matrix[0])
        lines.append(f"{name} ({nrows} x {ncols}) [row-packed into {memory_data_width}-bit words]:")
        for row in matrix:
            packed_row = []
            for chid in range(0, ncols, vector_size):
                vec = vec_to_bin(row[chid:chid+vector_size], data_type=data_type)
                hexwords = vec_to_hex(vec, vector_size=vector_size, memory_data_width=memory_data_width)
                packed_row.append("".join(hexwords))
            lines.append(" ".join(packed_row))
        lines.append("")
        return lines

def format_matrix_B(matrix, name, vector_size=8, memory_data_width=32, data_type="FP8"):
    """Pretty-print Matrix B columns using same packing as memory_lines"""
    lines = []
    nrows, ncols = len(matrix), len(matrix[0])
    lines.append(f"{name} ({nrows} x {ncols}) [col-packed into {memory_data_width}-bit words]:")
    for r in range(nrows):
        packed_row = []
        # go through col chunks of size vector_size
        for col_start in range(0, ncols, vector_size):
            # build the column vector like in memory writer
            vec = [matrix[r][col_start + k] for k in range(vector_size)]
            vec = vec_to_bin(vec, data_type=data_type)
            hexwords = vec_to_hex(vec, vector_size=vector_size, memory_data_width=memory_data_width)
            packed_row.append("".join(hexwords))
        lines.append(" ".join(packed_row))
    lines.append("")
    return lines