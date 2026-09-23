import argparse
import os
from pathlib import Path

from . import utils
from . import fp_functions
from .mxcore_utils import quantize_result_to_bf16

from .mxcore_gemm_tests import *
from . import mxcore_gemm_functions

default_path = "./testvectors/"

def gemm_mxcore_vector_gen(folder_path=default_path, data_type="FP8", acc_data_type="FP32", seed=None, fp9_scale_range=[-127, 128], set_max_fp9=False, set_min_fp9=False, is_fp32_subnormal=False, force_fp32=False, exponent_range_fp32=[-127, 128], force_output_zero=None, mdim=128, kdim=128, ndim=128, mxdotp_vector_size=8, num_mx_units=8, num_out_buffers=4, memory_data_width=32, block_size=32, use_external_data=False, preload=False, block_poison_enable=False):

    result_mx_block_size = block_size
    effective_vector_size = mxdotp_vector_size
    effective_block_size = block_size
    if block_size < mxdotp_vector_size:
        raise ValueError("MX Block_Size must be greater than or equal to Vector Size (VS).")
    if data_type == "FP4" and (mxdotp_vector_size % 2 != 0):
        raise ValueError("FP4 mode requires an even MXDOTP vector size (VS). Note: effective vector= 2*VS due to 4-bit packing.")

    if data_type == "FP4":
        # FP4 consumes two 4-bit values per logical lane, so the effective operand
        # vector and input block size are doubled relative to the hardware VS.
        effective_vector_size = 2 * mxdotp_vector_size
        effective_block_size = 2 * block_size

    folder_path = os.path.join(folder_path, "preload" if preload else "nopreload")

    _tag = f"{data_type}_VS{mxdotp_vector_size}_MX{num_mx_units}_O{num_out_buffers}_M{mdim}_K{kdim}_N{ndim}_BS{block_size}"

    memory_file    = os.path.join(folder_path, f"memory/data_memory_{_tag}.txt")
    result_file    = os.path.join(folder_path, f"result/result_{_tag}.txt")
    result_mx_file = os.path.join(folder_path, f"result_mx/result_{_tag}.txt")
    result_bf16_file = os.path.join(folder_path, f"result_bf16/result_{_tag}.txt")
    header_file    = os.path.join(folder_path, f"data_header/data_{_tag}.h")
    dataflow_file  = os.path.join(folder_path, f"debug/dataflow_debug_{_tag}.txt")
    mem_debug_file = os.path.join(folder_path, f"debug/memory_debug_{_tag}.txt")

    for fpath in [memory_file, result_file, result_mx_file, result_bf16_file, header_file, dataflow_file]:
        os.makedirs(os.path.dirname(fpath), exist_ok=True)

    if mxcore_gemm_functions.MEMORY_EXPORT:
        for f in [memory_file, result_file, result_mx_file, result_bf16_file, header_file, dataflow_file, mem_debug_file]:
            try:
                os.remove(f)
            except FileNotFoundError:
                pass

    print("Running Test for GEMM - MXCore...")
    n_errors = run_mxcore_gemm(
        data_type=data_type,
        seed=seed,
        acc_data_type=acc_data_type,
        hardware_vector_size=mxdotp_vector_size,
        vector_size=effective_vector_size,
        result_mx_block_size=result_mx_block_size,
        mdim=mdim,
        kdim=kdim,
        ndim=ndim,
        num_compute_units=num_mx_units,
        num_out_buffers=num_out_buffers,
        BLOCK_SIZE=effective_block_size,
        memory_data_width=memory_data_width,
        mem_file=memory_file,
        res_file=result_file,
        res_mx_file=result_mx_file,
        header_path=header_file,
        allow_fp9_special_values=False,
        set_max_fp9=set_max_fp9,
        set_min_fp9=set_min_fp9,
        scale_range=fp9_scale_range,
        is_fp32_subnormal=is_fp32_subnormal,
        force_fp32=force_fp32,
        exponent_range_fp32=exponent_range_fp32,
        force_output_zero=force_output_zero,
        use_external_data=use_external_data,
        dataflow_file=dataflow_file if mxcore_gemm_functions.MEMORY_EXPORT else None,
        mem_debug_file=mem_debug_file if mxcore_gemm_functions.MEMORY_EXPORT else None,
        preload=preload,
        block_poison_enable=block_poison_enable,
    )

    if n_errors == 0 and mxcore_gemm_functions.MEMORY_EXPORT:
        quantize_result_to_bf16(result_file, result_bf16_file, memory_data_width=memory_data_width)

    if n_errors == 0:
        print("✅", end=" ")
    else:
        print("❌", end=" ")
    print(f"Tests completed with {n_errors} errors.")
    if mxcore_gemm_functions.MEMORY_EXPORT:
        print(f"Data Memory:            {memory_file}")
        print(f"MXCore FP32 Results:    {result_file}")
        print(f"MXCore MX Results:      {result_mx_file}")
        print(f"MXCore BF16 Results:    {result_bf16_file}")
        print(f"C Data Header File:     {header_file}")
        print(f"Dataflow Debug:         {dataflow_file}")
        print(f"Memory Debug:           {mem_debug_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate MXCore GEMM test vectors from the golden model.")

    parser.add_argument(
        "--testvector_path",
        type=Path,
        default=Path(default_path),
        help=f"Path to the test vector directory (default: {default_path})"
    )
    parser.add_argument(
        "--main_seed",
        type=int,
        default=42,
        help="Seed for random number generation (default: 42)"
    )
    parser.add_argument(
        "--use_external_data",
        action="store_true",
        help="Use external data instead of generating random data (default: disabled)"
    )
    parser.add_argument(
        "--data_type",
        type=str,
        choices=["FP8", "FP8ALT", "FP4", "INT8"],
        default="FP8",
        help="Data type to use: FP8, FP8ALT, FP4, INT8 (default: FP8)"
    )
    parser.add_argument(
        "--acc_data_type",
        type=str,
        choices=["FP32", "BF16"],
        default="FP32",
        help="Accumulation data type to use: FP32, BF16 (default: FP32)"
    )
    parser.add_argument(
        "--scale",
        type=int,
        nargs=2,
        default=[-127, 128],
        help="FP9 scale range as [min, max] (default: [-127, 128])"
    )
    parser.add_argument(
        "--set_max_fp9",
        action="store_true",
        help="Set values to the maximum representable FP9 (default: disabled)"
    )
    parser.add_argument(
        "--set_min_fp9",
        action="store_true",
        help="Set values to the minimum representable FP9 (default: disabled)"
    )
    parser.add_argument(
        "--fp32_subnormal",
        action="store_true",
        help="Enable generation of subnormal FP32 values (default: disabled)"
    )
    parser.add_argument(
        "--force_fp32",
        action="store_true",
        help="Force generation of FP32 values (default: disabled)"
    )
    parser.add_argument(
        "--exponent_range_fp32",
        type=int,
        nargs=2,
        default=[-127, 128],
        help="Exponent range for FP32 when --force_fp32 is enabled (default: [-127, 128])"
    )
    parser.add_argument(
        "--force_output_zero",
        action="store_true",
        help="Force output vectors to zero (default: disabled)"
    )
    parser.add_argument(
        "--print",
        action="store_true",
        help="Enable printing of vectors to stdout (default: disabled)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable printing of debugging features to stdout (default: disabled)"
    )
    parser.add_argument(
        "--preload",
        action="store_true",
        help="Preload accumulator with random FP32 values (default: disabled)"
    )
    parser.add_argument(
        "--memory_export",
        action="store_true",
        help="Export data to a memory file for MXCore HWPE (default: disabled)"
    )

    gemm_group = parser.add_argument_group("GEMM MXCore Options")
    gemm_group.add_argument(
        "--gemm_mdim",
        type=int,
        default=128,
        help="Matrix A Rows (M) (default: 128)"
    )
    gemm_group.add_argument(
        "--gemm_kdim",
        type=int,
        default=128,
        help="GEMM Inner Dimension (K) (default: 128)"
    )
    gemm_group.add_argument(
        "--gemm_ndim",
        type=int,
        default=128,
        help="Matrix B Columns (N) (default: 128)"
    )
    gemm_group.add_argument(
        "--mxdotp_vector_size",
        type=int,
        default=32,
        help="Vector Size per MXDOTP Unit (VS) (default: 32)"
    )
    gemm_group.add_argument(
        "--num_mx_units",
        type=int,
        default=32,
        help="Number of MX Units (NPE) (default: 32)"
    )
    gemm_group.add_argument(
        "--num_out_buffers",
        type=int,
        default=64,
        help="Number of Output Buffer rows (Reuse) (default: 64)"
    )
    gemm_group.add_argument(
        "--memory_data_width",
        type=int,
        default=32,
        help="Width of Data Memory in bits (default: 32)"
    )
    gemm_group.add_argument(
        "--mx_block_size",
        type=int,
        choices=[16, 32],
        default=32,
        help="MX Block Size for MXCore GEMM (16 or 32; default: 32). Must be >= VS."
    )

    args = parser.parse_args()

    # Set global flags
    utils.PRINT_ENABLED = args.print
    utils.DEBUG = args.debug
    mxcore_gemm_functions.MEMORY_EXPORT = args.memory_export

    gemm_mxcore_vector_gen(
        folder_path=args.testvector_path,
        data_type=args.data_type,
        seed=args.main_seed,
        acc_data_type=args.acc_data_type,
        fp9_scale_range=args.scale,
        set_max_fp9=args.set_max_fp9,
        set_min_fp9=args.set_min_fp9,
        is_fp32_subnormal=args.fp32_subnormal,
        force_fp32=args.force_fp32,
        exponent_range_fp32=args.exponent_range_fp32,
        force_output_zero=args.force_output_zero,
        mdim=args.gemm_mdim,
        kdim=args.gemm_kdim,
        ndim=args.gemm_ndim,
        mxdotp_vector_size=args.mxdotp_vector_size,
        num_mx_units=args.num_mx_units,
        num_out_buffers=args.num_out_buffers,
        memory_data_width=args.memory_data_width,
        block_size=args.mx_block_size,
        use_external_data=args.use_external_data,
        preload=args.preload
    )
