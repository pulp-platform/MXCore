// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_engine
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
#(
  parameter int unsigned InputDataWidth = 512
) (
  // Global Signals
  input  logic                                          clk_i,
  input  logic                                          rst_ni,
  input  logic                                          clear_i,
  // Input signals
  hwpe_stream_intf_stream.sink                          vector_a_i,
  hwpe_stream_intf_stream.sink                          scale_a_i,
  hwpe_stream_intf_stream.sink                          vectors_b_i,
  hwpe_stream_intf_stream.sink                          scale_b_i,
  // Input Control/Configuration Signals
  input  logic                                          sbmat_lt_bw_i,
  input  fpnew_pkg::roundmode_e                         rnd_mode_i,
  input  fpnew_pkg::operation_e                         op_i,
  input  logic                                          op_mod_i,
  input  fpnew_pkg::fp_format_e                         src_fmt_i,
  input  fpnew_pkg::int_format_e                        int_fmt_i,
  input  fpnew_pkg::fp_format_e                         dst_fmt_i,
  input  logic [15:0]                                   ireuse_i,
  input  logic                                          flush_i,
  // Output Signals
  hwpe_stream_intf_stream.source                        result_o,
  // Indication of valid data in flight
  output logic                                          busy_o
);

  localparam int unsigned ScaleBDataWidth   = (NPE*MXCoreScaleDataWidth < InputDataWidth) ? (NPE*MXCoreScaleDataWidth) : InputDataWidth;
  localparam int unsigned ScaleFactor       = BlockSize / VectorSize;
  localparam int unsigned AddrWidth         = (Reuse > 1) ? $clog2(Reuse) : 1;

  // MXDOTP Array Signals
  logic                                     mxdotp_in_ready;
  logic                                     mxdotp_result_valid;
  logic                                     mxdotp_result_ready;
  logic                                     mxdotp_busy;

  // Vector B Buffer Signals
  logic                                     vector_b_valid;
  logic [NPE-1:0]                           vector_b_write_enable;
  logic                                     vector_b_write_addr;
  logic                                     vector_b_read_addr;

  // Scale B Buffer Signals
  logic                                     scale_b_valid;
  logic [NPE-1:0]                           scale_b_write_enable;
  logic                                     scale_b_write_addr;
  logic [ScaleBDataWidth-1:0]               scale_b;
  logic                                     scale_b_read_addr;

  // Output Buffer Signals
  logic                                     obuff_result_valid, obuff_result_ready;
  logic                                     tile_result_valid, tile_result_ready;
  logic [NPE-1:0][DST_WIDTH-1:0]            tile_result;
  logic                                     obuff_empty;
  logic                                     output_buffer_write_enable;
  logic [AddrWidth-1:0]                     output_buffer_write_addr;
  logic [AddrWidth-1:0]                     output_buffer_read_addr;
  logic [AddrWidth-1:0]                     output_buffer_tile_addr;

  // Input Multiplexing
  logic [MXCoreVectorDataWidth-1:0]         vector_a;
  logic [MXCoreScaleDataWidth-1:0]          scale_a;

  // Iteration Status Signals
  logic first_iter, last_iter;
  logic inputs_valid, in_accept, in_fire, out_fire;

  // Inputs after the first iteration also need their partial result from the output buffer
  assign inputs_valid       = vector_a_i.valid && scale_a_i.valid && vector_b_valid && scale_b_valid;
  assign in_accept          = first_iter || obuff_result_valid;
  assign in_fire            = inputs_valid && in_accept && mxdotp_in_ready;
  assign out_fire           = mxdotp_result_valid && mxdotp_result_ready;

  assign obuff_result_ready = in_fire && !first_iter;
  assign tile_result_ready  = result_o.ready;

  assign vector_a           = in_fire ? vector_a_i.data : '0;
  assign scale_a            = in_fire ? scale_a_i.data  : '0;

  mxcore_reuse_counters #(
    .Reuse  ( Reuse )
  ) i_reuse_counters (
    .clk_i        ( clk_i       ),
    .rst_ni       ( rst_ni      ),
    .clear_i      ( clear_i     ),
    .ireuse_i     ( ireuse_i    ),
    .count_in_i   ( in_fire     ),
    .count_out_i  ( out_fire    ),
    .first_iter_o ( first_iter  ),
    .last_iter_o  ( last_iter   )
  );

  mxcore_b_buffer_ctrl #(
    .InputDataWidth   ( InputDataWidth            ),
    .OutputDataWidth  ( NPE*MXCoreVectorDataWidth ),
    .NPE              ( NPE                       ),
    .ReuseFactor      ( Reuse                     ),
    .ScaleFactor      ( 1                         )
  ) i_vector_b_buffer_ctrl (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .sbmat_lt_bw_i  ( 1'b0                  ),
    .data_valid_i   ( vectors_b_i.valid     ),
    .data_ready_o   ( vectors_b_i.ready     ),
    .data_i         ( vectors_b_i.data      ),
    .data_valid_o   ( vector_b_valid        ),
    .data_ready_i   ( in_fire               ),
    .write_enable_o ( vector_b_write_enable ),
    .write_addr_o   ( vector_b_write_addr   ),
    .write_data_o   (                       ),
    .read_addr_o    ( vector_b_read_addr    ),
    .empty_o        (                       )
  );

  mxcore_b_buffer_ctrl #(
    .InputDataWidth   ( InputDataWidth            ),
    .OutputDataWidth  ( NPE*MXCoreScaleDataWidth  ),
    .NPE              ( NPE                       ),
    .ReuseFactor      ( Reuse                     ),
    .ScaleFactor      ( ScaleFactor               )
  ) i_scale_b_buffer_ctrl (
    .clk_i          ( clk_i                 ),
    .rst_ni         ( rst_ni                ),
    .clear_i        ( clear_i               ),
    .sbmat_lt_bw_i  ( sbmat_lt_bw_i         ),
    .data_valid_i   ( scale_b_i.valid       ),
    .data_ready_o   ( scale_b_i.ready       ),
    .data_i         ( scale_b_i.data        ),
    .data_valid_o   ( scale_b_valid         ),
    .data_ready_i   ( in_fire               ),
    .write_enable_o ( scale_b_write_enable  ),
    .write_addr_o   ( scale_b_write_addr    ),
    .write_data_o   ( scale_b               ),
    .read_addr_o    ( scale_b_read_addr     ),
    .empty_o        (                       )
  );

  mxcore_output_buffer_ctrl #(
    .Reuse      ( Reuse     ),
    .AddrWidth  ( AddrWidth )
  ) i_output_buffer_ctrl (
    .clk_i                  ( clk_i                       ),
    .rst_ni                 ( rst_ni                      ),
    .clear_i                ( clear_i                     ),
    .mxdotp_result_valid_i  ( mxdotp_result_valid         ),
    .mxdotp_result_ready_o  ( mxdotp_result_ready         ),
    .last_iter_i            ( last_iter                   ),
    .obuff_result_valid_o   ( obuff_result_valid          ),
    .obuff_result_ready_i   ( obuff_result_ready          ),
    .tile_result_valid_o    ( tile_result_valid           ),
    .tile_result_ready_i    ( tile_result_ready           ),
    .write_enable_o         ( output_buffer_write_enable  ),
    .write_addr_o           ( output_buffer_write_addr    ),
    .read_addr_o            ( output_buffer_read_addr     ),
    .tile_addr_o            ( output_buffer_tile_addr     ),
    .empty_o                ( obuff_empty                 )
  );

  mxcore_pe_array #(
    .InputDataWidth ( InputDataWidth  )
  ) i_pe_array (
    .clk_i                        ( clk_i                       ),
    .rst_ni                       ( rst_ni                      ),
    .vector_a_i                   ( vector_a                    ),
    .scale_a_i                    ( scale_a                     ),
    .vectors_b_i                  ( vectors_b_i.data            ),
    .vector_b_write_enable_i      ( vector_b_write_enable       ),
    .vector_b_write_addr_i        ( vector_b_write_addr         ),
    .vector_b_read_addr_i         ( vector_b_read_addr          ),
    .scale_b_i                    ( scale_b                     ),
    .scale_b_write_enable_i       ( scale_b_write_enable        ),
    .scale_b_write_addr_i         ( scale_b_write_addr          ),
    .scale_b_read_addr_i          ( scale_b_read_addr           ),
    .output_buffer_write_enable_i ( output_buffer_write_enable  ),
    .output_buffer_write_addr_i   ( output_buffer_write_addr    ),
    .output_buffer_read_addr_i    ( output_buffer_read_addr     ),
    .output_buffer_tile_addr_i    ( output_buffer_tile_addr     ),
    .obuff_result_ready_i         ( obuff_result_ready          ),
    .rnd_mode_i                   ( rnd_mode_i                  ),
    .op_i                         ( op_i                        ),
    .op_mod_i                     ( op_mod_i                    ),
    .src_fmt_i                    ( src_fmt_i                   ),
    .int_fmt_i                    ( int_fmt_i                   ),
    .dst_fmt_i                    ( dst_fmt_i                   ),
    .in_valid_i                   ( inputs_valid && in_accept   ),
    .in_ready_o                   ( mxdotp_in_ready             ),
    .flush_i                      ( flush_i                     ),
    .tile_result_o                ( tile_result                 ),
    .out_valid_o                  ( mxdotp_result_valid         ),
    .out_ready_i                  ( mxdotp_result_ready         ),
    .busy_o                       ( mxdotp_busy                 )
  );

  assign vector_a_i.ready = in_fire;
  assign scale_a_i.ready  = in_fire;
  assign result_o.valid   = tile_result_valid;
  assign result_o.data    = tile_result;
  assign result_o.strb    = '1;
  assign busy_o           = mxdotp_busy || !obuff_empty;

endmodule: mxcore_engine
