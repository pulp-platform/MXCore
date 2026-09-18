import random
from math import isnan

class Scale:
    def __init__(self, nonbiased_exponent=0):
        """
        Initialize a Scale object from a non-biased exponent of 8 bits.

        Args:
            nonbiased_exponent (int): The non-biased exponent of the scale.
        """
        self.nonbiased_exponent = nonbiased_exponent

        self.exponent_bits = 8
        self.bias = (1 << (self.exponent_bits - 1)) - 1

        self.exponent = self.nonbiased_exponent + self.bias
        self.binary = bin(self.exponent)[2:].zfill(self.exponent_bits)
        
        # Convert to float value
        self.value = self.nonbiased_exponent
        if self.value == self.bias + 1:
            self.value = float("nan")
        
    def __repr__(self):
        return (f"Scale(value={self.value:.8f}, "
                f"exponent={self.exponent} (binary={self.binary})")

    @classmethod
    def generate_random(cls, seed=None, range=[0, 255]):
        """
        Generate a random Scale value.
        """

        if seed is not None:
            random.seed(seed)
        
        nonbiased_exponent = random.randint(range[0], range[1])
        
        return cls(nonbiased_exponent)

    @classmethod
    def use_external_value(cls, value=None):
        """
        Use a precomputed value.
        """
        
        nonbiased_exponent = int(value)
        
        return cls(nonbiased_exponent)

