import struct
import csv
import itertools
from mpmath import mp, fsum, power
from math import isnan

from .fp_accumulator import *

PRINT_ENABLED = False
DEBUG = False

def print_conditional(*args, force_print=False, debug=False, **kwargs):
    if PRINT_ENABLED or force_print or (debug and DEBUG):
        print(*args, **kwargs)

def int_to_binary(num, bits):
    """
    Convert an integer to its binary representation with a fixed number of bits.
    Handles both positive and negative integers using two's complement for negatives.

    Args:
        num (int): The integer value to convert.
        bits (int): The number of bits in the binary representation.

    Returns:
        str: The binary representation of the integer value, using two's complement for negative numbers.
    """
    if num >= 0:
        binary = bin(num)[2:]  # Convert to binary and remove the '0b' prefix
    else:
        binary = bin(num & (2**bits - 1))[2:]  # Compute two's complement
    
    return binary.zfill(bits)  # Pad the binary number with leading zeros

def highlight_bits(binary_string, start, end):
    """
    Highlights bits in the specified range in a binary string by coloring them red.

    Args:
        binary_string (str): The binary string.
        start (int): The starting index of the range (inclusive).
        end (int): The ending index of the range (inclusive).

    Returns:
        str: The binary string with the specified range of bits highlighted in red.
    """
    if start < 0 or start > end:
        raise ValueError("Invalid start or end index for the given binary string.")
    elif end >= len(binary_string):
        end = len(binary_string) - 1
    
    # ANSI escape codes for red text
    red_start = "\033[91m"
    red_end = "\033[0m"
    
    # Splitting the binary string into three parts: before, within, and after the range
    before = binary_string[:start]
    within = binary_string[start:end + 1]  # end + 1 because the range is inclusive
    after = binary_string[end + 1:]
    
    # Concatenate the parts, with the middle part highlighted in red
    highlighted_string = before + red_start + within + red_end + after
    
    return highlighted_string

def format_fp9_cvfpu(fp9):
    if fp9.is_integer:
        return fp9.binary
    else:
        exp_width = fp9.exponent_bits
        mant_width = fp9.mantissa_bits
        exp_mask = (1 << exp_width) - 1
        mant_mask = (1 << mant_width) - 1
        mant_shift = fp9.super_mantissa_bits - mant_width
        prefix_zeros = 8 - (1 + exp_width + mant_width)
        prefix = '0' * prefix_zeros
        sign = f"{fp9.sign}"
        exponent = f"{fp9.exponent & exp_mask:0{exp_width}b}"
        mantissa = f"{(fp9.mantissa >> mant_shift) & mant_mask:0{mant_width}b}"
        return f"{prefix}{sign}{exponent}{mantissa}"

def check_equality(ms_matrix, mx_matrix, name, is_int8=False):
    if is_int8:
        if (name == "A" or name == "B"):
            flat_mx = [elem.value*2**-6 for row in mx_matrix for elem in row]
        elif (name == "Sa" or name == "Sb"):
            flat_mx = [elem.value+6 for row in mx_matrix for elem in row]
    else:
        flat_mx = [elem.value for row in mx_matrix for elem in row]
    flat_ms = [float(elem) for elem in ms_matrix]

    error = 0
    for i in range(len(flat_mx)):
        if flat_mx[i] != flat_ms[i]:
            error += 1
            print(f"Mismatch in {name} at index {i}: {flat_mx[i]} != {flat_ms[i]}")

    if error == 0:
        print(f"✅ MS {name} matrix matches the input {name} matrix.")
    else:
        raise ValueError(f"❌ MS {name} matrix does not match the input {name} matrix. {error} mismatches found.")

def compare_ms_mx(ms_data, a_matrix, b_matrix, scale_matrix_a, scale_matrix_b, is_int8=False):
    check_equality(ms_data["A"], a_matrix, "A", is_int8)
    check_equality(ms_data["B"], [list(col) for col in zip(*b_matrix)], "B", is_int8)  # Transpose b_matrix for comparison
    check_equality(ms_data["Sa"], scale_matrix_a, "Sa", is_int8)
    check_equality(ms_data["Sb"], scale_matrix_b, "Sb", is_int8)

def check_special_cases(fp9_vector_a, fp9_vector_b, scale_a, scale_b, fp32, acc_data_type):
    """
    Check for special cases in the input vectors and FP32 value.

    Args:
        fp9_vector_a (list): The first list of FP9 values.
        fp9_vector_b (list): The second list of FP9 values.
        fp32 (FPAccumulator): The FP32 value.
    """

    # Initialize flags for possible outcomes
    contains_nan = False
    contains_pos_inf = False
    contains_neg_inf = False

    # Check each vector element for special values
    for i, (fp9_a, fp9_b) in enumerate(zip(fp9_vector_a, fp9_vector_b)):
        # Check for NaN
        if isnan(fp9_a) or isnan(fp9_b):
            contains_nan = True
        if fp9_a == 0 and (fp9_b == float('inf') or fp9_b == float('-inf')):
            contains_nan = True
        elif (fp9_a == float('inf') or fp9_a == float('-inf')) and fp9_b == 0:
            contains_nan = True

        # Check for infinities
        if fp9_a == float('inf'):
            if fp9_b > 0: # Covers the positive infinity case
                contains_pos_inf = True
            elif fp9_b < 0:
                contains_neg_inf = True
        elif fp9_a == float('-inf'):
            if fp9_b > 0:
                contains_neg_inf = True
            elif fp9_b < 0:
                contains_pos_inf = True
        elif fp9_b == float('inf'):
            if fp9_a > 0:
                contains_pos_inf = True
            elif fp9_a < 0:
                contains_neg_inf = True
        elif fp9_b == float('-inf'):
            if fp9_a > 0:
                contains_neg_inf = True
            elif fp9_a < 0:
                contains_pos_inf = True

    if isnan(scale_a) or isnan(scale_b):
        contains_nan = True

    if isnan(fp32):
        contains_nan = True
    elif fp32 == float('inf'):
        contains_pos_inf = True
    elif fp32 == float('-inf'):
        contains_neg_inf = True

    if contains_nan:
        return True, FPAccumulator(float('nan'), acc_data_type)
    elif contains_pos_inf and contains_neg_inf:
        return True, FPAccumulator(float('nan'), acc_data_type)
    elif contains_pos_inf:
        return True, FPAccumulator(float('inf'), acc_data_type)
    elif contains_neg_inf:
        return True, FPAccumulator(float('-inf'), acc_data_type)
    else:
        return False, None

def high_precision_to_fp32(high_precision_value, mantissa_bits=23, prec=384):
    # Set the precision
    mp.prec = prec

    # Extract components of the high precision value
    sign = 0 if high_precision_value >= 0 else 1
    high_precision_value = abs(high_precision_value)

    # Check for special cases
    if high_precision_value == 0:
        return struct.unpack('>f', b'\x00\x00\x00\x00')[0]
    elif mp.isinf(high_precision_value):
        return struct.unpack('>f', b'\x7f\x80\x00\x00')[0] if sign == 0 else struct.unpack('>f', b'\xff\x80\x00\x00')[0]
    elif mp.isnan(high_precision_value):
        return struct.unpack('>f', b'\x7f\xc0\x00\x00')[0] if sign == 0 else struct.unpack('>f', b'\xff\xc0\x00\x00')[0]
    
    # Extract mantissa and exponent from mpmath high precision float
    mantissa, exponent = mp.frexp(high_precision_value)  # frexp returns mantissa and exponent such that value = mantissa * 2**exponent
    mantissa *= 2  # Normalize mantissa to be in the range [1, 2)
    exponent -= 1

    print_conditional(f"E: {int_to_binary(exponent, 8)}")
    print_conditional(f"M: {int_to_binary(int(mantissa * (1 << prec)), prec)}")
    
    subnormal = False
    # Handle subnormal numbers
    if exponent < -126:
        # Shift the mantissa to the right by the absolute value of the exponent
        shift = abs(exponent + 126)
        mantissa /= 2 ** shift
        fp32_exponent = 0
        subnormal = True
    else:
        # Convert exponent to FP32 bias format
        fp32_exponent = exponent + 127
    
    # Extract the FP32 mantissa with mantissa_bits bits precision
    mantissa_int = int(mantissa * (1 << mantissa_bits))  # Shift to get mantissa_bits bits of precision
    
    # Apply Round to Nearest, Even (RNE)
    round_bit = (mantissa * (1 << mantissa_bits)) % 1  # Check if there's a fractional part
    if round_bit > 0.5 or (round_bit == 0.5 and mantissa_int % 2 != 0):
        mantissa_int += 1
        if subnormal:
            if mantissa_int >= (1 << (mantissa_bits)):  # Handle carry overflow in mantissa
                mantissa_int = 0
                fp32_exponent += 1
        else:
            if mantissa_int >= (1 << (mantissa_bits+1)):  # Handle carry overflow in mantissa
                mantissa_int = mantissa_int // 2
                fp32_exponent += 1

    if fp32_exponent >= 255:
        # Overflow, return infinity
        return struct.unpack('>f', b'\x7f\x80\x00\x00')[0] if sign == 0 else struct.unpack('>f', b'\xff\x80\x00\x00')[0]
        
    # Assemble the final FP32 binary representation
    fp32_bin = (sign << 31) | (fp32_exponent << 23) | ((mantissa_int & ((1 << mantissa_bits) - 1)) << (23-mantissa_bits))
    
    # Convert the binary representation to a 32-bit float
    return struct.unpack('>f', struct.pack('>I', fp32_bin))[0]

def compute_mp_result(a, b, scale, s, prec=384):
    # Set the precision
    mp.prec = prec

    # Convert inputs to high precision mpmath.mpf types
    a_high_precision = [mp.mpf(a_val) for a_val in a]
    b_high_precision = [mp.mpf(b_val) for b_val in b]
    scale_high_precision = mp.mpf(scale)
    s_high_precision = mp.mpf(s)

    # Perform the computation at high precision
    return fsum([a_val * b_val for a_val, b_val in zip(a_high_precision, b_high_precision)]) * power(2, scale_high_precision) + s_high_precision

def extract_6bit(val):
    """Get 6 LSBs from 8-bit binary string."""
    return int(val[-6:], 2)

def pack_6bit_chunks(values):
    """Pack 32 6-bit values into 3x64-bit words."""
    packed = 0
    for i in range(32):
        val = extract_6bit(values[i])
        packed |= val << (i * 6)
    return packed

def group_vectors(rows, increments):
    """Extract a_vec and b_vec from 3 input rows."""
    a_vec, b_vec = [], []
    for row in rows:
        inc = next(increments)
        a_part = row[:inc]
        b_part = row[inc:2 * inc]
        a_vec.extend(a_part)
        b_vec.extend(b_part)
    return a_vec, b_vec

def process_csv_for_merged_inputs(csv_file, data_type, vector_size):
    with open(csv_file, mode='r', newline='') as f:
        reader = list(csv.reader(f))  # read all rows first

    updated_rows = []

    if (data_type == "FP6" or data_type == "FP6ALT"):
        increments = itertools.cycle([10, 11, 11])

        # Going over every 3 rows is only necessary for FP6 and FP6ALT
        for i in range(0, len(reader), 3):
            row_group = reader[i:i+3]
            if len(row_group) < 3:
                raise ValueError(f"Expected 3 rows per group, but found {len(row_group)} rows at index {i}.")

            a_vec, b_vec = group_vectors(row_group, increments)

            a_packed = pack_6bit_chunks(a_vec)
            b_packed = pack_6bit_chunks(b_vec)

            a_bin = f"{a_packed:0192b}"
            b_bin = f"{b_packed:0192b}"

            # For each of the 3 rows, replace a_vec and b_vec with one 64-bit word each
            for j in range(3):
                inc = next(increments)
                row = row_group[j]

                # Compute slice
                a_slice = a_bin[(2 - j) * 64 : (3 - j) * 64]
                b_slice = b_bin[(2 - j) * 64 : (3 - j) * 64]

                # Replace the a and b vector parts with 64-bit packed values
                rest = row[2 * inc:]  # keep the rest after a + b parts
                new_row = [a_slice, b_slice] + rest
                updated_rows.append(new_row)
    else:
        if (data_type == "FP4"):
            inc = vector_size // 2
        else:
            inc = vector_size

        # For other data types, we can process each row independently
        for row in reader:            
            # Extract a_vec and b_vec
            a_vec = row[:inc]
            b_vec = row[inc:2 * inc]

            # Pack the vectors into 64-bit words
            a_bin = ''.join(a_vec)
            b_bin = ''.join(b_vec)

            # Replace the a and b vector parts with 64-bit packed values
            rest = row[2 * inc:]
            new_row = [a_bin, b_bin] + rest
            updated_rows.append(new_row)

    # Overwrite the file
    with open(csv_file, mode='w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(updated_rows)

    print(f"✅ File '{csv_file}' updated: each row now starts with 64-bit packed a and b.")

    if (data_type == "FP6" or data_type == "FP6ALT"):
        unroll_csv(csv_file, unroll_factor=8)  # Unroll the CSV file after processing

def unroll_csv(csv_file, unroll_factor=8):
    with open(csv_file, mode='r', newline='') as f:
        reader = list(csv.reader(f))  # read all rows first

    updated_rows = []

    # Shuffle the rows to [0, 3, 6, 9, 12, 15, 18, 21, 1, 4, 7, 10, 13, 16, 19, 22, ...] (unroll=8)
    merged_ops = 3
    for i in range(0, len(reader), merged_ops * unroll_factor):
        # Get a chunk of rows for unrolling
        chunk = reader[i:i + merged_ops * unroll_factor]
        if len(chunk) < merged_ops * unroll_factor:
            raise ValueError(f"Expected {merged_ops * unroll_factor} rows per chunk, but found {len(chunk)} rows at index {i}.")

        # Shuffle the rows within the chunk
        for j in range(merged_ops):
            for k in range(unroll_factor):
                updated_rows.append(chunk[j + k * merged_ops])

    # Overwrite the file
    with open(csv_file, mode='w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(updated_rows)

    print(f"✅ File '{csv_file}' unrolled: rows shuffled.")