# Block FP Dot Product with FPAccumulator Accumulation

import numpy as np
from math import isclose, isnan, isinf
from mpmath import mp
import csv

from .fp9 import *
from .fp_accumulator import *
from .utils import *
from .norm_round import *

EXPORT = False

def multiply_fp9(constants, fp9_a, fp9_b):
    """
    Multiply two FP9 values using their mantissa and exponent bits.

    Args:
        fp9_a (FP9): The first FP9 value.
        fp9_b (FP9): The second FP9 value.
        anchor (int, optional): The anchor point for shifting. Defaults to ANCHOR.

    Returns:
        FP9: The result of the multiplied significand.
    """
    ANCHOR = constants["ANCHOR"]
    SOP_SHIFT = constants["SOP_SHIFT"]
    SOP_FIXED_WIDTH = constants["SOP_FIXED_WIDTH"]
    INT_SOP_WIDTH = constants["INT_SOP_WIDTH"]

    if fp9_a.is_integer and fp9_b.is_integer:
        # If both are integers, multiply them directly
        significand_mul = fp9_a.value * fp9_b.value
        print_conditional(f"Both FP9 values are integers: {fp9_a.value} * {fp9_b.value} = {significand_mul}")

        # Shift the result to the integer position
        significand_result = significand_mul << ANCHOR
        
        # Highlight the result in binary
        highlighted = int_to_binary(significand_result, (INT_SOP_WIDTH + ANCHOR))
        print_conditional(f"Significand result in binary: {highlighted}, in decimal: {significand_result}")
    else:
        # Extract sign, exponent, and significand
        sign_a, nonbiased_exponent_a, significand_a = fp9_a.sign, fp9_a.nonbiased_exponent, fp9_a.significand
        sign_b, nonbiased_exponent_b, significand_b = fp9_b.sign, fp9_b.nonbiased_exponent, fp9_b.significand
        
        # Calculate the resulting sign
        sign_result = sign_a ^ sign_b

        # Multiply the significands (9b)
        significand_mul = significand_a * significand_b
        if sign_result == 1:
            significand_mul = -significand_mul
        
        # Adjust the resulting exponent (excess-31 notation)
        # Note: subnormal exponent is zero but real value is 1 (-14)
        exponent_e31_sum = nonbiased_exponent_a + nonbiased_exponent_b
        
        # Right shift the significand by anchor point - exponent
        # sum of four 9-bit numbers can be at most 11 bits, for 69 bits output we need to shift by 69 - 11 = 58
        # 58-30=28 plus inherit 6 fractional bits from the multiplication -> point moves to 28+6=34
        significand_result = significand_mul << (SOP_SHIFT + exponent_e31_sum)

        print_conditional(f"exponent_e31_sum: {exponent_e31_sum}")
        print_conditional(f"significand_mul: {significand_mul}")
        print_conditional(f"significand_mul in binary: {int_to_binary(significand_mul, 9)}")

        highlighted = int_to_binary(significand_result, SOP_FIXED_WIDTH)

        print_conditional(f"significand_result in binary: {highlighted}, in decimal: {significand_result}")

    return significand_result

def multiply_fp9_vectors(constants, fp9_vector_a, fp9_vector_b):
    """
    Multiply two vectors of FP9 values element-wise.

    Args:
        fp9_vector_a (list): The first list of FP9 values.
        fp9_vector_b (list): The second list of FP9 values.

    Returns:
        list: A list of FP9 objects, each representing the result of the element-wise multiplication.
    """
    if len(fp9_vector_a) != len(fp9_vector_b):
        raise ValueError("Vectors must have the same length")
    
    return [multiply_fp9(constants, fp9_a, fp9_b) for fp9_a, fp9_b in zip(fp9_vector_a, fp9_vector_b)]

def sum_fp9_fp32(constants, fp_format, fp32, fp9_significand_result, fp9_scale_a, fp9_scale_b):
    """
    Sum an FPAccumulator value with an FP9 multiplication result, properly adjusting for scaling.

    Args:
        fp32 (FPAccumulator): The FPAccumulator value.
        fp9_significand_result (int): The FP9 multiplication significand result.
        fp9_scale (int): The scale applied to the FP9 result.

    Returns:
        int: The summed significand result.
    """
    ANCHOR = constants["ANCHOR"]
    MAX_SHIFT = constants["MAX_SHIFT"]
    FP_ACCUMULATOR_POINT = constants["FP_ACCUMULATOR_POINT"]
    FIXED_ACCUMULATOR_WIDTH = constants["FIXED_ACCUMULATOR_WIDTH"]

    # Calculate the block scale
    scale_9b = fp9_scale_a.value + fp9_scale_b.value

    # Calculate the scaled anchor point
    scaled_anchor = ANCHOR - scale_9b

    # Original point is at 23, needs to be up shifted to scaled_anchor (34-scale)
    shift_fp32_acc = scaled_anchor - FP_ACCUMULATOR_POINT + fp32.nonbiased_exponent

    # Check if the FP32 value is negative
    fp32_significand_result = -fp32.significand if fp32.sign == 1 else fp32.significand

    # SoP doesn't change the accumulator    
    if shift_fp32_acc > MAX_SHIFT:
        final_result = fp32
        print_conditional(f"Accumulator exceeds max shift with shift of {shift_fp32_acc}")
        # Default values for special cases
        shifted_significant_result = 0
        sum_significant = shifted_significant_result + fp9_significand_result
        normalized = '0'
        exponent = 0
    # Perform the appropriate shift
    else:
        if shift_fp32_acc >= 0:
            shifted_significant_result = fp32_significand_result << shift_fp32_acc
            rounding_bits = 0
            bin_rounding_bits = None
        else:
            print_conditional("Shifting accumulator to the right by", -shift_fp32_acc) # up to -244
            # Save the rounding bits after 94th bit
            rounding_bits = fp32_significand_result & ((1 << -shift_fp32_acc) - 1)
            bin_rounding_bits = int_to_binary(rounding_bits, -shift_fp32_acc)
            shifted_significant_result = fp32_significand_result >> -shift_fp32_acc
    
            print_conditional(f"Unshifted FP32 significand result:\n{int_to_binary(fp32_significand_result, FIXED_ACCUMULATOR_WIDTH)}")
            print_conditional(f"Rounding bits: {bin_rounding_bits}")

        # Sum the shifted FP32 significand result with the FP9 significand result
        sum_significant = shifted_significant_result + fp9_significand_result

        print_conditional(f"FP9 multiplication significand result:\n{int_to_binary(fp9_significand_result, FIXED_ACCUMULATOR_WIDTH)}")

        start_bits = FIXED_ACCUMULATOR_WIDTH - (FP_ACCUMULATOR_POINT + 1) - shift_fp32_acc
        highlighted = highlight_bits(int_to_binary(shifted_significant_result, FIXED_ACCUMULATOR_WIDTH), start_bits, start_bits + FP_ACCUMULATOR_POINT)

        print_conditional(f"Shifted FP32 significand result:\n{highlighted}")
        print_conditional(f"Summed significand result:\n{int_to_binary(sum_significant, FIXED_ACCUMULATOR_WIDTH)}")

        # Handle the final result based on the scaled anchor point
        if scaled_anchor < 0: # All integer bits
            print_conditional(f"Result in binary with a scale of {-scaled_anchor}:\n{int_to_binary(sum_significant, FIXED_ACCUMULATOR_WIDTH)}")
        elif scaled_anchor >= FIXED_ACCUMULATOR_WIDTH: # All fractional bits
            print_conditional(f"Result in binary with a scale of {-scaled_anchor}:\n{int_to_binary(sum_significant, FIXED_ACCUMULATOR_WIDTH)}")
        else:
            integer_bits = sum_significant >> scaled_anchor
            fractional_bits = sum_significant & ((1 << scaled_anchor) - 1)
            
            print_conditional(f"Integer {FIXED_ACCUMULATOR_WIDTH-scaled_anchor} bits of the result in binary:\n{int_to_binary(integer_bits, FIXED_ACCUMULATOR_WIDTH-scaled_anchor)}, decimal: {integer_bits}")
            print_conditional(f"Fractional {scaled_anchor} bits of the result in binary:\n{int_to_binary(fractional_bits, scaled_anchor)}, decimal: {fractional_bits / 2**scaled_anchor}")
            print_conditional(f"Result in binary:\n{int_to_binary(sum_significant, FIXED_ACCUMULATOR_WIDTH)}")

        final_result, normalized, exponent = fixed_to_FP32(FIXED_ACCUMULATOR_WIDTH, fp_format, sum_significant, bin_rounding_bits, scaled_anchor)

    return final_result, shift_fp32_acc, shifted_significant_result, sum_significant, normalized, exponent

def sum_fp9_sop_fp32(constants, fp9_vector_a, fp9_vector_b, fp32, scale_a, scale_b, data_type="FP8", acc_data_type="FP32", csv_file=None):
    """
    Compute the sum of products (SOP) of two FP9 vectors and sum with an FPAccumulator value.

    Args:
        a (list): First vector of floating-point numbers.
        b (list): Second vector of floating-point numbers.
        s (float): FPAccumulator value to sum with the SOP of vectors a and b.
        scale (int, optional): The scale applied to the result. Defaults to 0.

    Returns:
        float: The decimal result of the computation.
    """
    fp_format = FPFormats[acc_data_type]

    # Compute high precision result using mpmath
    actual_result = compute_mp_result([a.value for a in fp9_vector_a], [b.value for b in fp9_vector_b], scale_a.value + scale_b.value, fp32.value)
    actual_result_fp32 = high_precision_to_fp32(actual_result, fp_format.mantissa_bits)
    
    print_conditional(f"Actual Result (mp): {actual_result}")
    
    # Check for special cases
    is_special, final_result = check_special_cases([a.value for a in fp9_vector_a], [b.value for b in fp9_vector_b], scale_a.value, scale_b.value, fp32.value, acc_data_type)
    if is_special == False:
        print_conditional("Computing SOP of two vectors of FP9 values and summing with an FPAccumulator value...")
        for i, (fp9_a, fp9_b) in enumerate(zip(fp9_vector_a, fp9_vector_b)):
            print_conditional(f"FP9 (a[{i}]): {fp9_a}")
            print_conditional(f"FP9 (b[{i}]): {fp9_b}")
        print_conditional(f"Scale a: {scale_a}")
        print_conditional(f"Scale b: {scale_b}")
        print_conditional(f"FPAccumulator(s): {fp32}")

        # Compute using the datapath  
        products_fp9_vectors = multiply_fp9_vectors(constants, fp9_vector_a, fp9_vector_b)
        sum_fp9_vectors = sum(products_fp9_vectors)

        print_conditional(f"Result of SOP in decimal: {sum_fp9_vectors}")

        # Add SoP and Acc
        final_result, shift_fp32_acc, shifted_significant_result, sum_significant, normalized, exponent = sum_fp9_fp32(constants, fp_format, fp32, sum_fp9_vectors, scale_a, scale_b)

        print_conditional(f"Actual Result (FP32): {FPAccumulator(actual_result_fp32)}")
        print_conditional(f"Final FP32 Result: {final_result}")
    else:
        # Default values for special cases
        sum_fp9_vectors = 0
        shift_fp32_acc = 0
        shifted_significant_result = 0
        sum_significant = 0
        normalized = '0'
        exponent = 0

    # Check if the conversion is correct
    if isnan(actual_result_fp32) and isnan(final_result.value):
        print_conditional("CORRECT: Conversion to FP32 is correct!")
    elif final_result.value == actual_result_fp32:
        print_conditional("CORRECT: Conversion to FP32 is correct!")
        # except for infinities, which are not close to actual result
        if not isinf(final_result.value):
            if not isclose(final_result.value, actual_result, rel_tol=fp_format.rel_tol, abs_tol=fp_format.abs_tol):
                print_conditional("WARNING: Conversion to FP32 is close but not exact!")
                raise ValueError("Conversion to FP32 is close but not exact!")
    else:
        print("ERROR: Conversion to FP32 is incorrect!")
        # also print which bit differs
        print_conditional(f"Bit difference: {int(final_result.binary, 2) ^ int(FPAccumulator(actual_result_fp32).binary, 2):032b}")
        raise ValueError("Conversion to FP32 is incorrect!")

    if EXPORT:
        export_test_vectors(fp9_vector_a, fp9_vector_b, scale_a, scale_b, fp32, final_result, sum_fp9_vectors, shift_fp32_acc, shifted_significant_result, sum_significant, normalized, exponent, data_type=data_type, acc_data_type=acc_data_type, csv_file=csv_file)
    
    return final_result

def export_test_vectors(fp9_vector_a, fp9_vector_b, scale_a, scale_b, fp32, result, sum_fp9_vectors, shift_fp32_acc, shifted_significant_result, sum_significant, normalized, exponent, data_type="FP8", acc_data_type="FP32", csv_file=None):
    """
    Export the test vectors and result to a file.

    Args:
        fp9_vector_a (list): The first list of FP9 values.
        fp9_vector_b (list): The second list of FP9 values.
        fp32 (float): The FPAccumulator value.
        scale (int): The scale factor.
        result (float): The result of the computation.
    """
    # Preprocess the FP9 vectors for SystemVerilog
    vector_a = [format_fp9_cvfpu(fp9) for fp9 in fp9_vector_a]
    vector_b = [format_fp9_cvfpu(fp9) for fp9 in fp9_vector_b]

    if data_type == "FP4": # pack 2 FP4 into 1 FP8
        combined_vector_a = []
        combined_vector_b = []
        for i in range(0, len(vector_a), 2):
            combined_vector_a.extend([vector_a[i+1][-4:] + vector_a[i][-4:]])
            combined_vector_b.extend([vector_b[i+1][-4:] + vector_b[i][-4:]])
        vector_a = combined_vector_a
        vector_b = combined_vector_b

    if acc_data_type == "BF16":
        fp32_binary ='1'*16 + fp32.binary[0:16]
        result_binary = '1'*16 + result.binary[0:16]
    else:
        fp32_binary = fp32.binary
        result_binary = result.binary

    # extend normalized to 94 bits
    normalized = normalized + '0'*(94-len(normalized))
    
    print(f"Exporting test vectors to {csv_file}...")
    with open(csv_file, mode='a', newline='') as file:
        writer = csv.writer(file)

        row = []
        row.extend(vector_a)
        row.extend(vector_b)
        
        # Add the remaining static elements
        row.extend([
            scale_a.binary,
            scale_b.binary,
            fp32_binary,
            result_binary,
            sum_fp9_vectors,
            shift_fp32_acc,
            shifted_significant_result,
            sum_significant,
            normalized,
            exponent
        ])
        
        # Write the row to the CSV file
        writer.writerow(row)
