// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module block_scale #(
  parameter bit          Encoding    = 0,     // 0 - E5M2, 1 - E4M3
  parameter int unsigned BlockSize   = 32,
  parameter int unsigned ScaleWidth  = 8
) (
  // Global Signals
  input  logic                        clk_i,
  input  logic                        rst_ni,
  // Input FP32 Block
  input  logic [BlockSize*32-1:0]    fp32_block_i,
  // Output Block Scale
  output logic [ScaleWidth-1:0]      block_scale_o,
  output logic                        block_poison_o
);

  localparam int E5M2_EMAX  = 15;
  localparam int E4M3_EMAX  = 8;
  localparam int MXFP8_EMAX = (Encoding == 0) ? E5M2_EMAX : E4M3_EMAX;

  // Number of Levels/Stages in the Comparator Tree
  localparam int STAGES     = $clog2(BlockSize);

  // Bit Fields
  logic [7:0]    fp32_exponents  [BlockSize];
  logic [22:0]   fp32_mantissae  [BlockSize];

  // NaN/Inf per Element
  logic [BlockSize-1:0]  is_special;

  // Maximum Exponent
  logic [7:0]  max_exponent;

  // Scaled Exponent
  logic signed [9:0]  scaled_exponent;

  // Comparator Tree Stages
  logic [STAGES:0][BlockSize-1:0][7:0]  stage;

  generate
    for (genvar i = 0; i < BlockSize; i++) begin : extract_bit_fields
      assign fp32_exponents[i]  = fp32_block_i[i*32+30-:8];   // FP32 Exponents
      assign fp32_mantissae[i]  = fp32_block_i[i*32+22-:23];  // FP32 Mantissae
      assign is_special[i]      = (fp32_exponents[i] == 8'hff);
    end
  endgenerate

  // Comparator Tree
  generate
    for (genvar i = 0; i < BlockSize; i++) begin : stage_zero
      assign stage[0][i]  = fp32_exponents[i];
    end
  endgenerate
  generate
    for (genvar s = 0; s < STAGES; s++) begin : comparator_tree
      localparam int NUM_ELEMS = BlockSize >> s;
      for (genvar i = 0; i < NUM_ELEMS/2; i++) begin : compare
        assign stage[s+1][i]  = (stage[s][2*i] > stage[s][2*i+1]) ? stage[s][2*i] : stage[s][2*i+1];
      end
    end
  endgenerate
  assign max_exponent = stage[STAGES][0];

  // OCP E8M0 Scale (Bias 127)
  assign scaled_exponent  = $signed({2'b00, max_exponent}) - MXFP8_EMAX;
  assign block_scale_o    = (scaled_exponent < 0) ? '0 : scaled_exponent[ScaleWidth-1:0];

  assign block_poison_o   = |is_special;

endmodule : block_scale
