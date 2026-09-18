// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_mxdotp_array
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
(
  // Global Signals
  input  logic                                          clk_i,
  input  logic                                          rst_ni,
  // Input Signals
  // // Input Operands
  input  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0] operands_a_i,
  input  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0] operands_b_i,
  input  logic [NPE-1:0][1:0]                           operands_a_fp6_rem_i,
  input  logic [NPE-1:0][1:0]                           operands_b_fp6_rem_i,
  input  logic [NPE-1:0][1:0][SCALE_WIDTH-1:0]          operands_c_i,
  input  logic [NPE-1:0][DST_WIDTH-1:0]                 operand_d_i,
  // // Input Control Signals
  input  logic [NUM_FORMATS-1:0][NumOperands-1:0]      is_boxed_i,
  input  fpnew_pkg::roundmode_e                         rnd_mode_i,
  input  fpnew_pkg::operation_e                         op_i,
  input  logic                                          op_mod_i,
  input  fpnew_pkg::fp_format_e                         src_fmt_i,
  input  fpnew_pkg::int_format_e                        int_fmt_i,
  input  fpnew_pkg::fp_format_e                         dst_fmt_i,
  input  TagType                                        tag_i,
  input  logic                                          mask_i,
  input  AuxType                                        aux_i,
  // Input Handshake
  input  logic [NPE-1:0]                                in_valid_i,
  output logic [NPE-1:0]                                in_ready_o,
  input  logic                                          flush_i,
  // Output Signal
  output logic [NPE-1:0][DST_WIDTH-1:0]                 result_o,
  output fpnew_pkg::status_t [NPE-1:0]                  status_o,
  output logic [NPE-1:0]                                extension_bit_o,
  output TagType                                        tag_o,
  output logic                                          mask_o,
  output AuxType                                        aux_o,
  // Output Handshake
  output logic    [NPE-1:0]                             out_valid_o,
  input  logic    [NPE-1:0]                             out_ready_i,
  // Indication of Valid Data in Flight
  output logic                                          busy_o
);

  TagType [NPE-1:0]    out_tag_array;
  logic   [NPE-1:0]    out_mask_array;
  AuxType [NPE-1:0]    out_aux_array;
  logic   [NPE-1:0]    busy_array;

  generate
    for (genvar i = 0; i < NPE; i++) begin : mxdotp_array
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
        .clk_i                 ( clk_i                    ),
        .rst_ni                ( rst_ni                   ),
        .operands_a_i          ( operands_a_i[i]          ),
        .operands_b_i          ( operands_b_i[i]          ),
        .operands_a_fp6_rem_i  ( operands_a_fp6_rem_i[i]  ),
        .operands_b_fp6_rem_i  ( operands_b_fp6_rem_i[i]  ),
        .operands_c_i          ( operands_c_i[i]          ),
        .operand_d_i           ( operand_d_i[i]           ),
        .is_boxed_i            ( is_boxed_i               ),
        .rnd_mode_i            ( rnd_mode_i               ),
        .op_i                  ( op_i                     ),
        .op_mod_i              ( op_mod_i                 ),
        .src_fmt_i             ( src_fmt_i                ),
        .int_fmt_i             ( int_fmt_i                ),
        .dst_fmt_i             ( dst_fmt_i                ),
        .tag_i                 ( tag_i                    ),
        .mask_i                ( mask_i                   ),
        .aux_i                 ( aux_i                    ),
        .in_valid_i            ( in_valid_i[i]            ),
        .in_ready_o            ( in_ready_o[i]            ),
        .flush_i               ( flush_i                  ),
        .out_valid_o           ( out_valid_o[i]           ),
        .out_ready_i           ( out_ready_i[i]           ),
        .result_o              ( result_o[i]              ),
        .status_o              ( status_o[i]              ),
        .extension_bit_o       ( extension_bit_o[i]       ),
        .tag_o                 ( out_tag_array[i]         ),
        .mask_o                ( out_mask_array[i]        ),
        .aux_o                 ( out_aux_array[i]         ),
        .busy_o                ( busy_array[i]            )
      );
    end
  endgenerate

  assign tag_o  = |out_tag_array;
  assign mask_o = |out_mask_array;
  assign aux_o  = |out_aux_array;
  assign busy_o = |busy_array;

endmodule : mxcore_mxdotp_array