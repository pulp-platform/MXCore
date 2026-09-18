// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module fp32_to_mxfp8_quantizer #(
  parameter bit Encoding  = 0,      // 0 - E5M2, 1 - E4M3
  parameter bit Saturate  = 1       // 0 - NONSAT Mode, 1 - SAT Mode
) (
  // Global Signals
  input  logic              clk_i,
  input  logic              rst_ni,
  // Scale
  input  logic [7:0]        scale_i,
  // FP32 Value
  input  logic [31:0]       fp32_i,
  // MXFP8 Value
  output logic [7:0]        mxfp8_o
);

  // Biases
  localparam int FP32_BIAS  = 127;
  localparam int E5M2_BIAS  = 15;
  localparam int E4M3_BIAS  = 7;

  localparam int MXFP8_BIAS   = (Encoding == 0) ? E5M2_BIAS : E4M3_BIAS;
  localparam int EXPONENT_MAX = (Encoding == 0) ? 15 : 8;
  localparam int EXPONENT_MIN = (Encoding == 0) ? -14 : -6;

  localparam int unsigned EXP_BITS    = (Encoding == 0) ? 5 : 4;
  localparam int unsigned MANT_BITS   = (Encoding == 0) ? 2 : 3;

  // FP32 Bit Fields
  logic         fp32_sign;      // 1-bit
  logic [7:0]   fp32_exponent;  // 8-bit
  logic [22:0]  fp32_mantissa;  // 23-bit

  // MXFP8 Bit Fields
  logic                   mxfp8_sign;     // 1-bit
  logic [EXP_BITS-1:0]    mxfp8_exponent; // 5-bit or 4-bit
  logic [MANT_BITS-1:0]   mxfp8_mantissa; // 2-bit or 3-bit

  // Special Value Flags
  logic is_zero;
  logic is_nan;
  logic is_inf;
  logic is_input_subnorm;

  // Extract FP32 Bit Fields
  assign fp32_sign      = fp32_i[31];
  assign fp32_exponent  = fp32_i[30:23];
  assign fp32_mantissa  = fp32_i[22:0];

  // Is a Special Value?
  assign is_zero           = (fp32_exponent == 8'h00) && (fp32_mantissa == '0);
  assign is_nan            = (fp32_exponent == 8'hff) && (fp32_mantissa != '0);
  assign is_inf            = (fp32_exponent == 8'hff) && (fp32_mantissa == '0);
  assign is_input_subnorm  = (fp32_exponent == 8'h00) && (fp32_mantissa != '0);

  // Intermediate Signals
  logic signed  [9:0]   unbiased_exponent, scaled_exponent, final_exponent, shift_raw;
  logic         [4:0]   shift_amt;
  logic         [23:0]  full_mantissa, shifted_mantissa;
  logic         [MANT_BITS+1:0] rounded_mantissa;
  logic                 guard, sticky, roundbit, reserved_hit;

  always_comb begin
    // Default Assignment
    mxfp8_exponent  = '0;
    mxfp8_mantissa  = '0;
    // Value is Zero
    if (is_zero) begin
      mxfp8_exponent  = '0;
      mxfp8_mantissa  = '0;
    // Value is NaN
    end else if (is_nan) begin
      mxfp8_exponent  = (Encoding == 0) ? 5'h1f : 4'hf;
      mxfp8_mantissa  = (Encoding == 0) ? 2'b01 : 3'b111;
    // Value is Inf
    end else if (is_inf) begin
      mxfp8_exponent  = (Encoding == 0) ? ((Saturate == 1) ? 5'h1e : 5'h1f) : 4'hf;
      mxfp8_mantissa  = (Encoding == 0) ? ((Saturate == 1) ? 2'b11 : 2'b00) : ((Saturate == 1) ? 3'b110 : 3'b111);
    end else begin
      unbiased_exponent = is_input_subnorm ? (1 - FP32_BIAS) : (fp32_exponent - FP32_BIAS);
      full_mantissa     = is_input_subnorm ? {1'b0, fp32_mantissa} : {1'b1, fp32_mantissa};
      scaled_exponent   = unbiased_exponent - $signed(scale_i);
      // Overflow
      if (scaled_exponent > EXPONENT_MAX) begin
        mxfp8_exponent  = (Encoding == 0) ? ((Saturate == 1) ? 5'h1e : 5'h1f) : 4'hf;
        mxfp8_mantissa  = (Encoding == 0) ? ((Saturate == 1) ? 2'b11 : 2'b00) : ((Saturate == 1) ? 3'b110 : 3'b111);
      // Normal (scaled_exponent >= EXPONENT_MIN) or Subnormal/Underflow (below)
      end else begin
        shift_raw         = EXPONENT_MIN - scaled_exponent;
        shift_amt          = (shift_raw <= 0) ? 5'd0 : (shift_raw > 5'd24) ? 5'd24 : shift_raw[4:0];
        shifted_mantissa  = full_mantissa >> shift_amt;
        // Round to Nearest Even
        rounded_mantissa  = shifted_mantissa[23-:(MANT_BITS+1)];
        guard             = shifted_mantissa[23-MANT_BITS-1];
        sticky            = |(shifted_mantissa[23-MANT_BITS-2:0]);
        roundbit          = guard & (sticky | rounded_mantissa[0]);
        rounded_mantissa  = rounded_mantissa + roundbit;
        if (shift_amt == 5'd0) begin
          final_exponent    = scaled_exponent + MXFP8_BIAS + rounded_mantissa[MANT_BITS+1];
          reserved_hit = (Encoding == 0) ? (final_exponent >= 10'sd31)
                                          : (final_exponent > 10'sd15 ||
                                             (final_exponent == 10'sd15 && rounded_mantissa[MANT_BITS-1:0] == '1));
          if (reserved_hit) begin
            mxfp8_exponent  = (Encoding == 0) ? ((Saturate == 1) ? 5'h1e : 5'h1f) : 4'hf;
            mxfp8_mantissa  = (Encoding == 0) ? ((Saturate == 1) ? 2'b11 : 2'b00) : ((Saturate == 1) ? 3'b110 : 3'b111);
          end else begin
            mxfp8_exponent  = final_exponent[EXP_BITS-1:0];
            mxfp8_mantissa  = rounded_mantissa[MANT_BITS-1:0];
          end
        end else if (rounded_mantissa[MANT_BITS]) begin
          mxfp8_exponent  = EXP_BITS'(1);
          mxfp8_mantissa  = '0;
        end else begin
          mxfp8_exponent  = '0;
          mxfp8_mantissa  = rounded_mantissa[MANT_BITS-1:0];
        end
      end
    end
  end

  assign mxfp8_sign = fp32_sign;
  assign mxfp8_o    = {mxfp8_sign, mxfp8_exponent, mxfp8_mantissa};

endmodule : fp32_to_mxfp8_quantizer
