// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_block_quantizer #(
  parameter bit          Encoding         = 0,     // 0 - E5M2, 1 - E4M3
  parameter bit          Saturate         = 1      // 0 - NONSAT Mode, 1 - SAT Mode
) (
  // Global Signals
  input  logic                      clk_i,
  input  logic                      rst_ni,
  // Control
  input  logic                      block_poison_i,
  input  logic                      quantize_mxfp8_i,
  input  logic                      quantize_bf16_i,
  // Input Data Stream
  hwpe_stream_intf_stream.sink      fp32_result_i,
  // Output Data Stream - MXFP8 Quantized Blocks and Scales
  hwpe_stream_intf_stream.source    mxfp8_result_o,
  hwpe_stream_intf_stream.source    mx_result_scale_o,
  // Output Data Stream - BF16 Quantized Data
  hwpe_stream_intf_stream.source    bf16_result_o
);

  hwpe_stream_intf_stream #(.DATA_WIDTH (1024)) quant_fp32_i  ( .clk ( clk_i ));

  assign quant_fp32_i.valid   = fp32_result_i.valid && quantize_mxfp8_i;
  assign quant_fp32_i.data    = fp32_result_i.data;
  assign quant_fp32_i.strb    = fp32_result_i.strb;
  assign fp32_result_i.ready  = quantize_bf16_i ? bf16_result_o.ready : quant_fp32_i.ready;

  logic [511:0] bf16_data;

  generate
    for (genvar i = 0; i < 32; i++) begin : bf16_quantizer_array
      fp32_to_bf16_quantizer i_bf16_quantizer (
        .clk_i  ( clk_i                         ),
        .rst_ni ( rst_ni                        ),
        .fp32_i ( fp32_result_i.data[i*32+:32]  ),
        .bf16_o ( bf16_data[i*16+:16]           )
      );
    end
  endgenerate

  mxcore_hwpe_result_quantizer #(
    .Encoding     ( Encoding    ),
    .Saturate     ( Saturate    )
  ) i_quantizer (
    .clk_i             ( clk_i              ),
    .rst_ni            ( rst_ni             ),
    .block_poison_i    ( block_poison_i     ),
    .fp32_result_i     ( quant_fp32_i       ),
    .mxfp8_result_o    ( mxfp8_result_o     ),
    .mx_result_scale_o ( mx_result_scale_o  )
  );

  assign bf16_result_o.valid      = fp32_result_i.valid && quantize_bf16_i;
  assign bf16_result_o.data       = bf16_data;
  assign bf16_result_o.strb       = '1;

endmodule : mxcore_hwpe_block_quantizer
