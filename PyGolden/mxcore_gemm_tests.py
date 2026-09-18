import random
import traceback
from math import ceil

from .fp_functions import *
from .fp9 import *
from .fp_accumulator import FPAccumulator
from .scale import *
from .norm_round import *
from .mxcore_gemm_functions import *
from .random_tests import *
from .globals import get_constants

def test_mxcore_gemm(data_type="FP8", acc_data_type="FP32", hardware_vector_size=8, vector_size=8, mdim=256, kdim=1024, ndim=256, num_compute_units=8, num_out_buffers=4, BLOCK_SIZE=32, result_mx_block_size=None, seed=None, memory_data_width=32, mem_file=None, res_file=None, res_mx_file=None, header_path=None, allow_fp9_special_values=False, set_max_fp9=False, set_min_fp9=False, scale_range=[-127, 128], is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, use_external_data=False, dataflow_file=None, mem_debug_file=None, preload=False, block_poison_enable=False):
    """
    Test the mxcore_gemm function with two MX FP9 matrices

    Args:
        vector_size (int, optional): Vector size (VS) per MXDOTP unit.
        mdim (int, optional): M; rows of matrix A / rows of result. Defaults to 256.
        kdim (int, optional): K; inner dimension (cols of A, rows of B). Defaults to 1024.
        ndim (int, optional): N; cols of matrix B / cols of result. Defaults to 256.
        seed (int, optional): A seed for reproducible random number generation. Defaults to None.
        preload (bool, optional): Preload accumulator with random FP32 values. Defaults to False.
    """

    # Set the seed once
    if seed is not None:
        random.seed(seed)
    num_scale_blocks_k = ceil(kdim / BLOCK_SIZE)
    if use_external_data == True:
        ms_data = load_config()
        print(f"Trying External Data")
        random_fp9_matrix_a = [[FP9(data_type=data_type).float_to_mx(value = ms_data["A"][row*kdim + in_dim], data_type=data_type) for in_dim in range(kdim)] for row in range(mdim)]
        random_fp9_matrix_b = [[FP9(data_type=data_type).float_to_mx(value = ms_data["B"][col*kdim + in_dim], data_type=data_type) for col in range(ndim)] for in_dim in range(kdim)]
        scale_matrix_a = [[Scale.use_external_value(value=ms_data["Sa"][row*num_scale_blocks_k + in_dim]) for in_dim in range(num_scale_blocks_k)] for row in range(mdim)]
        scale_matrix_b = [[Scale.use_external_value(value = ms_data["Sb"][col*num_scale_blocks_k + in_dim]) for col in range(ndim)] for in_dim in range(num_scale_blocks_k)]
    else:
        # Generate random FP9 matrices
        random_fp9_matrix_a = [[FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for col in range(kdim)] for row in range(mdim)]
        random_fp9_matrix_b = [[FP9.generate_random(data_type=data_type, allow_special_values=allow_fp9_special_values, set_max=set_max_fp9, set_min=set_min_fp9) for col in range(ndim)] for row in range(kdim)]

        num_scale_blocks_k = ceil(kdim / BLOCK_SIZE)
        scale_matrix_a = [[Scale.generate_random(range=scale_range) for col in range(num_scale_blocks_k)] for row in range(mdim)]
        scale_matrix_b = [[Scale.generate_random(range=scale_range) for col in range(ndim)] for row in range(num_scale_blocks_k)]

    preload_matrix = None
    if preload:
        preload_matrix = [[FPAccumulator.generate_random(data_type=acc_data_type, forced=True, exponent_range=[-10, 10]) for _ in range(ndim)] for _ in range(mdim)]
        print(f"Preload: {mdim} x {ndim} FP32 accumulator matrix generated")

    # Test the mxcore_gemm function with the generated vectors
    mxcore_gemm(random_fp9_matrix_a, random_fp9_matrix_b, scale_matrix_a, scale_matrix_b, hardware_vector_size=hardware_vector_size, vector_size=vector_size, num_compute_units=num_compute_units, num_out_buffers=num_out_buffers, BLOCK_SIZE=BLOCK_SIZE, result_mx_block_size=result_mx_block_size, data_type=data_type, acc_data_type=acc_data_type, memory_data_width=memory_data_width, mem_file=mem_file, res_file=res_file, res_mx_file=res_mx_file, header_path=header_path, allow_fp9_special_values=allow_fp9_special_values, set_max_fp9=set_max_fp9, set_min_fp9=set_min_fp9, scale_range=scale_range, is_fp32_subnormal=is_fp32_subnormal, force_fp32=force_fp32, exponent_range_fp32=exponent_range_fp32, force_output_zero=force_output_zero, use_external_data=use_external_data, dataflow_file=dataflow_file, mem_debug_file=mem_debug_file, preload_matrix=preload_matrix, block_poison_enable=block_poison_enable)

def run_mxcore_gemm(data_type="FP8", acc_data_type="FP32", seed=None, hardware_vector_size=8, vector_size=8, mdim=256, kdim=1024, ndim=256, num_compute_units=8, num_out_buffers=4, BLOCK_SIZE=32, result_mx_block_size=None, memory_data_width=32, mem_file=None, res_file=None, res_mx_file=None, header_path=None, allow_fp9_special_values=False, set_max_fp9=False, set_min_fp9=False, scale_range=[-127, 128], is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=False, use_external_data=False, dataflow_file=None, mem_debug_file=None, preload=False, block_poison_enable=False):
    """
    Run the test_mxcore_gemm function

    Args:
        vector_size (int, optional): The size of vectors handled by each MXDOTP unit in MXCore. Defaults to 8.
        mdim (int, optional): M; rows of matrix A / rows of result. Defaults to 256.
        kdim (int, optional): K; inner dimension (cols of A, rows of B). Defaults to 1024.
        ndim (int, optional): N; cols of matrix B / cols of result. Defaults to 256.
        preload (bool, optional): Preload accumulator with random FP32 values. Defaults to False.
    """

    n_errors= 0

    try:
        test_mxcore_gemm(data_type=data_type,
                         acc_data_type=acc_data_type,
                         hardware_vector_size=hardware_vector_size,
                         vector_size=vector_size,
                         mdim=mdim,
                         kdim=kdim,
                         ndim=ndim,
                         num_compute_units=num_compute_units,
                         num_out_buffers=num_out_buffers,
                         BLOCK_SIZE=BLOCK_SIZE,
                         result_mx_block_size=result_mx_block_size,
                         seed=seed,
                         memory_data_width=memory_data_width,
                         mem_file=mem_file,
                         res_file=res_file,
                         res_mx_file=res_mx_file,
                         header_path=header_path,
                         allow_fp9_special_values=allow_fp9_special_values,
                         set_max_fp9=set_max_fp9,
                         set_min_fp9=set_min_fp9,
                         scale_range=scale_range,
                         is_fp32_subnormal=is_fp32_subnormal,
                         force_fp32=force_fp32,
                         exponent_range_fp32=exponent_range_fp32,
                         force_output_zero=force_output_zero,
                         use_external_data=use_external_data,
                         dataflow_file=dataflow_file,
                         mem_debug_file=mem_debug_file,
                         preload=preload,
                         block_poison_enable=block_poison_enable)
    except Exception as e:
        print("Error Encountered!")
        print(f"Exception: {e}")
        traceback.print_exc()
        n_errors += 1

    print(f"Number of Errors: {n_errors}")

    return n_errors
