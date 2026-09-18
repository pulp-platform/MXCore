import random
import struct
from dataclasses import dataclass

@dataclass(frozen=True)
class FPFormat:
    name: str
    mantissa_bits: int
    exponent_bits: int
    rel_tol: float
    abs_tol: float

    @property
    def bias(self):
        return (1 << (self.exponent_bits - 1)) - 1


# Define supported FP formats
FPFormats = {
    "FP32": FPFormat("FP32", mantissa_bits=23, exponent_bits=8, rel_tol=1e-7, abs_tol=1e-9),
    "BF16": FPFormat("BF16", mantissa_bits=7,  exponent_bits=8, rel_tol=1e-2, abs_tol=1e-3),
    "FP16": FPFormat("FP16", mantissa_bits=10, exponent_bits=5, rel_tol=5e-3, abs_tol=1e-3),
}


class FPAccumulator:
    def __init__(self, value=0.0, data_type="FP32"):
        """
        Initialize an FPAccumulator with a specific floating-point format and value.
        """
        if data_type not in FPFormats:
            raise ValueError(f"Unsupported data_type: {data_type}")

        self.format = FPFormats[data_type]
        self.value = value

        self.mantissa_bits = self.format.mantissa_bits
        self.exponent_bits = self.format.exponent_bits
        self.bias = self.format.bias

        self.binary = self.float_to_binary(value)
        self.hex = self.extract_hex_from_bin_str()
        self.sign, self.exponent, self.mantissa, self.significand = self.split_fp(self.binary)
        self.nonbiased_exponent = self.exponent - self.bias if self.exponent != 0 else -self.bias + 1

    def float_to_binary(self, value):
        """
        Convert float to binary string based on the current data type.
        """
        if self.format.name == "FP32":
            [bits] = struct.unpack(">L", struct.pack(">f", value))
            return f"{bits:032b}"
        elif self.format.name == "BF16":
            [full_bits] = struct.unpack(">L", struct.pack(">f", value))
            bf16_bits = (full_bits >> 16) & 0xFFFF
            return f"{bf16_bits:016b}"

    def split_fp(self, binary):
        """
        Extract sign, exponent, mantissa, and significand from binary string.
        """
        sign = int(binary[0], 2)
        exponent = int(binary[1:9], 2)
        mantissa = int(binary[9:], 2)

        if exponent == (1 << self.exponent_bits) - 1:  # Inf or NaN
            significand = 0 if mantissa == 0 else (1 << self.mantissa_bits) | mantissa
        elif exponent == 0:  # subnormal or zero
            significand = mantissa if mantissa != 0 else 0
        else:
            significand = (1 << self.mantissa_bits) | mantissa

        # For BF16 we align to 32-bit for super format
        if self.format.name == "BF16":
            return sign, exponent, mantissa << 16, significand << 16
        else:
            return sign, exponent, mantissa, significand

    @staticmethod
    def binary_to_float(binary):
        int_rep = int(binary, 2)
        packed = struct.pack('>I', int_rep)
        return struct.unpack('>f', packed)[0]

    @staticmethod
    def binary_to_value(binary, data_type="FP32"):
        int_rep = int(binary, 2)
        if data_type == "FP32":
            packed = struct.pack('>I', int_rep)
            return struct.unpack('>f', packed)[0]
        elif data_type == "BF16":
            int32 = int_rep << 16
            packed = struct.pack('>I', int32)
            return struct.unpack('>f', packed)[0]

    def extract_hex_from_bin_str(self):
        if self.format.name == "BF16":
            # Take the first 16 bits (BF16 in upper half)
            bf16_bits = self.binary[:16]
            bf16_int = int(bf16_bits, 2)
            return f"0x{bf16_int:04x}"
        elif self.format.name == "FP32":
            fp32_int = int(self.binary, 2)
            return f"0x{fp32_int:08x}"
        else:
            raise ValueError("Unsupported format for hex extraction")

    def __repr__(self):
        binary_exponent = f"{self.exponent:08b}"
        binary_significand = f"{self.significand:0{self.mantissa_bits + 1}b}"
        return (f"{self.format.name}(value={self.value}, sign={self.sign}, "
                f"nonbiased exponent={self.nonbiased_exponent} (binary={binary_exponent}), "
                f"significand binary={binary_significand})")

    @classmethod
    def generate_random(cls, data_type="FP32", seed=None, subnormal=False, forced=False, exponent_range=None):
        """
        Generate a random FPAccumulator with specified properties.
        """
        if data_type not in FPFormats:
            raise ValueError(f"Unsupported data_type: {data_type}")

        if seed is not None:
            random.seed(seed)

        fmt = FPFormats[data_type]
        exponent_range = exponent_range or [-fmt.bias, fmt.bias]

        if subnormal:
            sign = random.randint(0, 1)
            exponent = 0
            mantissa = random.randint(1, (1 << fmt.mantissa_bits) - 1)
        elif forced:
            sign = 0
            exponent_offset = random.randint(*exponent_range)
            exponent = fmt.bias + exponent_offset
            mantissa = random.randint(0, (1 << fmt.mantissa_bits) - 1)
        else:
            if data_type == "FP32":
                raw = random.getrandbits(32)
                value = struct.unpack('>f', struct.pack('>I', raw))[0]
                return cls(value, data_type)
            elif data_type == "BF16":
                raw = random.getrandbits(16)
                fp32_bits = raw << 16
                value = struct.unpack('>f', struct.pack('>I', fp32_bits))[0]
                return cls(value, data_type)

        raw_bits = (sign << (fmt.exponent_bits + fmt.mantissa_bits)) | (exponent << fmt.mantissa_bits) | mantissa

        if data_type == "BF16":
            fp32_bits = raw_bits << 16
            value = struct.unpack('>f', struct.pack('>I', fp32_bits))[0]
        else:
            value = struct.unpack('>f', struct.pack('>I', raw_bits))[0]

        return cls(value, data_type)