// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_pe_array
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
#(
  parameter int unsigned InputDataWidth       = 512,
  // Do not change the following parameters
  parameter int unsigned ScaleBDataWidth      = (NPE*MXCoreScaleDataWidth < InputDataWidth) ? (NPE*MXCoreScaleDataWidth) : InputDataWidth,
  parameter int unsigned BiasDataWidth        = (NPE*DST_WIDTH < InputDataWidth) ? (NPE*DST_WIDTH) : InputDataWidth
) (
  // Global Signals
  input  logic                                      clk_i,
  input  logic                                      rst_ni,
  // Input Operands
  input  logic [MXCoreVectorDataWidth-1:0]          vector_a_i,
  input  logic [MXCoreScaleDataWidth-1:0]           scale_a_i,
  // Vector B Buffers
  input  logic [InputDataWidth-1:0]                 vectors_b_i,
  input  logic [NPE-1:0]                            vector_b_write_enable_i,
  input  logic                                      vector_b_write_addr_i,
  input  logic                                      vector_b_read_addr_i,
  // Scale B Buffers
  input  logic [ScaleBDataWidth-1:0]                scale_b_i,
  input  logic [NPE-1:0]                            scale_b_write_enable_i,
  input  logic                                      scale_b_write_addr_i,
  input  logic                                      scale_b_read_addr_i,
  // Output Buffers
  input  logic                                      output_buffer_write_enable_i,
  input  logic [GOBAddrWidth-1:0]                   output_buffer_write_addr_i,
  input  logic [BiasDataWidth-1:0]                  preload_bias_i,
  input  logic [NPE-1:0]                            bias_write_enable_i,
  input  logic [GOBAddrWidth-1:0]                   bias_write_addr_i,
  input  logic [GOBAddrWidth-1:0]                   output_buffer_read_addr_i,
  input  logic [GOBAddrWidth-1:0]                   output_buffer_tile_addr_i,
  input  logic                                      obuff_result_ready_i,
  // Input Control Signals
  input  fpnew_pkg::roundmode_e                     rnd_mode_i,
  input  fpnew_pkg::operation_e                     op_i,
  input  logic                                      op_mod_i,
  input  fpnew_pkg::fp_format_e                     src_fmt_i,
  input  fpnew_pkg::int_format_e                    int_fmt_i,
  input  fpnew_pkg::fp_format_e                     dst_fmt_i,
  // Input Handshake
  input  logic                                      in_valid_i,
  output logic                                      in_ready_o,
  input  logic                                      flush_i,
  // Output Signals
  output logic [NPE-1:0][DST_WIDTH-1:0]             tile_result_o,
  // Output Handshake
  output logic                                      out_valid_o,
  input  logic                                      out_ready_i,
  // Indication of Valid Data in Flight
  output logic                                      busy_o
);

  localparam int unsigned VectorsBPerWrite  = InputDataWidth / MXCoreVectorDataWidth;
  localparam int unsigned ScalesBPerWrite   = ScaleBDataWidth / MXCoreScaleDataWidth;
  localparam int unsigned BiasesPerWrite    = BiasDataWidth / DST_WIDTH;

  logic [NPE-1:0]                 pe_in_ready;
  logic [NPE-1:0]                 pe_out_valid;
  logic [NPE-1:0]                 pe_busy;
  logic [NPE-1:0][DST_WIDTH-1:0]  tile_result;

  generate
    for (genvar pe = 0; pe < NPE; pe++) begin : gen_mxcore_pe
      mxcore_pe i_mxcore_pe (
        .clk_i                        ( clk_i                                                                           ),
        .rst_ni                       ( rst_ni                                                                          ),
        .vector_a_i                   ( vector_a_i                                                                      ),
        .scale_a_i                    ( scale_a_i                                                                       ),
        .vector_b_i                   ( vectors_b_i[(pe%VectorsBPerWrite)*MXCoreVectorDataWidth+:MXCoreVectorDataWidth] ),
        .vector_b_write_enable_i      ( vector_b_write_enable_i[pe]                                                     ),
        .vector_b_write_addr_i        ( vector_b_write_addr_i                                                           ),
        .vector_b_read_addr_i         ( vector_b_read_addr_i                                                            ),
        .scale_b_i                    ( scale_b_i[(pe%ScalesBPerWrite)*MXCoreScaleDataWidth+:MXCoreScaleDataWidth]      ),
        .scale_b_write_enable_i       ( scale_b_write_enable_i[pe]                                                      ),
        .scale_b_write_addr_i         ( scale_b_write_addr_i                                                            ),
        .scale_b_read_addr_i          ( scale_b_read_addr_i                                                             ),
        .output_buffer_write_enable_i ( output_buffer_write_enable_i                                                    ),
        .output_buffer_write_addr_i   ( output_buffer_write_addr_i                                                      ),
        .preload_bias_i               ( preload_bias_i[(pe%BiasesPerWrite)*DST_WIDTH+:DST_WIDTH]                        ),
        .bias_write_enable_i          ( bias_write_enable_i[pe]                                                         ),
        .bias_write_addr_i            ( bias_write_addr_i                                                               ),
        .output_buffer_read_addr_i    ( output_buffer_read_addr_i                                                       ),
        .output_buffer_tile_addr_i    ( output_buffer_tile_addr_i                                                       ),
        .obuff_result_ready_i         ( obuff_result_ready_i                                                            ),
        .rnd_mode_i                   ( rnd_mode_i                                                                      ),
        .op_i                         ( op_i                                                                            ),
        .op_mod_i                     ( op_mod_i                                                                        ),
        .src_fmt_i                    ( src_fmt_i                                                                       ),
        .int_fmt_i                    ( int_fmt_i                                                                       ),
        .dst_fmt_i                    ( dst_fmt_i                                                                       ),
        .in_valid_i                   ( in_valid_i                                                                      ),
        .in_ready_o                   ( pe_in_ready[pe]                                                                 ),
        .flush_i                      ( flush_i                                                                         ),
        .tile_result_o                ( tile_result[pe]                                                                 ),
        .out_valid_o                  ( pe_out_valid[pe]                                                                ),
        .out_ready_i                  ( out_ready_i                                                                     ),
        .busy_o                       ( pe_busy[pe]                                                                     )
      );
    end
  endgenerate

  assign in_ready_o     = &pe_in_ready;
  assign out_valid_o    = &pe_out_valid;
  assign busy_o         = |pe_busy;
  assign tile_result_o  = tile_result;

endmodule : mxcore_pe_array
