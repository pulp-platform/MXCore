# Constants for the golden model

import math

def get_constants(vector_size):
    vector_bit = math.ceil(math.log2(vector_size))
    # I tried ANCHOR=32 but negative shift count problem occurred
    anchor = 34 # min_xy = 32b
    fp_accumulator_point = 23
    # min xy = 32b, max xy = 32b, sign = 1b, vector -> clog2(vector_size) b
    sop_fixed_width = 32 + anchor + 1 + vector_bit
    # |s|-Acc:24b-|R|-unsigned SoP:64+log2k-|
    fixed_accumulator_width = 1 + (fp_accumulator_point + 1) + 1 + (sop_fixed_width - 1)
    max_shift = fixed_accumulator_width - (fp_accumulator_point + 1) - 1 # Maximum allowable shift, -1 for the sign bit

    product_width = 9 # m=3, p=4, 2p+1=9 (+1 for sign bit)
    sop_width = product_width + vector_bit
    int_product_width = 2 * 8
    int_sop_width = int_product_width + vector_bit
    sop_shift = anchor - 2 * 3 # 2p=6

    return {
        "RTL_VECTOR_SIZE": vector_size,
        "VECTOR_BIT": vector_bit,
        "ANCHOR": anchor,
        "FP_ACCUMULATOR_POINT": fp_accumulator_point,
        "SOP_FIXED_WIDTH": sop_fixed_width,
        "FIXED_ACCUMULATOR_WIDTH": fixed_accumulator_width,
        "MAX_SHIFT": max_shift,
        "PRODUCT_WIDTH": product_width,
        "SOP_WIDTH": sop_width,
        "INT_SOP_WIDTH": int_sop_width,
        "SOP_SHIFT": sop_shift,
    }