// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module fp32_to_mxfp4_quantizer (
  // Global Signals
  input  logic              clk_i,
  input  logic              rst_ni,
  // Scale
  input  logic [7:0]        scale_i,
  // FP32 Value
  input  logic [31:0]       fp32_i,
  // MXFP4 Value
  output logic [3:0]        mxfp4_o
);

  // Biases
  localparam int FP32_BIAS  = 127;
  localparam int E2M1_BIAS  = 1;
  localparam int SCALE_BIAS = 127;

  localparam int EXPONENT_MAX = 2;
  localparam int EXPONENT_MIN = 0;

  localparam int unsigned EXP_BITS    = 2;
  localparam int unsigned MANT_BITS   = 1;

  localparam logic [EXP_BITS+MANT_BITS-1:0] E2M1_MAX = 3'b11_1;

  // FP32 Bit Fields
  logic         fp32_sign;      // 1-bit
  logic [7:0]   fp32_exponent;  // 8-bit
  logic [22:0]  fp32_mantissa;  // 23-bit

  // MXFP4 Bit Fields
  logic                   mxfp4_sign;     // 1-bit
  logic [EXP_BITS-1:0]    mxfp4_exponent; // 2-bit
  logic [MANT_BITS-1:0]   mxfp4_mantissa; // 1-bit

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
  logic                 guard, sticky, roundbit;

  always_comb begin
    // Default Assignment
    mxfp4_exponent    = '0;
    mxfp4_mantissa    = '0;
    unbiased_exponent = '0;
    scaled_exponent   = '0;
    final_exponent    = '0;
    shift_raw         = '0;
    shift_amt         = '0;
    full_mantissa     = '0;
    shifted_mantissa  = '0;
    rounded_mantissa  = '0;
    guard             = 1'b0;
    sticky            = 1'b0;
    roundbit          = 1'b0;
    // Value is Inf: Saturate (FP4 has no Inf/NaN encodings)
    if (is_inf) begin
      {mxfp4_exponent, mxfp4_mantissa} = E2M1_MAX;
    // Value is neither Zero nor NaN
    end else if (!is_zero && !is_nan) begin
      unbiased_exponent = is_input_subnorm ? (1 - FP32_BIAS) : (fp32_exponent - FP32_BIAS);
      full_mantissa     = is_input_subnorm ? {1'b0, fp32_mantissa} : {1'b1, fp32_mantissa};
      scaled_exponent   = unbiased_exponent - ($signed({2'b00, scale_i}) - SCALE_BIAS);
      // Overflow
      if (scaled_exponent > EXPONENT_MAX) begin
        {mxfp4_exponent, mxfp4_mantissa} = E2M1_MAX;
      // Normal (scaled_exponent >= EXPONENT_MIN) or Subnormal/Underflow (below)
      end else begin
        shift_raw         = EXPONENT_MIN - scaled_exponent;
        shift_amt         = (shift_raw <= 0) ? 5'd0 : (shift_raw > 5'd24) ? 5'd24 : shift_raw[4:0];
        shifted_mantissa  = full_mantissa >> shift_amt;
        // Round to Nearest Even
        rounded_mantissa  = shifted_mantissa[23-:(MANT_BITS+1)];
        guard             = shifted_mantissa[23-MANT_BITS-1];
        sticky            = |(shifted_mantissa[23-MANT_BITS-2:0]);
        roundbit          = guard & (sticky | rounded_mantissa[0]);
        rounded_mantissa  = rounded_mantissa + roundbit;
        if (shift_amt == 5'd0) begin
          final_exponent  = scaled_exponent + E2M1_BIAS + rounded_mantissa[MANT_BITS+1];
          if (final_exponent > (EXPONENT_MAX + E2M1_BIAS)) begin
            {mxfp4_exponent, mxfp4_mantissa} = E2M1_MAX;
          end else begin
            mxfp4_exponent  = final_exponent[EXP_BITS-1:0];
            mxfp4_mantissa  = rounded_mantissa[MANT_BITS-1:0];
          end
        end else if (rounded_mantissa[MANT_BITS]) begin
          mxfp4_exponent  = EXP_BITS'(1);
          mxfp4_mantissa  = '0;
        end else begin
          mxfp4_exponent  = '0;
          mxfp4_mantissa  = rounded_mantissa[MANT_BITS-1:0];
        end
      end
    end
  end

  assign mxfp4_sign = fp32_sign;
  assign mxfp4_o    = {mxfp4_sign, mxfp4_exponent, mxfp4_mantissa};

endmodule : fp32_to_mxfp4_quantizer
