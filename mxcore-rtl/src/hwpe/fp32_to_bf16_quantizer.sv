// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module fp32_to_bf16_quantizer (
  // Global Signals
  input  logic              clk_i,
  input  logic              rst_ni,
  // FP32 Value
  input  logic [31:0]       fp32_i,
  // BF16 Value
  output logic [15:0]       bf16_o
);

  logic         is_nan;
  logic [31:0]  rounded;

  assign is_nan   = (fp32_i[30:23] == 8'hff) && (fp32_i[22:0] != '0);
  assign rounded  = fp32_i + 32'h0000_7fff + {31'b0, fp32_i[16]};       // RNE
  assign bf16_o   = is_nan ? {fp32_i[31], 15'h7fc0} : rounded[31:16];   

endmodule : fp32_to_bf16_quantizer
