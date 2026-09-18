import random
import contextlib
import sys
import itertools

from . import fp_functions
from .fp_functions import *
from .fp9 import *
from .scale import *
from .norm_round import *
from .globals import get_constants
from .utils import process_csv_for_merged_inputs

from asap25.linear.layer import load_config

def generate_random_seeds(num_seeds=100, seed=42):
    """
    Generate a list of random seeds.

    Args:
        num_seeds (int, optional): Number of seeds to generate. Defaults to 100.

    Returns:
        list: A list of unique random seeds.
    """
    random.seed(seed)  # Set a fixed seed for reproducibility of the seeds
    return [random.randint(1, 1000000) for _ in range(num_seeds)]

def test_sum_fp9_sop_fp32_with_random_values(data_type="FP8", acc_data_type="FP32", vector_size=4, seed=None, allow_fp9_special_values=True, set_max_fp9=False, set_min_fp9=False, scale_range=[-127, 128], is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, csv_file=None):
    """
    Test the sum_fp9_sop_fp32 function with random FP9 vectors and a random FP32 value.

    Args:
        vector_size (int, optional): The size of the vectors to generate. Defaults to 5.
        scale (int, optional): The scale factor to use in sum_fp9_sop_fp32. Defaults to 0.
        seed (int, optional): A seed for reproducible random number generation. Defaults to None.
    """

    if data_type == "FP4":
        constants = get_constants(vector_size/2) # HW has bits for half the vector size
    elif data_type == "FP6" or data_type == "FP6ALT":
        constants = get_constants((vector_size * 6) // 8) # HW has vector size based on FP8
    else:
        constants = get_constants(vector_size)

    # Set the seed once
    if seed is not None:
        random.seed(seed)

    # Force output to zero
    if force_output_zero: # TODO: Check for types other than FP8/FP8ALT
        fp9_binary_one = "001111000" if data_type == "FP8" else "000111000"
        fp9_binary_minus_one = "101111000" if data_type == "FP8" else "100111000"
        # A is set to zero except for one 1
        random_fp9_a = [FP9(data_type=data_type, binary="000000000") for _ in range(vector_size)]
        random_fp9_a[random.randint(0, vector_size - 1)] = FP9(data_type=data_type, binary=fp9_binary_one)
        # B is set to zero except for one -1
        random_fp9_b = [FP9(data_type=data_type, binary="000000000") for _ in range(vector_size)]
        random_fp9_b[random.randint(0, vector_size - 1)] = FP9(data_type=data_type, binary=fp9_binary_minus_one)
        # Scale is set to zero
        random_scale_a = Scale(0)
        random_scale_b = Scale(0)
        random_acc = FPAccumulator(1)
    else:
        # Generate random FP9 vectors
        random_fp9_a = [FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for _ in range(vector_size)]
        random_fp9_b = [FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for _ in range(vector_size)]

        # Generate a random scale
        random_scale_a = Scale.generate_random(range=scale_range)
        random_scale_b = Scale.generate_random(range=scale_range)

        # Generate a random accumulator value
        random_acc = FPAccumulator.generate_random(data_type=acc_data_type, subnormal=is_fp32_subnormal, forced=force_fp32, exponent_range=exponent_range_fp32)

    # Print generated vectors and FP32 value for reference
    print_conditional(f"Random FP9 Vector A: {[fp9.value for fp9 in random_fp9_a]}")
    print_conditional(f"Random FP9 Vector B: {[fp9.value for fp9 in random_fp9_b]}")
    print_conditional(f"Random Scale A: {random_scale_a.value}")
    print_conditional(f"Random Scale B: {random_scale_b.value}")
    print_conditional(f"Random Acc Value (s): {random_acc.value}")

    # Test the sum_fp9_sop_fp32 function with the generated vectors
    sum_fp9_sop_fp32(constants, random_fp9_a, random_fp9_b, random_acc, random_scale_a, random_scale_b, data_type=data_type, acc_data_type=acc_data_type, csv_file=csv_file)

def run_tests_with_seeds(seeds, data_type="FP8", acc_data_type="FP32", vector_size=4, fp9_scale_range=[-127, 128], allow_fp9_special_values=True, set_max_fp9=False, set_min_fp9=False, is_fp32_subnormal= False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, csv_file=None, output_file="test_output.txt"):
    """
    Run the sum_fp9_sop_fp32_with_random_values test with a set of seeds and randomized scales.

    Args:
        seeds (list): A list of seeds to use for random number generation.
        vector_size (int, optional): The size of the vectors to generate. Defaults to 4.
        output_file (str, optional): The file to write the output to. Defaults to 'test_output3.txt'.
    """

    n_errors= 0

    with open(output_file, 'w') as f:
        # Write the function name at the top
        f.write("Function: run_tests_with_seeds with {} seeds\n\n".format(len(seeds)))
        
        # Redirect stdout to the file
        with contextlib.redirect_stdout(f):
            for idx, seed in enumerate(seeds, start=1):  # start=1 to make the index start from 1
                random.seed(seed)  # Set the seed for reproducibility
                print(f"Vector {idx}: Running test with seed: {seed}")

                try:
                    test_sum_fp9_sop_fp32_with_random_values(data_type=data_type, acc_data_type=acc_data_type,
                                                             vector_size=vector_size, seed=seed, 
                                                             allow_fp9_special_values=allow_fp9_special_values,
                                                             set_max_fp9=set_max_fp9, set_min_fp9=set_min_fp9,
                                                             scale_range=fp9_scale_range,
                                                             is_fp32_subnormal=is_fp32_subnormal, 
                                                             force_fp32=force_fp32, 
                                                             exponent_range_fp32=exponent_range_fp32, 
                                                             force_output_zero=force_output_zero,
                                                             csv_file=csv_file)
                except Exception as e:
                    print(f"Error encountered with seed {seed}: {e}")
                    n_errors += 1
                finally:
                    print("\n" + "="*50 + "\n")  # Separator between test outputs

            print(f"Number of errors: {n_errors}")
    
    return n_errors

def test_gemm_fp9_sop_fp32_with_random_values(data_type="FP8", acc_data_type="FP32", rows=4, cols=4, inner_dim=32, block_size=32, vector_size=4, seed=None, allow_fp9_special_values=False, set_max_fp9=False, set_min_fp9=False, scale_range=[-127, 128], is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, csv_file=None, use_external_data=False):
    """
    Simulate matrix multiplication (GEMM) using sum_fp9_sop_fp32 for dot products on FP9 vectors.

    Args:
        vector_size (int, optional): The size of the vectors for dot products. Defaults to 4.
        block_size (int, optional): Size of blocks to assign unique scales. Defaults to 32.
        seed (int, optional): A seed for reproducible random number generation. Defaults to None.
    """
    # Ensure inner_dim is divisible by block_size
    assert inner_dim % block_size == 0, "inner_dim must be divisible by block_size"

    if data_type == "FP4":
        constants = get_constants(vector_size/2) # HW has bits for half the vector size
    elif data_type == "FP6" or data_type == "FP6ALT":
        constants = get_constants((vector_size * 6) // 8) # HW has vector size based on FP8
        assert (block_size % 32 == 0), "block_size must be a multiple of 32 for FP6/FP6ALT"
    else:
        constants = get_constants(vector_size)

    # Set the seed once
    if seed is not None:
        random.seed(seed)
    if use_external_data == True:
        ms_data = load_config(format=data_type)
        print(f"trying external")
        a_matrix = [[FP9(data_type=data_type).float_to_mx(value = ms_data["A"][row*inner_dim + in_dim], data_type=data_type) for in_dim in range(inner_dim)] for row in range(rows)]
        b_matrix = [[FP9(data_type=data_type).float_to_mx(value = ms_data["B"][col * inner_dim + in_dim], data_type=data_type) for col in range(cols)] for in_dim in range(inner_dim)]
        # We scale A and B matrices by 2^6 to make integer so multiply scales with 2^-6
        if data_type == "INT8":
            print(f"scaling int8")
            scale_matrix_a = [[Scale.use_external_value(value=ms_data["Sa"][row * (inner_dim//block_size) + in_dim] - 6)
                        for in_dim in range(inner_dim // block_size)] 
                        for row in range(rows)]
            scale_matrix_b = [[Scale.use_external_value(value = ms_data["Sb"][col*(inner_dim//block_size)+in_dim] - 6) 
                        for in_dim in range(inner_dim // block_size)]
                        for col in range(cols)]
        else:
            scale_matrix_a = [[Scale.use_external_value(value=ms_data["Sa"][row * (inner_dim//block_size) + in_dim])
                        for in_dim in range(inner_dim // block_size)] 
                        for row in range(rows)]
            scale_matrix_b = [[Scale.use_external_value(value = ms_data["Sb"][col*(inner_dim//block_size)+in_dim]) 
                        for in_dim in range(inner_dim // block_size)]
                        for col in range(cols)]
        scale_matrix = [] 
        scale_matrix = [[[[scale_matrix_a[i][k], scale_matrix_b[j][k]]
                        for j in range(cols)]
                        for k in range(inner_dim // block_size)]
                        for i in range(rows)]
        # Check the conversions
        b_transposed = [[b_matrix[k][j] for k in range(len(b_matrix))] for j in range(len(b_matrix[0]))]
        compare_ms_mx(ms_data, a_matrix, b_matrix, scale_matrix_a, scale_matrix_b, is_int8=(data_type=="INT8"))
    else:
        # Generate random FP9 matrices
        a_matrix = [[FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for _ in range(inner_dim)] for _ in range(rows)]
        b_matrix = [[FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for _ in range(cols)] for _ in range(inner_dim)]

        # Generate random scale matrix with two scales for a and b per element
        scale_matrix_a = [[Scale.generate_random(range=scale_range) 
                    for _ in range(inner_dim // block_size)] 
                    for _ in range(rows)]
        scale_matrix_b = [[Scale.generate_random(range=scale_range)
                    for _ in range(inner_dim // block_size)]
                    for _ in range(cols)]
        scale_matrix = [[[[scale_matrix_a[i][k], scale_matrix_b[j][k]]
                        for j in range(cols)]
                        for k in range(inner_dim // block_size)]
                        for i in range(rows)]

    # Initialize FP32 accumulators
    accumulators = [[FPAccumulator(0, acc_data_type) for _ in range(cols)] for _ in range(rows)]

    if (data_type == "FP6" or data_type == "FP6ALT"):
        increments = itertools.cycle([10, 11, 11])
    else:
        increments = itertools.cycle([vector_size])

    # Simulate matrix multiplication
    for i in range(rows):
        for j in range(cols):
            k_start = 0
            while k_start < inner_dim:
                inc = next(increments)
                print_conditional(f"Vector={i*cols*inner_dim//vector_size + j*inner_dim//vector_size + k_start//vector_size}, i={i}, j={j}, k={k_start}")
                k_block = k_start // block_size
                scale_a = scale_matrix[i][k_block][j][0]
                scale_b = scale_matrix[i][k_block][j][1]

                # Extract vector_size chunks for dot product
                a_vector = a_matrix[i][k_start:k_start + inc]
                b_vector = [b_matrix[k][j] for k in range(k_start, k_start + inc)]

                # Update k_start for the next iteration
                k_start += inc

                # Compute dot product and update the accumulator
                accumulators[i][j] = sum_fp9_sop_fp32(
                    constants,
                    a_vector,              # Vector of elements from A's row
                    b_vector,              # Vector of elements from B's column
                    accumulators[i][j],    # FP32 accumulator
                    scale_a,               # Scale for a vector
                    scale_b,               # Scale for b vector
                    data_type=data_type,
                    acc_data_type=acc_data_type,
                    csv_file=csv_file
                )

    # Prepare data for C application into an array of binary strings
    b_transposed = [[b_matrix[k][j] for k in range(len(b_matrix))] for j in range(len(b_matrix[0]))]

    a_flat = [fp9.binary for row in a_matrix for fp9 in row]
    b_flat = [fp9.binary for row in b_transposed for fp9 in row]
    scales_flat = [scale[idx].binary for row in scale_matrix for col in row for scale in col for idx in range(2)]
    scale_a_flat = [s.binary for row in scale_matrix_a for s in row]
    scale_b_flat = [s.binary for row in scale_matrix_b for s in row]
    scale_b_flat_t = [scale_matrix_b[i][j].binary for j in range(len(scale_matrix_b[0])) for i in range(len(scale_matrix_b))]
    if acc_data_type == "FP32":
        accumulators_hex = [acc.hex for row in accumulators for acc in row]
        accumulators_value = [acc.value for row in accumulators for acc in row]
    elif acc_data_type == "BF16":
        accumulators_hex = [acc.hex for row in accumulators for acc in row]
        accumulators_value = [acc.value for row in accumulators for acc in row]

    # Verify correctness
    ms_mx_gemm_output = ms_data["Output"] if use_external_data else None

    verify_matmul(
        a_matrix=a_matrix,
        b_matrix=b_matrix,
        scale_matrix_a=scale_matrix_a,
        scale_matrix_b=scale_matrix_b,
        accumulators=accumulators,
        vector_size=vector_size,
        block_size=block_size,
        rows=rows,
        cols=cols,
        inner_dim=inner_dim, 
        use_external_data = use_external_data,
        ms_mx_gemm_output=ms_mx_gemm_output,
        res_mantissa_bits=FPFormats[acc_data_type].mantissa_bits,
        increments=increments
    )

    return a_flat, b_flat, scales_flat, accumulators_hex, accumulators_value, scale_a_flat, scale_b_flat, scale_b_flat_t

import numpy as np

def compare_with_inf_nan(expected, computed, rtol=1e-5):
    """
    Compare two matrices element-wise using relative error, handling NaN and inf values.
    
    Args:
        expected (np.ndarray): Ground truth matrix.
        computed (np.ndarray): Computed matrix.
        rtol (float): Relative tolerance for comparison.
    
    Returns:
        bool: True if matrices are element-wise equal within relative tolerance.
    """
    # Check shapes
    if expected.shape != computed.shape:
        print("Shape mismatch")
        return False
    
    OutputCorrect = True

    # Element-wise comparison
    for i in range(expected.shape[0]):
        for j in range(expected.shape[1]):
            e, c = expected[i, j], computed[i, j]
            
            # Handle NaN
            if np.isnan(e) and np.isnan(c):
                continue  # Both are NaN, considered equal
            
            # Handle inf
            elif np.isinf(e) and np.isinf(c) and np.sign(e) == np.sign(c):
                continue  # Both are inf with the same sign
            
            # Handle relative error
            elif not np.isclose(c, e, rtol=rtol):
                rel_error = abs(c - e) / (abs(e) + 1e-12)  # Avoid division by zero
                print(f"Mismatch at ({i}, {j}): expected={e}, computed={c}, relative error={rel_error}")
                OutputCorrect = False

    return OutputCorrect

def verify_matmul(a_matrix, b_matrix, scale_matrix_a, scale_matrix_b, accumulators, vector_size, block_size, rows, cols, inner_dim, use_external_data, ms_mx_gemm_output, res_mantissa_bits, increments):
    # Convert a_matrix and b_matrix to NumPy arrays
    a_np = np.array([[fp9.value for fp9 in row] for row in a_matrix], dtype=np.float32)
    b_np = np.array([[fp9.value for fp9 in row] for row in b_matrix], dtype=np.float32)
    
    # Perform matrix multiplication using NumPy
    expected_result = np.zeros((rows, cols), dtype=np.float32)
    if use_external_data:
        expected_mx_result = np.zeros((rows, cols), dtype=np.float32)

    for i in range(rows):
        for j in range(cols):
            k_start = 0
            while k_start < inner_dim:
                inc = next(increments)
                k_block = k_start // block_size
                scale = scale_matrix_a[i][k_block].value + scale_matrix_b[j][k_block].value
                
                # Extract vector_size chunks for dot product
                a_vector = a_np[i, k_start:k_start + inc]
                b_vector = b_np[k_start:k_start + inc, j]
                
                # Update k_start for the next iteration
                k_start += inc

                # Compute scaled dot product using mpmath
                actual_result = compute_mp_result([float(x) for x in a_vector], [float(x) for x in b_vector], scale, float(expected_result[i, j]))
                expected_result[i, j] = high_precision_to_fp32(actual_result, res_mantissa_bits)
                if use_external_data:
                    expected_mx_result[i,j] = ms_mx_gemm_output[i * 192 + j] # Hardcoded 192 from max cols in sample data [deit-tiny]

    # Compare with accumulators
    computed_result = np.array([[acc.value for acc in row] for row in accumulators], dtype=np.float32)
    if compare_with_inf_nan(expected_result, computed_result, rtol=1e-5):
        print("[highprecision-verify] Matrix multiplication is correct!")
    else:
        print("[highprecision-verify] Matrix multiplication is incorrect.")
        raise ValueError("[highprecision-verify] Matrix multiplication is incorrect.")
    if use_external_data:
        if res_mantissa_bits == 7:
            rtol = 3
        else:
            rtol = 1e-2
        print(f"verifying external")
        if compare_with_inf_nan(expected_mx_result, computed_result, rtol=rtol):
            print("[external-data-verify] Matrix multiplication is correct!")
        else:
            print("[external-data-verify] Matrix multiplication is incorrect.")
            raise ValueError("[external-data-verify] Matrix multiplication is incorrect.")


def run_gemm_with_seeds(seeds, data_type="FP8", acc_data_type="FP32", rows=4, cols=4, inner_dim=32, block_size=32,
                        vector_size=4, fp9_scale_range=[-127, 128], allow_fp9_special_values=False, set_max_fp9=False, set_min_fp9=False, is_fp32_subnormal= False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, csv_file=None, output_file="test_output.txt", use_external_data=False):
    """
    Run the sum_fp9_sop_fp32_with_random_values test with a set of seeds and randomized scales.

    Args:
        seeds (list): A list of seeds to use for random number generation.
        vector_size (int, optional): The size of the vectors to generate. Defaults to 4.
        output_file (str, optional): The file to write the output to. Defaults to 'test_output3.txt'.
    """

    n_errors= 0

    with open(output_file, 'w') as f:
        # Write the function name at the top
        f.write("Function: run_gemm_with_seeds with {} seeds\n\n".format(len(seeds)))
        
        # Redirect stdout to the file
        with contextlib.redirect_stdout(f):
            for idx, seed in enumerate(seeds, start=1):  # start=1 to make the index start from 1
                random.seed(seed)  # Set the seed for reproducibility
                print(f"Vector {idx}: Running test with seed: {seed}")

                try:
                    test_gemm_fp9_sop_fp32_with_random_values(data_type=data_type, acc_data_type=acc_data_type,
                                                             rows=rows, cols=cols, inner_dim=inner_dim, block_size=block_size,
                                                             vector_size=vector_size, seed=seed, 
                                                             allow_fp9_special_values=allow_fp9_special_values,
                                                             set_max_fp9=set_max_fp9, set_min_fp9=set_min_fp9,
                                                             scale_range=fp9_scale_range,
                                                             is_fp32_subnormal=is_fp32_subnormal, 
                                                             force_fp32=force_fp32, 
                                                             exponent_range_fp32=exponent_range_fp32, 
                                                             force_output_zero=force_output_zero,
                                                             csv_file=csv_file,
                                                             use_external_data=use_external_data)
                except Exception as e:
                    print(f"Error encountered with seed {seed}: {e}")
                    n_errors += 1
                finally:
                    print("\n" + "="*50 + "\n")  # Separator between test outputs

            # Merge inputs to 64-bit for the wrapper/FPU
            if fp_functions.EXPORT:
                print("Processing CSV for merged inputs...")
                process_csv_for_merged_inputs(csv_file=csv_file, data_type=data_type, vector_size=vector_size)

            print(f"Number of errors: {n_errors}")
    
    return n_errors
