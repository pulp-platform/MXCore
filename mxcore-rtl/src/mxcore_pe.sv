// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_pe
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
#(
  parameter int unsigned VectorBSegments  = 1,
  parameter int unsigned AddrWidth        = (Reuse > 1) ? $clog2(Reuse) : 1
) (
  // Global Signals
  input  logic                                      clk_i,
  input  logic                                      rst_ni,
  // Input Operands
  input  logic [VectorSize-1:0][SRC_WIDTH-1:0]      vector_a_i,
  input  logic [SCALE_WIDTH-1:0]                    scale_a_i,
  // Vector B Buffer
  input  logic [LaneWidth/VectorBSegments-1:0]      vector_b_i,
  input  logic [VectorBSegments-1:0]                vector_b_write_enable_i,
  input  logic                                      vector_b_write_addr_i,
  input  logic                                      vector_b_read_addr_i,
  // Scale B Buffer
  input  logic [SCALE_WIDTH-1:0]                    scale_b_i,
  input  logic                                      scale_b_write_enable_i,
  input  logic                                      scale_b_write_addr_i,
  input  logic                                      scale_b_read_addr_i,
  // Output Buffer
  input  logic                                      output_buffer_write_enable_i,
  input  logic [AddrWidth-1:0]                      output_buffer_write_addr_i,
  input  logic [AddrWidth-1:0]                      output_buffer_read_addr_i,
  input  logic [AddrWidth-1:0]                      output_buffer_tile_addr_i,
  input  logic                                      obuff_result_ready_i,
  // Input Control Signals
  input  fpnew_pkg::roundmode_e                    rnd_mode_i,
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
  output logic [DST_WIDTH-1:0]                      tile_result_o,
  // Output Handshake
  output logic                                      out_valid_o,
  input  logic                                      out_ready_i,
  // Indication of Valid Data in Flight
  output logic                                      busy_o
);

  localparam int unsigned VectorBSegmentWidth = LaneWidth / VectorBSegments;

  logic [LaneWidth-1:0]           vector_b;
  logic [SCALE_WIDTH-1:0]         scale_b;
  logic [1:0][SCALE_WIDTH-1:0]    operands_c;
  logic [DST_WIDTH-1:0]           operand_d;
  logic [DST_WIDTH-1:0]           obuff_result;
  logic [DST_WIDTH-1:0]           tile_result;
  logic [DST_WIDTH-1:0]           mxdotp_result;

  assign operands_c = {scale_b, scale_a_i};
  assign operand_d  = obuff_result_ready_i ? obuff_result : '0;

  generate
    for (genvar s = 0; s < VectorBSegments; s++) begin : gen_vector_b_buffer
      mxcore_register_file_1r_1w #(
        .ADDR_WIDTH ( 1                   ),
        .DATA_WIDTH ( VectorBSegmentWidth )
      ) i_vector_b_buffer (
        .clk          ( clk_i                                                     ),
        .ReadEnable   ( 1'b1                                                      ),
        .ReadAddr     ( vector_b_read_addr_i                                      ),
        .ReadData     ( vector_b[s*VectorBSegmentWidth+:VectorBSegmentWidth]      ),
        .WriteEnable  ( vector_b_write_enable_i[s]                                ),
        .WriteAddr    ( vector_b_write_addr_i                                     ),
        .WriteData    ( vector_b_i                                                )
      );
    end
  endgenerate

  mxcore_register_file_1r_1w #(
    .ADDR_WIDTH ( 1           ),
    .DATA_WIDTH ( SCALE_WIDTH )
  ) i_scale_b_buffer (
    .clk          ( clk_i                   ),
    .ReadEnable   ( 1'b1                    ),
    .ReadAddr     ( scale_b_read_addr_i     ),
    .ReadData     ( scale_b                 ),
    .WriteEnable  ( scale_b_write_enable_i  ),
    .WriteAddr    ( scale_b_write_addr_i    ),
    .WriteData    ( scale_b_i               )
  );

  mxcore_register_file_2r_2w #(
    .ADDR_WIDTH ( AddrWidth ),
    .DATA_WIDTH ( DST_WIDTH )
  ) i_output_buffer (
    .clk        ( clk_i                         ),
    .rst_n      ( rst_ni                        ),
    .raddr_a_i  ( output_buffer_read_addr_i     ),
    .rdata_a_o  ( obuff_result                  ),
    .raddr_b_i  ( output_buffer_tile_addr_i     ),
    .rdata_b_o  ( tile_result                   ),
    .waddr_a_i  ( output_buffer_write_addr_i    ),
    .wdata_a_i  ( mxdotp_result                 ),
    .we_a_i     ( output_buffer_write_enable_i  ),
    .waddr_b_i  ( '0                            ),
    .wdata_b_i  ( '0                            ),
    .we_b_i     ( 1'b0                          )
  );

  fpnew_mxdotp_multi #(
    .FpSrcFmtConfig   ( EnMxdotpSrcFpFmtConfig  ),
    .IntSrcFmtConfig  ( EnMxdotpSrcIntFmtConfig ),
    .FpDstFmtConfig   ( EnMxdotpDstFpFmtConfig  ),
    .LaneWidth        ( LaneWidth               ),
    .VectorSize       ( VectorSize              ),
    .NumPipeRegs      ( NumPipeRegs             ),
    .PipeConfig       ( PipeConfig              ),
    .TagType          ( TagType                 ),
    .AuxType          ( AuxType                 )
  ) i_fpnew_mxdotp_multi (
    .clk_i                 ( clk_i          ),
    .rst_ni                ( rst_ni         ),
    .operands_a_i          ( vector_a_i     ),
    .operands_b_i          ( vector_b       ),
    .operands_a_fp6_rem_i  ( '0             ),
    .operands_b_fp6_rem_i  ( '0             ),
    .operands_c_i          ( operands_c     ),
    .operand_d_i           ( operand_d      ),
    .is_boxed_i            ( '1             ),
    .rnd_mode_i            ( rnd_mode_i     ),
    .op_i                  ( op_i           ),
    .op_mod_i              ( op_mod_i       ),
    .src_fmt_i             ( src_fmt_i      ),
    .int_fmt_i             ( int_fmt_i      ),
    .dst_fmt_i             ( dst_fmt_i      ),
    .tag_i                 ( '0             ),
    .mask_i                ( 1'b0           ),
    .aux_i                 ( '0             ),
    .in_valid_i            ( in_valid_i     ),
    .in_ready_o            ( in_ready_o     ),
    .flush_i               ( flush_i        ),
    .out_valid_o           ( out_valid_o    ),
    .out_ready_i           ( out_ready_i    ),
    .result_o              ( mxdotp_result  ),
    .status_o              (                ),
    .extension_bit_o       (                ),
    .tag_o                 (                ),
    .mask_o                (                ),
    .aux_o                 (                ),
    .busy_o                ( busy_o         )
  );

  assign tile_result_o = tile_result;

endmodule : mxcore_pe
