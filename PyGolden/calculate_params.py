import argparse
import math

def ceil_log2(x):
    return math.ceil(math.log2(x))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vector_size", type=int, required=True)
    parser.add_argument("--num_compute_units", type=int, required=True)
    parser.add_argument("--num_out_buffers", type=int, required=True)
    parser.add_argument("--sequence_length", type=int, required=True)
    parser.add_argument("--embedding_length", type=int, required=True)
    parser.add_argument("--src_width", type=int, required=True)
    parser.add_argument("--dst_width", type=int, required=True)
    parser.add_argument("--scale_width", type=int, required=True)
    args = parser.parse_args()

    VS = args.vector_size
    MXU = args.num_compute_units
    O = args.num_out_buffers
    S = args.sequence_length
    E = args.embedding_length
    SRCW = args.src_width
    DSTW = args.dst_width
    SCALEW = args.scale_width

    # Data Sizes
    VECTOR_A_DW = VS * SRCW
    VECTOR_B_DW = MXU * VS * SRCW
    SCALE_A_DW = SCALEW
    SCALE_B_DW = MXU * SCALEW
    RESULT_DW = MXU * DSTW
    avg_bw = VECTOR_A_DW + VECTOR_B_DW / O + SCALE_A_DW + SCALE_B_DW / O
    TCDM_DW = 256 * (2 ** ceil_log2(avg_bw / 256))

    # Streamer lengths
    A_LEN = (E * O * SRCW) / TCDM_DW
    B_LEN = (E * MXU * SRCW) / TCDM_DW
    SA_LEN = ((E / VS) * O * SCALEW) / TCDM_DW
    SB_LEN = ((E / VS) * MXU * SCALEW) / TCDM_DW
    RESULT_LEN = (O * MXU * DSTW) / TCDM_DW

    # Reuse metrics
    cycles = E * O / VS
    reuse = cycles - O

    # Memory line ranges
    A_start = 0
    A_end = (E * O * SRCW) // 32 - 1
    B_start = A_end + 1
    B_end = B_start + (E * MXU * SRCW) // 32 - 1
    SA_start = B_end + 1
    SA_end = SA_start + ((E // VS) * O * SCALEW) // 32 - 1
    SB_start = SA_end + 1
    SB_end = SB_start + ((E // VS) * MXU * SCALEW) // 32 - 1
    total_lines = SB_end + 1

    print(f"""
=== Data Sizes ===
MXCORE_VECTOR_A_DW  = {VECTOR_A_DW} bits
MXCORE_VECTORS_B_DW = {VECTOR_B_DW} bits
MXCORE_SCALE_A_DW   = {SCALE_A_DW} bits
MXCORE_SCALE_B_DW   = {SCALE_B_DW} bits
MXCORE_RESULT_DW    = {RESULT_DW} bits
Average Bandwidth   = {avg_bw:.2f} bits
MXCORE_TCDM_DW      = {TCDM_DW} bits

=== Streamer Section ===
A_LEN         = {A_LEN:.2f}
B_LEN         = {B_LEN:.2f}
Scale_A_LEN   = {SA_LEN:.2f}
Scale_B_LEN   = {SB_LEN:.2f}
RESULT_LEN    = {RESULT_LEN:.2f}

=== OReuse Section ===
Cycles Taken (Ideal) = {cycles:.0f}
Output Reuse Count   = {reuse:.0f}

=== Memory Layout (Line indices) ===
A Lines       = {A_start} to {A_end}
B Lines       = {B_start} to {B_end}
Scale A Lines = {SA_start} to {SA_end}
Scale B Lines = {SB_start} to {SB_end}
Total Lines   = {total_lines}

=== Buffer Interfaces ===
* Input to Vector A Buffer  = {TCDM_DW} bits | Output = {VECTOR_A_DW} bits
* Input to Vectors B Buffer = {TCDM_DW} bits | Output = {VECTOR_B_DW} bits
* Input to Scale A Buffer   = {TCDM_DW} bits | Output = {SCALE_A_DW} bits
* Input to Scale B Buffer   = {TCDM_DW} bits | Output = {SCALE_B_DW} bits
* Input to Result Buffer    = {RESULT_DW} bits | Output = {TCDM_DW} bits
""")

if __name__ == "__main__":
    main()
