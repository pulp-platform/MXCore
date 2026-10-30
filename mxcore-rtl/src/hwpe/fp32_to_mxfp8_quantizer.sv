// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module fp32_to_mxfp8_quantizer #(
  parameter bit Saturate  = 1       // 0 - NONSAT Mode, 1 - SAT Mode
) (
  // Global Signals
  input  logic              clk_i,
  input  logic              rst_ni,
  // Control
  input  logic              quantize_mxfp8alt_i,  // 0 - E5M2, 1 - E4M3
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
  localparam int SCALE_BIAS = 127;

  localparam int E5M2_EXPONENT_MAX = 15;
  localparam int E4M3_EXPONENT_MAX = 8;
  localparam int E5M2_EXPONENT_MIN = -14;
  localparam int E4M3_EXPONENT_MIN = -6;

  // Exponent and Mantissa Fields of Special Encodings
  localparam logic [6:0] E5M2_NAN = 7'b11111_01;
  localparam logic [6:0] E4M3_NAN = 7'b1111_111;
  localparam logic [6:0] E5M2_OVF = (Saturate == 1) ? 7'b11110_11 : 7'b11111_00;
  localparam logic [6:0] E4M3_OVF = (Saturate == 1) ? 7'b1111_110 : 7'b1111_111;

  // FP32 Bit Fields
  logic         fp32_sign;      // 1-bit
  logic [7:0]   fp32_exponent;  // 8-bit
  logic [22:0]  fp32_mantissa;  // 23-bit

  // MXFP8 Bit Fields
  logic         mxfp8_sign;     // 1-bit
  logic [6:0]   mxfp8_fields;   // E5M2 or E4M3

  // Special Value Flags
  logic is_zero;
  logic is_nan;
  logic is_inf;
  logic is_input_subnorm;

  // Encoding-Dependent Constants
  logic signed  [9:0]   mxfp8_bias, exponent_max, exponent_min;
  logic         [6:0]   nan_fields, ovf_fields;

  // Extract FP32 Bit Fields
  assign fp32_sign      = fp32_i[31];
  assign fp32_exponent  = fp32_i[30:23];
  assign fp32_mantissa  = fp32_i[22:0];

  // Is a Special Value?
  assign is_zero           = (fp32_exponent == 8'h00) && (fp32_mantissa == '0);
  assign is_nan            = (fp32_exponent == 8'hff) && (fp32_mantissa != '0);
  assign is_inf            = (fp32_exponent == 8'hff) && (fp32_mantissa == '0);
  assign is_input_subnorm  = (fp32_exponent == 8'h00) && (fp32_mantissa != '0);

  assign mxfp8_bias    = quantize_mxfp8alt_i ? E4M3_BIAS         : E5M2_BIAS;
  assign exponent_max  = quantize_mxfp8alt_i ? E4M3_EXPONENT_MAX : E5M2_EXPONENT_MAX;
  assign exponent_min  = quantize_mxfp8alt_i ? E4M3_EXPONENT_MIN : E5M2_EXPONENT_MIN;
  assign nan_fields    = quantize_mxfp8alt_i ? E4M3_NAN          : E5M2_NAN;
  assign ovf_fields    = quantize_mxfp8alt_i ? E4M3_OVF          : E5M2_OVF;

  // Intermediate Signals
  logic signed  [9:0]   unbiased_exponent, scaled_exponent, final_exponent, shift_raw;
  logic         [4:0]   shift_amt;
  logic         [23:0]  full_mantissa, shifted_mantissa;
  logic         [4:0]   rounded_mantissa;
  logic                 guard, sticky, roundbit, carry, reserved_hit;

  always_comb begin
    // Default Assignment
    mxfp8_fields      = '0;
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
    carry             = 1'b0;
    reserved_hit      = 1'b0;
    // Value is Zero
    if (is_zero) begin
      mxfp8_fields  = '0;
    // Value is NaN
    end else if (is_nan) begin
      mxfp8_fields  = nan_fields;
    // Value is Inf
    end else if (is_inf) begin
      mxfp8_fields  = ovf_fields;
    end else begin
      unbiased_exponent = is_input_subnorm ? (1 - FP32_BIAS) : (fp32_exponent - FP32_BIAS);
      full_mantissa     = is_input_subnorm ? {1'b0, fp32_mantissa} : {1'b1, fp32_mantissa};
      scaled_exponent   = unbiased_exponent - ($signed({2'b00, scale_i}) - SCALE_BIAS);
      // Overflow
      if (scaled_exponent > exponent_max) begin
        mxfp8_fields  = ovf_fields;
      // Normal (scaled_exponent >= exponent_min) or Subnormal/Underflow (below)
      end else begin
        shift_raw         = exponent_min - scaled_exponent;
        shift_amt         = (shift_raw <= 0) ? 5'd0 : (shift_raw > 5'd24) ? 5'd24 : shift_raw[4:0];
        shifted_mantissa  = full_mantissa >> shift_amt;
        // Round to Nearest Even
        rounded_mantissa  = quantize_mxfp8alt_i ? {1'b0, shifted_mantissa[23:20]} : {2'b00, shifted_mantissa[23:21]};
        guard             = quantize_mxfp8alt_i ? shifted_mantissa[19]            : shifted_mantissa[20];
        sticky            = quantize_mxfp8alt_i ? |(shifted_mantissa[18:0])       : |(shifted_mantissa[19:0]);
        roundbit          = guard & (sticky | rounded_mantissa[0]);
        rounded_mantissa  = rounded_mantissa + roundbit;
        if (shift_amt == 5'd0) begin
          carry           = quantize_mxfp8alt_i ? rounded_mantissa[4] : rounded_mantissa[3];
          final_exponent  = scaled_exponent + mxfp8_bias + carry;
          reserved_hit    = quantize_mxfp8alt_i ? (final_exponent > 10'sd15 || (final_exponent == 10'sd15 && rounded_mantissa[2:0] == '1))
                                                : (final_exponent >= 10'sd31);
          if (reserved_hit) begin
            mxfp8_fields  = ovf_fields;
          end else begin
            mxfp8_fields  = quantize_mxfp8alt_i ? {final_exponent[3:0], rounded_mantissa[2:0]} : {final_exponent[4:0], rounded_mantissa[1:0]};
          end
        end else if (quantize_mxfp8alt_i ? rounded_mantissa[3] : rounded_mantissa[2]) begin
          mxfp8_fields  = quantize_mxfp8alt_i ? 7'b0001_000 : 7'b00001_00;
        end else begin
          mxfp8_fields  = quantize_mxfp8alt_i ? {4'b0, rounded_mantissa[2:0]} : {5'b0, rounded_mantissa[1:0]};
        end
      end
    end
  end

  assign mxfp8_sign = fp32_sign;
  assign mxfp8_o    = {mxfp8_sign, mxfp8_fields};

endmodule : fp32_to_mxfp8_quantizer
