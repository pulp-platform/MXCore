import random
from math import isnan
import struct

from .utils import print_conditional

class FP9:
    def __init__(self, data_type="FP8", binary="000000000"):
        """
        Initialize an FP9 object from a 9-bit binary string.

        Args:
            binary (str): The 9-bit binary string representation.
        """

        self.data_type = data_type
        self.binary = binary

        self.is_integer = False
        
        if data_type == "FP8": #e5m2
            self.exponent_bits = 5
        elif data_type == "FP8ALT": #e4m3
            self.exponent_bits = 4
        elif data_type == "FP6": #e3m2
            self.exponent_bits = 3
        elif data_type == "FP6ALT": #e2m3
            self.exponent_bits = 2
        elif data_type == "FP4": #e2m1
            self.exponent_bits = 2
        elif data_type == "INT8": #int8
            self.exponent_bits = 1
            self.is_integer = True

        self.bias = (1 << (self.exponent_bits - 1)) - 1  # Bias = 15 for 5-bit exponent, 7 for 4-bit exponent
        self.super_mantissa_bits = 3 # for FP9

        if data_type == "FP8":
            self.precision_bits = 3
        elif data_type == "FP8ALT":
            self.precision_bits = 4
        elif data_type == "FP6":
            self.precision_bits = 3
        elif data_type == "FP6ALT":
            self.precision_bits = 4
        elif data_type == "FP4":
            self.precision_bits = 2
        elif data_type == "INT8":
            self.precision_bits = 8

        self.mantissa_bits = self.precision_bits - 1

        self.exponent_min = 1 - self.bias
        if data_type == "FP8":
            self.exponent_max = self.bias
        else:
            self.exponent_max = self.bias + 1 # no inf

        self.min_value = 2 ** (self.exponent_min + 1 - self.precision_bits)
        self.min_normal = 2 ** self.exponent_min

        if data_type == "FP8ALT":
            self.max_value = 2 ** self.exponent_max * (2 - 2 ** -(self.precision_bits-2)) # no inf but nan
        else:
            self.max_value = 2 ** self.exponent_max * (2 - 2 ** -(self.precision_bits-1))
        
        # Split the binary representation
        self.sign, self.exponent, self.nonbiased_exponent, self.mantissa, self.significand = self.split_fp9()
        
        # Convert to value
        if data_type == "INT8":
            self.value = int(self.binary, 2) - (1 << 8) if self.binary[0] == '1' else int(self.binary, 2)
        else:
            self.value = self.binary_to_float()

    def split_fp9(self): # TODO: Add support for FP6, FP6ALT, FP4
        """
        Split the binary representation of an FP9 number into sign, exponent, and mantissa.

        Returns:
            tuple: The sign, exponent, nonbiased exponent, mantissa, and significand bits.
        """
        sign = int(self.binary[0], 2)  
        exponent = int(self.binary[1:6], 2)
        mantissa = int(self.binary[6:], 2)

        if exponent == 0:
            nonbiased_exponent = self.exponent_min
            significand = mantissa
        else:
            nonbiased_exponent = exponent - self.bias
            significand = (1 << self.super_mantissa_bits) | mantissa
        
        return sign, exponent, nonbiased_exponent, mantissa, significand

    def binary_to_float(self):
        """
        Convert a 9-bit binary representation to a floating-point number.

        Args:
            binary (str): The 9-bit binary representation.

        Returns:
            float: The floating-point number.
        """

        # Special cases: Inf or NaN
        if (self.data_type == "FP8" and self.exponent == 31) or (self.data_type == "FP8ALT" and self.exponent == 15):
            if self.data_type == "FP8":
                if self.mantissa == 0:
                    return float("inf") if self.sign == 0 else float("-inf")
                else:
                    return float("nan")
            elif self.data_type == "FP8ALT" and self.mantissa == 7: # no inf for FP8ALT (e4m3)
                return float("nan")
    
        value = self.significand / (1 << self.super_mantissa_bits) * (2 ** self.nonbiased_exponent)
        return -value if self.sign == 1 else value
        
    def __repr__(self):
        binary_exponent = f"{self.exponent:05b}"
        binary_mantissa = f"{self.mantissa:03b}"
        binary_significand = f"{self.significand:04b}"
        return (f"FP9(value={self.value:.8f}, sign={self.sign}, "
                f"exponent={self.exponent} (binary={binary_exponent}), "
                f"mantissa={self.mantissa} (binary={binary_mantissa}), "
                f"significand={self.significand} (binary={binary_significand}), "
                f"nonbiased exponent={self.nonbiased_exponent})")

    @classmethod
    def generate_random(cls, seed=None, data_type="FP8", allow_special_values=True, set_max=False, set_min=False):
        """
        Generate a random FP9 value.

        Args:
            seed (int, optional): A seed for the random number generator. Defaults to None.
            allow_special_values (bool, optional): If True, exponent can be up to 31/15 (special values).
                                                   If False, exponent is limited to 30/14. Defaults to True.

        Returns:
            FP9: A randomly generated FP9 value.
        """
        if seed is not None:
            random.seed(seed)
        
        sign = random.randint(0, 1)

        if data_type == "FP8":
            # E5M2 format
            if set_max:
                sign = 0
                exponent = 30
                mantissa = 3 << 1
            elif set_min:
                sign = 0
                exponent = 0
                mantissa = 1 << 1
            else:
                if allow_special_values:
                    exponent = random.randint(0, 31)
                else:
                    exponent = random.randint(0, 30)
                mantissa = random.randint(0, 3) << 1
        elif data_type == "FP8ALT":
            # E4M3 format
            if set_max: # no inf but nan
                sign = 0
                exponent = 15
                mantissa = 6
            elif set_min:
                sign = 0
                exponent = 0
                mantissa = 1
            else:
                if allow_special_values:
                    exponent = random.randint(0, 15)
                else:
                    exponent = random.randint(0, 14)
                mantissa = random.randint(0, 7)
        elif data_type == "FP6":
            # E3M2 format
            if set_max:
                sign = 0
                exponent = 7 # no inf/nan
                mantissa = 3 << 1
            elif set_min:
                sign = 0
                exponent = 0
                mantissa = 1 << 1
            else:
                exponent = random.randint(0, 7)
                mantissa = random.randint(0, 3) << 1
        elif data_type == "FP6ALT":
            # E2M3 format
            if set_max:
                sign = 0
                exponent = 3 # no inf/nan
                mantissa = 7
            elif set_min:
                sign = 0
                exponent = 0
                mantissa = 1
            else:
                exponent = random.randint(0, 3)
                mantissa = random.randint(0, 7)
        elif data_type == "FP4":
            # E2M1 format
            if set_max:
                sign = 0
                exponent = 3 # no inf/nan
                mantissa = 1 << 2
            elif set_min:
                sign = 0
                exponent = 0
                mantissa = 1 << 2
            else:
                exponent = random.randint(0, 3)
                mantissa = random.randint(0, 1) << 2
        elif data_type == "INT8":
            # INT8 format
            if set_max:
                integer = 127
            elif set_min:
                integer = -128
            else:
                integer = random.randint(-128, 127)

        if data_type == "INT8":
            binary = f"{integer & 0xFF:08b}"
        else:
            binary = f"{sign:01b}{exponent:05b}{mantissa:03b}"

        return cls(data_type, binary)
    
    @classmethod
    def float_to_mx(cls, value, data_type = "FP8"): # TODO: Add support for FP6, FP6ALT, FP4

        packed = struct.pack('!f', value)
    
        # Convert the packed bytes into a binary string
        binary_string = ''.join(f'{byte:08b}' for byte in packed)

        # Extract sign (1 bit), exponent (8 bits), mantissa (23 bits)
        sign = binary_string[0]  # First bit is the sign
        exponent = binary_string[1:9]  # Next 8 bits are the exponent
        mantissa = binary_string[9:]  # Remaining 23 bits are the mantissa

        # Convert exponent to decimal and apply bias correction (Bias = 127 for single-precision)
        unbiased_exponent_value = int(exponent, 2) - 127

        # Exponent 5bits, Mantissa 2bits
        if data_type == "FP8":
            exponent = unbiased_exponent_value + 15 # adding bias
            if unbiased_exponent_value > 15: # overflow
                raise OverflowError(f"Value {value} is too large to be represented in FP8ALT format.")
            elif unbiased_exponent_value < -14: # subnormal
                exponent = 0
                exp_diff = -14 - unbiased_exponent_value
                mantissa = '0' * (exp_diff-1) + '1' + mantissa
            exponent_bin = f"{exponent:05b}"
            mantissa_bin = f"{mantissa[:2]}0"
            binary_string = f"{sign}{exponent_bin}{mantissa_bin}"
        # Exponent 4bits, Mantissa 3bits
        elif data_type == "FP8ALT":
            exponent = unbiased_exponent_value + 7
            if unbiased_exponent_value > 8: # overflow
                raise OverflowError(f"Value {value} is too large to be represented in FP8ALT format.")
            elif unbiased_exponent_value < -6: # subnormal
                exponent = 0
                exp_diff = -6 - unbiased_exponent_value
                mantissa = '0' * (exp_diff-1) + '1' + mantissa
            exponent_bin = f"0{exponent:04b}"
            mantissa_bin = f"{mantissa[:3]}"
            binary_string = f"{sign}{exponent_bin}{mantissa_bin}"
        # E3M2
        elif data_type == "FP6":
            exponent = unbiased_exponent_value + 3
            if unbiased_exponent_value > 4: # overflow
                raise OverflowError(f"Value {value} is too large to be represented in FP6 format.")
            elif unbiased_exponent_value < -2: # subnormal
                exponent = 0
                exp_diff = -2 - unbiased_exponent_value
                mantissa = '0' * (exp_diff-1) + '1' + mantissa
            exponent_bin = f"00{exponent:03b}"
            mantissa_bin = f"{mantissa[:2]}0"
            binary_string = f"{sign}{exponent_bin}{mantissa_bin}"
        # E2M3
        elif data_type == "FP6ALT":
            exponent = unbiased_exponent_value + 1
            if unbiased_exponent_value > 2: # overflow
                raise OverflowError(f"Value {value} is too large to be represented in FP6ALT format.")
            elif unbiased_exponent_value < 0: # subnormal
                exponent = 0
                exp_diff = 0 - unbiased_exponent_value
                mantissa = '0' * (exp_diff-1) + '1' + mantissa
            exponent_bin = f"000{exponent:02b}"
            mantissa_bin = f"{mantissa[:3]}"
            binary_string = f"{sign}{exponent_bin}{mantissa_bin}"
        # E2M1
        elif data_type == "FP4":
            exponent = unbiased_exponent_value + 1
            if unbiased_exponent_value > 2: # overflow
                raise OverflowError(f"Value {value} is too large to be represented in FP4 format.")
            elif unbiased_exponent_value < 0: # subnormal
                exponent = 0
                exp_diff = 0 - unbiased_exponent_value
                mantissa = '0' * (exp_diff-1) + '1' + mantissa
            exponent_bin = f"000{exponent:02b}"
            mantissa_bin = f"{mantissa[:1]}00"
            binary_string = f"{sign}{exponent_bin}{mantissa_bin}"
        elif data_type == "INT8":
            scaled_value = value * 2**6
            # check if scaled value is integer
            if not float(scaled_value).is_integer():
                raise ValueError(f"Value {value} cannot be represented exactly in INT8 format.")
            integer = int(scaled_value)
            if integer > 127 or integer < -128:
                raise OverflowError(f"Value {value} is too large to be represented in INT8 format.")
            binary_string = f"{integer & 0xFF:08b}"

        return cls(data_type, binary_string)
