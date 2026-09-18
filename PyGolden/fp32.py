import random
import struct

class FP32:
    def __init__(self, value=0.0):
        """
        Initialize an FP32 object from a floating-point number.

        Args:
            value (float): The floating-point number.
        """
        self.value = value
        self.binary = self.float_to_binary(value)
        self.bias = 2 ** (8 - 1) - 1
        self.sign, self.exponent, self.mantissa, self.significand = self.split_fp32(self.binary)
        self.nonbiased_exponent = self.exponent - self.bias
    
    @staticmethod
    def float_to_binary(value):
        """
        Convert a floating-point number to its binary representation.

        Args:
            value (float): The floating-point number.

        Returns:
            str: The binary representation of the floating-point number.
        """
        [d] = struct.unpack(">L", struct.pack(">f", value))
        return f"{d:032b}"
    
    @staticmethod
    def split_fp32(binary):
        """
        Split the binary representation of an FP32 number into sign, exponent, and significand.

        Args:
            binary (str): The binary representation of the FP32 number.

        Returns:
            tuple: The sign, exponent, and significand bits.
        """
        sign = int(binary[0], 2)
        exponent = int(binary[1:9], 2)
        mantissa = int(binary[9:], 2)
        if exponent == 0xFF: # Special values
            if mantissa == 0:
                significand = 0
            else:
                significand = int('1' + binary[9:], 2)
        elif exponent == 0: # Denormalized number
            if mantissa == 0:
                significand = 0
            else:
                exponent = 1
                significand = mantissa
        else: # Normalized number
            significand = int('1' + binary[9:], 2)
        return sign, exponent, mantissa, significand
    
    @staticmethod
    def binary_to_float(binary):
        """
        Convert a binary representation to a floating-point number.

        Args:
            binary (str): The binary representation.

        Returns:
            float: The floating-point number.
        """
        int_rep = int(binary, 2)
        packed = struct.pack('>I', int_rep)
        return struct.unpack('>f', packed)[0]
    
    def __repr__(self):
        binary_exponent = f"{self.exponent:08b}"
        binary_significand = f"{self.significand:024b}"
        return (f"FP32(value={self.value}, sign={self.sign}, "
                f"nonbiased exponent={self.nonbiased_exponent} (binary={binary_exponent}), "
                f"significand binary={binary_significand})")

    @classmethod
    def generate_random(cls, seed=None, subnormal=False, forced=False, exponent_range=[-127, 128]):
        """
        Generate a random FP32 value.

        Args:
            seed (int, optional): A seed for the random number generator. Defaults to None.

        Returns:
            FP32: A randomly generated FP32 value.
        """
        if seed is not None:
            random.seed(seed)

        if subnormal:
            # Generate a random subnormal number
            sign = random.choice([0, 1])
            exponent = 0
            significand = random.randint(0, 0x7FFFFF)
            # Combine the sign, exponent, and significand
            random_float = struct.unpack('!f', struct.pack('!I', (sign << 31) | (exponent << 23) | significand))[0]
        elif forced:
            # Use a forced value
            sign = 0
            exponent = 127 + random.randint(exponent_range[0], exponent_range[1])
            significand = random.randint(0, 0x7FFFFF)
            # Combine the sign, exponent, and significand
            random_float = struct.unpack('!f', struct.pack('!I', (sign << 31) | (exponent << 23) | significand))[0]
        else:
            # Generate a random 32-bit floating-point number
            # This is done by generating a random 32-bit integer and converting it to a float
            random_float = struct.unpack('!f', struct.pack('!I', random.randint(0, 0xFFFFFFFF)))[0]
        return cls(random_float)
    