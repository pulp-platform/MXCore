import sys
sys.path.append('/usr/scratch2/bismantova/gislamoglu/mx/mxdotp/microsoft/microxcaling_larain10/examples/workloads/deit_tiny')

import os

def load_config(cfg_data="sample0_layer1", format="FP8"):
    # # For power simulations:
    # cfg_path = os.getenv("mxgemm_DATA_CFG")  # Returns None if MY_VAR is not set
    # cfg_file = os.path.splitext(os.path.basename(cfg_path))[0]
    # parts = cfg_file.split("_")
    # cfg_data = "_".join(parts[-2:])

    # parts_0 = parts[0].split("-")
    # format = parts_0[0]

    print(f"cfg_data: {cfg_data}")
    print(f"format: {format}")

    if cfg_data == "sample0_layer1":
        print("Loading sample0_layer1")
        # fp8_e5m2/sample_0_2989 layer 1

        if format == "FP8":
            print("Loading FP8")
            from fp8_e5m2.sample_0_2989.input_1 import input_1
            from fp8_e5m2.sample_0_2989.weight_1 import weight_1
            from fp8_e5m2.sample_0_2989.input_exp_1 import input_exp_1
            from fp8_e5m2.sample_0_2989.weight_exp_1 import weight_exp_1
            from fp8_e5m2.sample_0_2989.gemm_output_1 import gemm_output_1
        if format == "FP8ALT":
            print("Loading FP8ALT")
            from fp8_e4m3.sample_0_2989.input_1 import input_1
            from fp8_e4m3.sample_0_2989.weight_1 import weight_1
            from fp8_e4m3.sample_0_2989.input_exp_1 import input_exp_1
            from fp8_e4m3.sample_0_2989.weight_exp_1 import weight_exp_1
            from fp8_e4m3.sample_0_2989.gemm_output_1 import gemm_output_1
        if format == "FP6":
            print("Loading FP6")
            from fp6_e3m2.sample_0_2989.input_1 import input_1
            from fp6_e3m2.sample_0_2989.weight_1 import weight_1
            from fp6_e3m2.sample_0_2989.input_exp_1 import input_exp_1
            from fp6_e3m2.sample_0_2989.weight_exp_1 import weight_exp_1
            from fp6_e3m2.sample_0_2989.gemm_output_1 import gemm_output_1
        if format == "FP6ALT":
            print("Loading FP6ALT")
            from fp6_e2m3.sample_0_2989.input_1 import input_1
            from fp6_e2m3.sample_0_2989.weight_1 import weight_1
            from fp6_e2m3.sample_0_2989.input_exp_1 import input_exp_1
            from fp6_e2m3.sample_0_2989.weight_exp_1 import weight_exp_1
            from fp6_e2m3.sample_0_2989.gemm_output_1 import gemm_output_1
        if format == "FP4":
            print("Loading FP4")
            from fp4_e2m1.sample_0_2989.input_1 import input_1
            from fp4_e2m1.sample_0_2989.weight_1 import weight_1
            from fp4_e2m1.sample_0_2989.input_exp_1 import input_exp_1
            from fp4_e2m1.sample_0_2989.weight_exp_1 import weight_exp_1
            from fp4_e2m1.sample_0_2989.gemm_output_1 import gemm_output_1
        if format == "INT8":
            print("Loading INT8")
            from int8.sample_0_2989.input_1 import input_1
            from int8.sample_0_2989.weight_1 import weight_1
            from int8.sample_0_2989.input_exp_1 import input_exp_1
            from int8.sample_0_2989.weight_exp_1 import weight_exp_1
            from int8.sample_0_2989.gemm_output_1 import gemm_output_1

        return {
            "A": input_1,
            "B": weight_1,
            "Sa": input_exp_1,
            "Sb": weight_exp_1,
            "Output": gemm_output_1,
        }

    elif cfg_data == "sample2_layer15":
        print("Loading sample2_layer15")
        # fp8_e5m2/sample_2_48136 layer 15

        if format == "FP8":
            print("Loading FP8")
            from fp8_e5m2.sample_2_48136.input_15 import input_15
            from fp8_e5m2.sample_2_48136.weight_15 import weight_15
            from fp8_e5m2.sample_2_48136.input_exp_15 import input_exp_15
            from fp8_e5m2.sample_2_48136.weight_exp_15 import weight_exp_15
            from fp8_e5m2.sample_2_48136.gemm_output_15 import gemm_output_15
        else:
            print("Loading FP8ALT")
            from fp8_e4m3.sample_2_48136.input_15 import input_15
            from fp8_e4m3.sample_2_48136.weight_15 import weight_15
            from fp8_e4m3.sample_2_48136.input_exp_15 import input_exp_15
            from fp8_e4m3.sample_2_48136.weight_exp_15 import weight_exp_15
            from fp8_e4m3.sample_2_48136.gemm_output_15 import gemm_output_15

        return {
            "A": input_15,
            "B": weight_15,
            "Sa": input_exp_15,
            "Sb": weight_exp_15,
            "Output": gemm_output_15,
        }

    elif cfg_data == "sample4_layer30":
        print("Loading sample4_layer30")
        # fp8_e5m2/sample_4_1989 layer 30

        if format == "FP8":
            print("Loading FP8")
            from fp8_e5m2.sample_4_1989.input_30 import input_30
            from fp8_e5m2.sample_4_1989.weight_30 import weight_30
            from fp8_e5m2.sample_4_1989.input_exp_30 import input_exp_30
            from fp8_e5m2.sample_4_1989.weight_exp_30 import weight_exp_30
            from fp8_e5m2.sample_4_1989.gemm_output_30 import gemm_output_30
        else:
            print("Loading FP8ALT")
            from fp8_e4m3.sample_4_1989.input_30 import input_30
            from fp8_e4m3.sample_4_1989.weight_30 import weight_30
            from fp8_e4m3.sample_4_1989.input_exp_30 import input_exp_30
            from fp8_e4m3.sample_4_1989.weight_exp_30 import weight_exp_30
            from fp8_e4m3.sample_4_1989.gemm_output_30 import gemm_output_30

        return {
            "A": input_30,
            "B": weight_30,
            "Sa": input_exp_30,
            "Sb": weight_exp_30,
            "Output": gemm_output_30,
        }

    elif cfg_data == "sample6_layer45":
        print("Loading sample6_layer45")
        # fp8_e5m2/sample_6_40482 layer 45

        if format == "FP8":
            print("Loading FP8")
            from fp8_e5m2.sample_6_40482.input_45 import input_45
            from fp8_e5m2.sample_6_40482.weight_45 import weight_45
            from fp8_e5m2.sample_6_40482.input_exp_45 import input_exp_45
            from fp8_e5m2.sample_6_40482.weight_exp_45 import weight_exp_45
            from fp8_e5m2.sample_6_40482.gemm_output_45 import gemm_output_45
        else:
            print("Loading FP8ALT")
            from fp8_e4m3.sample_6_40482.input_45 import input_45
            from fp8_e4m3.sample_6_40482.weight_45 import weight_45
            from fp8_e4m3.sample_6_40482.input_exp_45 import input_exp_45
            from fp8_e4m3.sample_6_40482.weight_exp_45 import weight_exp_45
            from fp8_e4m3.sample_6_40482.gemm_output_45 import gemm_output_45

        return {
            "A": input_45,
            "B": weight_45,
            "Sa": input_exp_45,
            "Sb": weight_exp_45,
            "Output": gemm_output_45,
        }

    elif cfg_data == "sample8_layer60":
        print("Loading sample8_layer60")
        # fp8_e5m2/sample_8_751 layer 60

        if format == "FP8":
            print("Loading FP8")
            from fp8_e5m2.sample_8_751.input_60 import input_60
            from fp8_e5m2.sample_8_751.weight_60 import weight_60
            from fp8_e5m2.sample_8_751.input_exp_60 import input_exp_60
            from fp8_e5m2.sample_8_751.weight_exp_60 import weight_exp_60
            from fp8_e5m2.sample_8_751.gemm_output_60 import gemm_output_60
        else:
            print("Loading FP8ALT")
            from fp8_e4m3.sample_8_751.input_60 import input_60
            from fp8_e4m3.sample_8_751.weight_60 import weight_60
            from fp8_e4m3.sample_8_751.input_exp_60 import input_exp_60
            from fp8_e4m3.sample_8_751.weight_exp_60 import weight_exp_60
            from fp8_e4m3.sample_8_751.gemm_output_60 import gemm_output_60

        return {
            "A": input_60,
            "B": weight_60,
            "Sa": input_exp_60,
            "Sb": weight_exp_60,
            "Output": gemm_output_60,
        }