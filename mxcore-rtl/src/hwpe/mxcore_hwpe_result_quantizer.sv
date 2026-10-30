// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_result_quantizer #(
  parameter bit          Saturate           = 1,     // 0 - NONSAT Mode, 1 - SAT Mode
  parameter int unsigned BlockSize          = 32,
  parameter int unsigned ScaleWidth         = 8,
  parameter int unsigned InputDataWidth     = BlockSize * 32,
  parameter int unsigned OutputDataWidth    = BlockSize  * 8,
  parameter int unsigned Fp4OutputDataWidth = BlockSize  * 4
) (
  // Global Signals
  input  logic                      clk_i,
  input  logic                      rst_ni,
  // Control
  input  logic                      block_poison_i,
  input  logic                      quantize_mxfp8alt_i,
  input  logic                      quantize_mxfp4_i,
  // Input Data Stream
  hwpe_stream_intf_stream.sink      fp32_result_i,
  // Output Data Stream
  hwpe_stream_intf_stream.source    mxfp8_result_o,
  hwpe_stream_intf_stream.source    mxfp4_result_o,
  hwpe_stream_intf_stream.source    mx_result_scale_o
);

  localparam logic [7:0]            E5M2_NAN  = 8'b0_11111_01;
  localparam logic [7:0]            E4M3_NAN  = 8'b0_1111_111;
  localparam logic [ScaleWidth-1:0] E8M0_NAN  = '1;

  // FP32 Block
  logic [InputDataWidth-1:0]  fp32_block;

  // Shared Block Scale
  logic [ScaleWidth-1:0]   block_scale;
  logic                     block_poison;

  // MXFP8 Quantized Block
  logic [BlockSize*8-1:0]  mxfp8_block;

  // MXFP4 Quantized Block
  logic [BlockSize*4-1:0]  mxfp4_block;

  assign fp32_block = fp32_result_i.data;

  block_scale #(
    .BlockSize   ( BlockSize  ),
    .ScaleWidth  ( ScaleWidth )
  ) i_block_scale (
    .clk_i                ( clk_i               ),
    .rst_ni               ( rst_ni              ),
    .quantize_mxfp8alt_i  ( quantize_mxfp8alt_i ),
    .quantize_mxfp4_i     ( quantize_mxfp4_i    ),
    .fp32_block_i         ( fp32_block          ),
    .block_scale_o        ( block_scale         ),
    .block_poison_o       ( block_poison        )
  );

  logic [31:0]  fp32_data   [BlockSize];
  logic [7:0]   mxfp8_data  [BlockSize];
  logic [3:0]   mxfp4_data  [BlockSize];

  generate
    for (genvar i = 0; i < BlockSize; i++) begin : quantizer_array
      assign fp32_data[i] = fp32_block[i*32+:32];
      fp32_to_mxfp8_quantizer #(
        .Saturate ( Saturate )
      ) i_quantizer (
        .clk_i                ( clk_i               ),
        .rst_ni               ( rst_ni              ),
        .quantize_mxfp8alt_i  ( quantize_mxfp8alt_i ),
        .scale_i              ( block_scale         ),
        .fp32_i               ( fp32_data[i]        ),
        .mxfp8_o              ( mxfp8_data[i]       )
      );
      assign mxfp8_block[i*8+:8] = (block_poison && block_poison_i) ? (quantize_mxfp8alt_i ? E4M3_NAN : E5M2_NAN) : mxfp8_data[i];
      fp32_to_mxfp4_quantizer i_mxfp4_quantizer (
        .clk_i    ( clk_i         ),
        .rst_ni   ( rst_ni        ),
        .scale_i  ( block_scale   ),
        .fp32_i   ( fp32_data[i]  ),
        .mxfp4_o  ( mxfp4_data[i] )
      );
      assign mxfp4_block[i*4+:4] = (block_poison && block_poison_i) ? 4'b0 : mxfp4_data[i];
    end
  endgenerate

  assign fp32_result_i.ready  = quantize_mxfp4_i ? mxfp4_result_o.ready : mxfp8_result_o.ready;

  assign mxfp8_result_o.valid = fp32_result_i.valid && !quantize_mxfp4_i;
  assign mxfp8_result_o.data  = mxfp8_block;
  assign mxfp8_result_o.strb  = {(OutputDataWidth/8){1'b1}};

  assign mxfp4_result_o.valid = fp32_result_i.valid && quantize_mxfp4_i;
  assign mxfp4_result_o.data  = mxfp4_block;
  assign mxfp4_result_o.strb  = {(Fp4OutputDataWidth/8){1'b1}};

  assign mx_result_scale_o.valid = fp32_result_i.valid;
  assign mx_result_scale_o.data  = (block_poison && block_poison_i && quantize_mxfp4_i) ? E8M0_NAN : block_scale;
  assign mx_result_scale_o.strb  = {ScaleWidth/8{1'b1}};

endmodule : mxcore_hwpe_result_quantizer
