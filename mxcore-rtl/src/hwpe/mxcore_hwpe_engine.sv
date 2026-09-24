// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_engine
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
  import mxcore_hwpe_package::*;
(
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Test Signals
  input logic                       test_mode_i,
  // Data Signals
  // // Operand Vector A
  hwpe_stream_intf_stream.sink      vector_a_i,
  // // Operand Vector B
  hwpe_stream_intf_stream.sink      vectors_b_i,
  // // Scales
  hwpe_stream_intf_stream.sink      scale_a_i,
  hwpe_stream_intf_stream.sink      scale_b_i,
  // // Preload Bias
  hwpe_stream_intf_stream.sink      preload_bias_i,
  // // Result
  hwpe_stream_intf_stream.source    result_o,
  // Control Channel
  input     ctrl_engine_t           ctrl_i,
  output    flags_engine_t          flags_o
);

  // Input Handshake Signals
  logic [NPE-1:0]  inputs_valid, inputs_ready;

  // Output Handshake Signals
  logic [NPE-1:0]  output_valid, output_ready;

  assign inputs_valid = {NPE{vector_a_i.valid && vectors_b_i.valid && scale_a_i.valid && scale_b_i.valid}};
  assign output_ready = {NPE{result_o.ready}};

  // Input Data
  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0]  operands_a, operands_b;
  logic [NPE-1:0][1:0][SCALE_WIDTH-1:0]           operands_c;
  logic [NPE-1:0][DST_WIDTH-1:0]                  operand_d;
  logic [NUM_FORMATS-1:0][NumOperands-1:0]       is_boxed;

  // Output Data
  logic [NPE-1:0][DST_WIDTH-1:0]  mxdotp_result;

  // Assign Input Operands
  assign operands_a = vectors_b_i.data;
  assign operands_b = {NPE{vector_a_i.data}};
  generate
    for (genvar i = 0; i < NPE; i++) begin : assign_operands_c
      assign operands_c[i][0] = scale_b_i.data[i*SCALE_WIDTH+:SCALE_WIDTH];
      assign operands_c[i][1] = scale_a_i.data;
    end
  endgenerate
  assign operand_d  = '0;
  assign is_boxed   = &inputs_valid ? '1 : '0;

  assign vector_a_i.ready   = &inputs_ready;
  assign vectors_b_i.ready  = &inputs_ready;
  assign scale_a_i.ready    = &inputs_ready;
  assign scale_b_i.ready    = &inputs_ready;

  // MXDOTP Engine - MXDOTP Array + Global Output Buffer + Reuse Counters
  mxcore_engine i_mxcore_engine (
    .clk_i                ( clk_i                 ),
    .rst_ni               ( rst_ni                ),
    .clear_i              ( clear_i               ),
    .operands_a_i         ( operands_a            ),
    .operands_b_i         ( operands_b            ),
    .operands_a_fp6_rem_i ( '0                    ),
    .operands_b_fp6_rem_i ( '0                    ),
    .operands_c_i         ( operands_c            ),
    .operand_d_i          ( operand_d             ),
    .preload_bias_i       ( preload_bias_i        ),
    .is_boxed_i           ( is_boxed              ),
    .rnd_mode_i           ( ctrl_i.rnd_mode       ),
    .op_i                 ( ctrl_i.op             ),
    .op_mod_i             ( ctrl_i.op_mod         ),
    .src_fmt_i            ( ctrl_i.src_fmt        ),
    .int_fmt_i            ( fpnew_pkg::INT8       ),
    .dst_fmt_i            ( ctrl_i.dst_fmt        ),
    .tag_i                ( ctrl_i.tag            ),
    .mask_i               ( ctrl_i.mask           ),
    .aux_i                ( ctrl_i.aux            ),
    .ireuse_i             ( ctrl_i.iter_count     ),
    .preload_i            ( ctrl_i.preload        ),
    .compute_en_i         ( ctrl_i.compute_en     ),
    .in_valid_i           ( inputs_valid          ),
    .in_ready_o           ( inputs_ready          ),
    .flush_i              ( ctrl_i.flush          ),
    .result_o             ( mxdotp_result         ),
    .status_o             ( flags_o.status        ),
    .extension_bit_o      ( flags_o.extension_bit ),
    .tag_o                ( flags_o.tag           ),
    .mask_o               ( flags_o.mask          ),
    .aux_o                ( flags_o.aux           ),
    .out_valid_o          ( output_valid          ),
    .out_ready_i          ( output_ready          ),
    .preload_done_o       ( flags_o.preload_done  ),
    .tile_end_o           ( flags_o.tile_end      ),
    .busy_o               ( flags_o.busy          )
  );

  logic [NPE-1:0][DST_WIDTH-1:0]  result_data_masked;
  assign result_data_masked = mxdotp_result;

  logic [MXCoreEngineResultDataWidth/8-1:0]  result_strb;
  assign result_strb = '1;

  assign result_o.valid = &output_valid;
  assign result_o.data  = result_data_masked;
  assign result_o.strb  = result_strb;

endmodule : mxcore_hwpe_engine