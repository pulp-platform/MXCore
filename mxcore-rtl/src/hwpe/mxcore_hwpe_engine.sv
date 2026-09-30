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
  // // Result
  hwpe_stream_intf_stream.source    result_o,
  // Control Channel
  input     ctrl_engine_t           ctrl_i,
  output    flags_engine_t          flags_o
);

  // Output Handshake Signals
  logic                           output_valid;

  // Output Data
  logic [NPE-1:0][DST_WIDTH-1:0]  mxdotp_result;

  // MXDOTP Engine - PE Array + Buffer Controllers + Reuse Counters
  mxcore_engine #(
    .InputDataWidth ( MXCoreTCDMDataWidth )
  ) i_mxcore_engine (
    .clk_i              ( clk_i                 ),
    .rst_ni             ( rst_ni                ),
    .clear_i            ( clear_i               ),
    .vector_a_valid_i   ( vector_a_i.valid      ),
    .vector_a_ready_o   ( vector_a_i.ready      ),
    .vector_a_i         ( vector_a_i.data       ),
    .scale_a_valid_i    ( scale_a_i.valid       ),
    .scale_a_ready_o    ( scale_a_i.ready       ),
    .scale_a_i          ( scale_a_i.data        ),
    .vectors_b_valid_i  ( vectors_b_i.valid     ),
    .vectors_b_ready_o  ( vectors_b_i.ready     ),
    .vectors_b_i        ( vectors_b_i.data      ),
    .scale_b_valid_i    ( scale_b_i.valid       ),
    .scale_b_ready_o    ( scale_b_i.ready       ),
    .scale_b_i          ( scale_b_i.data        ),
    .sbmat_lt_bw_i      ( ctrl_i.sbmat_lt_bw    ),
    .rnd_mode_i         ( ctrl_i.rnd_mode       ),
    .op_i               ( ctrl_i.op             ),
    .op_mod_i           ( ctrl_i.op_mod         ),
    .src_fmt_i          ( ctrl_i.src_fmt        ),
    .int_fmt_i          ( fpnew_pkg::INT8       ),
    .dst_fmt_i          ( ctrl_i.dst_fmt        ),
    .ireuse_i           ( ctrl_i.iter_count     ),
    .flush_i            ( ctrl_i.flush          ),
    .result_o           ( mxdotp_result         ),
    .out_valid_o        ( output_valid          ),
    .out_ready_i        ( result_o.ready        ),
    .busy_o             ( flags_o.busy          )
  );

  logic [MXCoreEngineResultDataWidth/8-1:0]  result_strb;
  assign result_strb = '1;

  assign result_o.valid = output_valid;
  assign result_o.data  = mxdotp_result;
  assign result_o.strb  = result_strb;

endmodule : mxcore_hwpe_engine
