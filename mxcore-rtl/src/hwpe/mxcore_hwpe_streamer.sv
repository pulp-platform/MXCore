// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "hci_helpers.svh"

module mxcore_hwpe_streamer
  import mxcore_package::*;
  import mxcore_hwpe_package::*;
  import hwpe_stream_package::*;
  import hci_package::*;
#(
    parameter int unsigned  TCDMDataWidth = 32,
    localparam int unsigned REALIGN       = 0
) (
    // Global Signals
    input logic                     clk_i,
    input logic                     rst_ni,
    // Test Signals
    input logic                     test_mode_i,
    // Local Enable & Clear
    input logic                     enable_i,
    input logic                     clear_i,
    // Operand Vector A Stream + Handshake
    hwpe_stream_intf_stream.source  vector_a_o,
    // Operand Vector B Stream + Handshake
    hwpe_stream_intf_stream.source  vectors_b_o,
    // Scales Stream + Handshake
    hwpe_stream_intf_stream.source  scale_a_o,
    hwpe_stream_intf_stream.source  scale_b_o,
    // Result Stream + Handshake
    hwpe_stream_intf_stream.sink    result_i,
    hwpe_stream_intf_stream.sink    result_scale_i,
    // TCDM Ports
    hci_core_intf.initiator         tcdm_o,
    // Control Channel
    input   ctrl_streamer_t         ctrl_i,
    output  flags_streamer_t        flags_o,
    output  flags_fifo_t            flags_fifo_o
);

  // Multiplex TCDM Ports (Operand Vector A, Operand Vector B, Scales, Accumulator, Result)
  localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm_dw) = '{
    DW:     MXCoreTCDMDataWidth,
    AW:     DEFAULT_AW,
    BW:     DEFAULT_BW,
    UW:     DEFAULT_UW,
    IW:     IdWidth,
    EW:     DEFAULT_EW,
    EHW:    DEFAULT_EHW
  };
  `HCI_INTF_EXPLICIT_PARAM(tcdm_vector_a, clk_i, HCI_SIZE_tcdm_dw);
  `HCI_INTF_EXPLICIT_PARAM(tcdm_vectors_b, clk_i, HCI_SIZE_tcdm_dw);
  `HCI_INTF_EXPLICIT_PARAM(tcdm_scale_a, clk_i, HCI_SIZE_tcdm_dw);
  `HCI_INTF_EXPLICIT_PARAM(tcdm_scale_b, clk_i, HCI_SIZE_tcdm_dw);
  `HCI_INTF_EXPLICIT_PARAM(tcdm_result, clk_i, HCI_SIZE_tcdm_dw);

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(virt_tcdm) = '{
    DW:     MXCoreTCDMDataWidth,
    AW:     DEFAULT_AW,
    BW:     DEFAULT_BW,
    UW:     DEFAULT_UW,
    IW:     IdWidth,
    EW:     DEFAULT_EW,
    EHW:    DEFAULT_EHW
  };
  `HCI_INTF_ARRAY(virt_tcdm, clk_i, 0:4);

  `HCI_INTF_EXPLICIT_PARAM(ldst_tcdm, clk_i, HCI_SIZE_tcdm_dw);

  hci_core_assign i_load_vector_a_assign  ( .tcdm_target (tcdm_vector_a),   .tcdm_initiator (virt_tcdm[0]) );
  hci_core_assign i_load_vectors_b_assign ( .tcdm_target (tcdm_vectors_b),  .tcdm_initiator (virt_tcdm[1]) );
  hci_core_assign i_load_scale_a_assign   ( .tcdm_target (tcdm_scale_a),    .tcdm_initiator (virt_tcdm[2]) );
  hci_core_assign i_load_scale_b_assign   ( .tcdm_target (tcdm_scale_b),    .tcdm_initiator (virt_tcdm[3]) );
  hci_core_assign i_store_result_assign   ( .tcdm_target (tcdm_result),     .tcdm_initiator (virt_tcdm[4]) );

  hci_core_mux_ooo #(
    .NB_CHAN ( 5 ),
    .`HCI_SIZE_PARAM(out) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_ldst_mux (
    .clk_i              ( clk_i     ),
    .rst_ni             ( rst_ni    ),
    .clear_i            ( clear_i   ),
    .priority_force_i   ( 1'b1      ),
    .priority_i         ( {3'h4, 3'h3, 3'h2, 3'h1, 3'h0} ), // Vector A > Vector B > Scale A > Scale B > Result
    .in                 ( virt_tcdm ),
    .out                ( ldst_tcdm )
  );

  hci_core_r_id_filter #(
    .`HCI_SIZE_PARAM(tcdm_target) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_ldst_filter (
    .clk_i          ( clk_i     ),
    .rst_ni         ( rst_ni    ),
    .clear_i        ( clear_i   ),
    .enable_i       ( enable_i  ),
    .tcdm_target    ( ldst_tcdm ),
    .tcdm_initiator ( tcdm_o    )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_vector_a_fifo (
    .clk ( clk_i )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_vectors_b_fifo (
    .clk ( clk_i )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_scale_a_fifo (
    .clk ( clk_i )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_scale_b_fifo (
    .clk ( clk_i )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_result_fifo (
    .clk ( clk_i )
  );

  hci_core_intf #(
  `ifndef SYNTHESIS
    .WAIVE_RQ4_ASSERT  (    1'b1 ),
    .WAIVE_RSP3_ASSERT (    1'b1 ),
  `endif
    .DW  ( HCI_SIZE_tcdm_dw.DW  ),
    .AW  ( HCI_SIZE_tcdm_dw.AW  ),
    .BW  ( HCI_SIZE_tcdm_dw.BW  ),
    .UW  ( HCI_SIZE_tcdm_dw.UW  ),
    .IW  ( HCI_SIZE_tcdm_dw.IW  ),
    .EW  ( HCI_SIZE_tcdm_dw.EW  ),
    .EHW ( HCI_SIZE_tcdm_dw.EHW )
  ) tcdm_result_scale_fifo (
    .clk ( clk_i )
  );

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(result_mux_tcdm) = '{
    DW:     MXCoreTCDMDataWidth,
    AW:     DEFAULT_AW,
    BW:     DEFAULT_BW,
    UW:     DEFAULT_UW,
    IW:     IdWidth,
    EW:     DEFAULT_EW,
    EHW:    DEFAULT_EHW
  };
  `HCI_INTF_ARRAY(result_mux_tcdm, clk_i, 0:1);

  hci_core_assign i_result_mux_assign       ( .tcdm_target (tcdm_result_fifo),        .tcdm_initiator (result_mux_tcdm[0]) );
  hci_core_assign i_result_scale_mux_assign ( .tcdm_target (tcdm_result_scale_fifo),  .tcdm_initiator (result_mux_tcdm[1]) );

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm_result_muxed) = '{
    DW:     MXCoreTCDMDataWidth,
    AW:     DEFAULT_AW,
    BW:     DEFAULT_BW,
    UW:     DEFAULT_UW,
    IW:     IdWidth,
    EW:     DEFAULT_EW,
    EHW:    DEFAULT_EHW
  };
  `HCI_INTF_ARRAY(tcdm_result_muxed, clk_i, 0:0);

  hci_core_mux_dynamic #(
    .NB_IN_CHAN   ( 2 ),
    .NB_OUT_CHAN  ( 1 ),
    .`HCI_SIZE_PARAM(in)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_result_fifo_mux (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),
    .clear_i    ( clear_i           ),
    .in         ( result_mux_tcdm   ),
    .out        ( tcdm_result_muxed )
  );

  hci_core_source #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_vector_a_stream_source (
    .clk_i       ( clk_i                            ),
    .rst_ni      ( rst_ni                           ),
    .test_mode_i ( test_mode_i                      ),
    .clear_i     ( clear_i                          ),
    .enable_i    ( enable_i                         ),
    .tcdm        ( tcdm_vector_a_fifo               ),
    .stream      ( vector_a_o                       ),
    .ctrl_i      ( ctrl_i.vector_a_source_ctrl      ),
    .flags_o     ( flags_o.vector_a_source_flags    )
  );

  hci_core_source #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_vectors_b_stream_source (
    .clk_i       ( clk_i                           ),
    .rst_ni      ( rst_ni                          ),
    .test_mode_i ( test_mode_i                     ),
    .clear_i     ( clear_i                         ),
    .enable_i    ( enable_i                        ),
    .tcdm        ( tcdm_vectors_b_fifo             ),
    .stream      ( vectors_b_o                     ),
    .ctrl_i      ( ctrl_i.vectors_b_source_ctrl    ),
    .flags_o     ( flags_o.vectors_b_source_flags  )
  );

  hci_core_source #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .DIM_ENABLE_1H          ( 4'b0111 ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_scale_a_stream_source (
    .clk_i       ( clk_i                         ),
    .rst_ni      ( rst_ni                        ),
    .test_mode_i ( test_mode_i                   ),
    .clear_i     ( clear_i                       ),
    .enable_i    ( enable_i                      ),
    .tcdm        ( tcdm_scale_a_fifo             ),
    .stream      ( scale_a_o                     ),
    .ctrl_i      ( ctrl_i.scale_a_source_ctrl    ),
    .flags_o     ( flags_o.scale_a_source_flags  )
  );

  hci_core_source #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_scale_b_stream_source (
    .clk_i       ( clk_i                          ),
    .rst_ni      ( rst_ni                         ),
    .test_mode_i ( test_mode_i                    ),
    .clear_i     ( clear_i                        ),
    .enable_i    ( enable_i                       ),
    .tcdm        ( tcdm_scale_b_fifo              ),
    .stream      ( scale_b_o                      ),
    .ctrl_i      ( ctrl_i.scale_b_source_ctrl     ),
    .flags_o     ( flags_o.scale_b_source_flags   )
  );

  hci_core_sink #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_result_stream_sink (
    .clk_i       ( clk_i                            ),
    .rst_ni      ( rst_ni                           ),
    .test_mode_i ( test_mode_i                      ),
    .clear_i     ( clear_i                          ),
    .enable_i    ( enable_i                         ),
    .tcdm        ( tcdm_result_fifo                 ),
    .stream      ( result_i                         ),
    .ctrl_i      ( ctrl_i.result_sink_ctrl          ),
    .flags_o     ( flags_o.result_sink_flags        )
  );

  hci_core_sink #(
    .MISALIGNED_ACCESSES    ( REALIGN ),
    .`HCI_SIZE_PARAM(tcdm)  ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_result_scale_stream_sink (
    .clk_i       ( clk_i                            ),
    .rst_ni      ( rst_ni                           ),
    .test_mode_i ( test_mode_i                      ),
    .clear_i     ( clear_i                          ),
    .enable_i    ( enable_i                         ),
    .tcdm        ( tcdm_result_scale_fifo           ),
    .stream      ( result_scale_i                   ),
    .ctrl_i      ( ctrl_i.result_scale_sink_ctrl    ),
    .flags_o     ( flags_o.result_scale_sink_flags  )
  );

  hci_core_fifo #(
    .FIFO_DEPTH ( 2 ),
    .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_tcdm_vector_a_fifo (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .flags_o        (                       ),
    .tcdm_target    ( tcdm_vector_a_fifo    ),
    .tcdm_initiator ( tcdm_vector_a         )
  );

  hci_core_fifo #(
    .FIFO_DEPTH ( 2 ),
    .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_tcdm_vectors_b_fifo (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .flags_o        (                       ),
    .tcdm_target    ( tcdm_vectors_b_fifo   ),
    .tcdm_initiator ( tcdm_vectors_b        )
  );

  hci_core_fifo #(
    .FIFO_DEPTH ( 2 ),
    .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_tcdm_scale_a_fifo (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .flags_o        (                       ),
    .tcdm_target    ( tcdm_scale_a_fifo     ),
    .tcdm_initiator ( tcdm_scale_a          )
  );

  hci_core_fifo #(
    .FIFO_DEPTH ( 2 ),
    .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_tcdm_scale_b_fifo (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .flags_o        (                       ),
    .tcdm_target    ( tcdm_scale_b_fifo     ),
    .tcdm_initiator ( tcdm_scale_b          )
  );

  hci_core_fifo #(
    .FIFO_DEPTH ( 2 ),
    .`HCI_SIZE_PARAM(tcdm_initiator) ( `HCI_SIZE_PARAM(tcdm_dw) )
  ) i_tcdm_result_fifo (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .flags_o        ( flags_fifo_o          ),
    .tcdm_target    ( tcdm_result_muxed[0]  ),
    .tcdm_initiator ( tcdm_result           )
  );

endmodule : mxcore_hwpe_streamer