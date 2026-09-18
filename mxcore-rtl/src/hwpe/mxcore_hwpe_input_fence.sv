// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_input_fence
  import mxcore_package::*;
  import mxcore_hwpe_package::*;
  import hwpe_stream_package::*;
#(
    parameter int unsigned MXCoreVectorADataWidth   = 64,
    parameter int unsigned MXCoreVectorsBDataWidth  = 512,
    parameter int unsigned MXCoreScaleADataWidth    = 8,
    parameter int unsigned MXCoreScaleBDataWidth    = 64
) (
    // Global Signals
    input logic                     clk_i,
    input logic                     rst_ni,
    // Clear Signal
    input logic                     clear_i,
    // Test Mode Signal
    input logic                     test_mode_i,
    // Stream Interfaces
    hwpe_stream_intf_stream.sink    vector_a_i,
    hwpe_stream_intf_stream.sink    vectors_b_i,
    hwpe_stream_intf_stream.sink    scale_a_i,
    hwpe_stream_intf_stream.sink    scale_b_i,
    hwpe_stream_intf_stream.source  vector_a_o,
    hwpe_stream_intf_stream.source  vectors_b_o,
    hwpe_stream_intf_stream.source  scale_a_o,
    hwpe_stream_intf_stream.source  scale_b_o
);

  // Fence all inputs to ensure they arrive at the same time
  localparam int unsigned NB_STREAMS = 4;

  hwpe_stream_intf_stream #(
    .DATA_WIDTH (MXCoreVectorsBDataWidth)   // MXCoreVectorsBDataWidth > MXCoreVectorADataWidth > MXCoreScaleBDataWidth > MXCoreScaleADataWidth
  ) split_streams [NB_STREAMS-1:0] (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH (MXCoreVectorsBDataWidth)
  ) fenced_streams [NB_STREAMS-1:0] (
    .clk ( clk_i )
  );

  hwpe_stream_fence #(
    .NB_STREAMS (NB_STREAMS),
    .DATA_WIDTH (MXCoreVectorsBDataWidth)
  ) i_fence (
    .clk_i          ( clk_i             ),
    .rst_ni         ( rst_ni            ),
    .clear_i        ( clear_i           ),
    .test_mode_i    ( test_mode_i       ),
    .push_i         ( split_streams     ),
    .pop_o          ( fenced_streams    )
  );

  hwpe_stream_assign i_split_vector_a_assign    ( .push_i (vector_a_i), .pop_o(split_streams[0])  );
  hwpe_stream_assign i_split_vectors_b_assign   ( .push_i (vectors_b_i), .pop_o(split_streams[1]) );
  hwpe_stream_assign i_split_scale_a_assign     ( .push_i (scale_a_i), .pop_o(split_streams[2])   );
  hwpe_stream_assign i_split_scale_b_assign     ( .push_i (scale_b_i), .pop_o(split_streams[3])   );

  hwpe_stream_assign i_fenced_vector_a_assign   ( .push_i (fenced_streams[0]), .pop_o(vector_a_o) );
  hwpe_stream_assign i_fenced_vectors_b_assign  ( .push_i (fenced_streams[1]), .pop_o(vectors_b_o));
  hwpe_stream_assign i_fenced_scale_a_assign    ( .push_i (fenced_streams[2]), .pop_o(scale_a_o)  );
  hwpe_stream_assign i_fenced_scale_b_assign    ( .push_i (fenced_streams[3]), .pop_o(scale_b_o)  );

endmodule : mxcore_hwpe_input_fence