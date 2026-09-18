from math import isinf

from .utils import *
from .fp9 import *
from .fp_accumulator import *
from .fp_functions import *

def leading_zero_counter(binary_string):
    """
    Count the number of leading sign bits in a binary string.

    Args:
        binary_string (str): A binary string.

    Returns:
        int: The number of leading sign bits.
    """
    count = 0
    for bit in binary_string:
        if bit == '0':
            count += 1
        else:
            break
    return count

def extract_round_mantissa(binary_string, mantissa_width=23):
    """
    Extracts the mantissa_width-bit mantissa from a binary string using Round to Nearest, Even (RNE).
    
    Args:
        binary_string (str): The binary string to extract the mantissa from.
        
    Returns:
        str: The mantissa_width-bit mantissa after rounding.
    """

    # Ensure the binary string is long enough to consider mantissa_width bits and the rounding bits
    if len(binary_string) <= mantissa_width:
        # No need for rounding, just return the mantissa (left-padded to mantissa_width bits if necessary)
        return binary_string.ljust(mantissa_width, '0'), 0

    # Extract the first mantissa_width bits
    mantissa = binary_string[:mantissa_width]
    
    # Get the round bit ((mantissa_width+1)th bit) and sticky bits (bits after the (mantissa_width+1)th)
    round_bit = int(binary_string[mantissa_width]) if len(binary_string) > mantissa_width else 0
    sticky_bits = int(binary_string[(mantissa_width+1):], 2) if len(binary_string) > (mantissa_width+1) else 0

    # Apply Round to Nearest, Even (RNE)
    if round_bit == 1 and (sticky_bits > 0 or int(mantissa[-1]) == 1):
        # Convert mantissa to integer, add 1
        mantissa_int = int(mantissa, 2) + 1
        
        # Check for overflow (if mantissa is now (mantissa_width+1) bits long)
        if mantissa_int >= (1 << mantissa_width):
            # Mantissa overflow: set mantissa to 0 and signal to increment the exponent
            return '0' * mantissa_width, 1
        
        # Convert back to binary
        mantissa = f"{mantissa_int:0{mantissa_width}b}"

    return mantissa, 0

def fixed_to_FP32(FIXED_ACCUMULATOR_WIDTH, fp_format, sum_94b, rounding_bits, scaled_anchor):
    """
    Convert the 94-bit fixed-point sum to a 32-bit floating-point number.

    Args:
        sum_94b (int): The 94-bit fixed-point sum.
        scaled_anchor (int): The scaled anchor value.
        actual_result (int): The actual result of the operation.

    Returns:
        float: The 32-bit floating-point representation of the sum.
    """

    # Convert the 94-bit fixed-point sum to a binary string
    binary_sum = int_to_binary(sum_94b, FIXED_ACCUMULATOR_WIDTH)

    if rounding_bits is None:
        binary_sum_rounding = binary_sum
    else:
        binary_sum_rounding = binary_sum + rounding_bits

    
    sum = int(binary_sum, 2)
    sum_rounding = int(binary_sum_rounding, 2)

    sign = binary_sum[0]
    if sign == "1":
        binary_sum = int_to_binary(-sum, len(binary_sum))
        binary_sum_rounding = int_to_binary(-sum_rounding, len(binary_sum_rounding))

    count = leading_zero_counter(binary_sum_rounding)

    # Calculate the biased exponent (excess-127 form)
    # The exponent-major is -scaled_anchor
    if count == len(binary_sum_rounding): # All bits are zero, so the output
        exponent = 0
    else:
        exponent = 127 - scaled_anchor + (FIXED_ACCUMULATOR_WIDTH-count-1)

    # Subnormal numbers
    if exponent <= 0:
        print_conditional("Subnormal result")
        shift = 1 - exponent
        count -= shift
        exponent = 0

    # Normalize the binary string
    normalized = binary_sum[count+1:]
    normalized_rounding = binary_sum_rounding[count+1:]

    mantissa, increment_exponent = extract_round_mantissa(normalized_rounding, fp_format.mantissa_bits)
    exponent += increment_exponent

    normalized_rounding = highlight_bits(normalized_rounding, len(normalized), len(normalized_rounding))

    print_conditional(f"{'Sign bit:':30} {sign}")
    print_conditional(f"{'Normalized Mantissa:':30} {normalized_rounding}")
    print_conditional(f"{'Rounded Mantissa (23 bits):':30} {mantissa}")

    # Handle special cases
    if exponent >= 255:
        # Overflow
        print_conditional("Overflow")
        if sign == "1":
            return FPAccumulator(float('-inf'), fp_format.name), normalized, exponent
        else:
            return FPAccumulator(float('inf'), fp_format.name), normalized, exponent

    # Combine the sign, exponent, and mantissa into a 32-bit binary string
    binary_fp32 = sign + int_to_binary(exponent, 8) + mantissa + "0" * (23 - fp_format.mantissa_bits)

    # Convert the binary string to a floating-point number
    fp32 = FPAccumulator(FPAccumulator.binary_to_float(binary_fp32), fp_format.name)

    return fp32, normalized, exponent