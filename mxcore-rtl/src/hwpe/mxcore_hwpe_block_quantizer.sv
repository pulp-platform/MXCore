// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_block_quantizer
  import mxcore_package::*;
#(
  parameter bit          Encoding         = 0,     // 0 - E5M2, 1 - E4M3
  parameter bit          Saturate         = 1,     // 0 - NONSAT Mode, 1 - SAT Mode
  parameter int unsigned BlockSize        = 32,
  parameter int unsigned ScaleWidth       = 8,
  parameter int unsigned InputDataWidth   = 1024
) (
  // Global Signals
  input  logic                      clk_i,
  input  logic                      rst_ni,
  // Control
  input  logic                      block_poison_i,
  // Input Data Stream
  hwpe_stream_intf_stream.sink      fp32_result_i,
  // Output Data Stream - Quantized Blocks and Scales
  hwpe_stream_intf_stream.source    mxfp8_result_o,
  hwpe_stream_intf_stream.source    mx_result_scale_o
);

  localparam int unsigned QUANT_IN_DATA_WIDTH   = BlockSize * 32;
  localparam int unsigned QUANT_OUT_DATA_WIDTH  = BlockSize * 8;
  localparam int unsigned NQUANTIZER            = InputDataWidth / QUANT_IN_DATA_WIDTH;

  hwpe_stream_intf_stream #(.DATA_WIDTH (QUANT_IN_DATA_WIDTH))  quant_fp32_i  [NQUANTIZER] ( .clk ( clk_i ));
  hwpe_stream_intf_stream #(.DATA_WIDTH (QUANT_OUT_DATA_WIDTH)) quant_mxfp8_o [NQUANTIZER] ( .clk ( clk_i ));
  hwpe_stream_intf_stream #(.DATA_WIDTH (ScaleWidth))          quant_scale_o [NQUANTIZER] ( .clk ( clk_i ));

  logic [NQUANTIZER-1:0]    quant_fp32_ready;

  logic [NQUANTIZER-1:0]                           quant_mxfp8_valid;
  logic [NQUANTIZER*QUANT_OUT_DATA_WIDTH-1:0]      quant_mxfp8_data;
  logic [NQUANTIZER*QUANT_OUT_DATA_WIDTH/8-1:0]    quant_mxfp8_strb;

  logic [NQUANTIZER-1:0]                           quant_scale_valid;
  logic [NQUANTIZER*ScaleWidth-1:0]               quant_scale_data;
  logic [NQUANTIZER*ScaleWidth/8-1:0]             quant_scale_strb;

  generate
    for (genvar i = 0; i < NQUANTIZER; i++) begin : assign_quantizer_input_stream
      assign quant_fp32_i[i].valid  = fp32_result_i.valid;
      assign quant_fp32_ready[i]    = quant_fp32_i[i].ready;
      assign quant_fp32_i[i].data   = fp32_result_i.data[i*QUANT_IN_DATA_WIDTH+:QUANT_IN_DATA_WIDTH];
      assign quant_fp32_i[i].strb   = fp32_result_i.strb[i*QUANT_IN_DATA_WIDTH/8+:QUANT_IN_DATA_WIDTH/8];
    end
  endgenerate

  assign fp32_result_i.ready    = &quant_fp32_ready;

  generate
    for (genvar i = 0; i < NQUANTIZER; i++) begin : quantizer_array
      mxcore_hwpe_result_quantizer #(
        .Encoding     ( Encoding    ),
        .Saturate     ( Saturate    ),
        .BlockSize   ( BlockSize  ),
        .ScaleWidth  ( ScaleWidth )
      ) i_quantizer (
        .clk_i             ( clk_i            ),
        .rst_ni            ( rst_ni           ),
        .block_poison_i    ( block_poison_i   ),
        .fp32_result_i     ( quant_fp32_i[i]  ),
        .mxfp8_result_o    ( quant_mxfp8_o[i] ),
        .mx_result_scale_o ( quant_scale_o[i] )
      );
    end
  endgenerate

  generate
    for (genvar i = 0; i < NQUANTIZER; i++) begin : acquire_quantizer_output_stream
      assign quant_mxfp8_valid[i]                                               = quant_mxfp8_o[i].valid;
      assign quant_mxfp8_o[i].ready                                             = mxfp8_result_o.ready;
      assign quant_mxfp8_data[i*QUANT_OUT_DATA_WIDTH+:QUANT_OUT_DATA_WIDTH]     = quant_mxfp8_o[i].data[0+:QUANT_OUT_DATA_WIDTH];
      assign quant_mxfp8_strb[i*QUANT_OUT_DATA_WIDTH/8+:QUANT_OUT_DATA_WIDTH/8] = '1;
      assign quant_scale_valid[i]                                               = quant_scale_o[i].valid;
      assign quant_scale_o[i].ready                                             = mx_result_scale_o.ready;
      assign quant_scale_data[i*ScaleWidth+:ScaleWidth]                       = quant_scale_o[i].data[0+:ScaleWidth];
      assign quant_scale_strb[i*ScaleWidth/8+:ScaleWidth/8]                   = '1;
    end
  endgenerate

  // Valid: all NQUANTIZER run; wait for all to be valid
  assign mxfp8_result_o.valid     = &quant_mxfp8_valid;
  assign mxfp8_result_o.data      = quant_mxfp8_data;
  assign mxfp8_result_o.strb      = quant_mxfp8_strb;

  assign mx_result_scale_o.valid  = &quant_scale_valid;
  assign mx_result_scale_o.data   = quant_scale_data;
  assign mx_result_scale_o.strb   = quant_scale_strb;

endmodule : mxcore_hwpe_block_quantizer