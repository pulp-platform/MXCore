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

  // MXDOTP Engine - PE Array + Buffer Controllers + Reuse Counters
  mxcore_engine #(
    .InputDataWidth ( MXCoreTCDMDataWidth )
  ) i_mxcore_engine (
    .clk_i            ( clk_i                 ),
    .rst_ni           ( rst_ni                ),
    .clear_i          ( clear_i               ),
    .vector_a_i       ( vector_a_i            ),
    .scale_a_i        ( scale_a_i             ),
    .vectors_b_i      ( vectors_b_i           ),
    .scale_b_i        ( scale_b_i             ),
    .preload_bias_i   ( preload_bias_i        ),
    .sbmat_lt_bw_i    ( ctrl_i.sbmat_lt_bw    ),
    .rnd_mode_i       ( ctrl_i.rnd_mode       ),
    .op_i             ( ctrl_i.op             ),
    .op_mod_i         ( ctrl_i.op_mod         ),
    .src_fmt_i        ( ctrl_i.src_fmt        ),
    .int_fmt_i        ( fpnew_pkg::INT8       ),
    .dst_fmt_i        ( ctrl_i.dst_fmt        ),
    .iter_count_i     ( ctrl_i.iter_count     ),
    .preload_i        ( ctrl_i.preload        ),
    .compute_en_i     ( ctrl_i.compute_en     ),
    .flush_i          ( ctrl_i.flush          ),
    .result_o         ( result_o              ),
    .preload_ready_o  ( flags_o.preload_ready ),
    .tile_end_o       ( flags_o.tile_end      ),
    .busy_o           ( flags_o.busy          )
  );

endmodule : mxcore_hwpe_engine
