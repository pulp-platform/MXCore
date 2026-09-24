// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_engine
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
(
  // Global Signals
  input  logic                                          clk_i,
  input  logic                                          rst_ni,
  input  logic                                          clear_i,
  // Input signals
  input  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0] operands_a_i,
  input  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0] operands_b_i,
  input  logic [NPE-1:0][1:0]                           operands_a_fp6_rem_i,
  input  logic [NPE-1:0][1:0]                           operands_b_fp6_rem_i,
  input  logic [NPE-1:0][1:0][SCALE_WIDTH-1:0]          operands_c_i,
  input  logic [NPE-1:0][DST_WIDTH-1:0]                 operand_d_i,
  hwpe_stream_intf_stream.sink                          preload_bias_i,
  // Input Control/Configuration Signals
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
  input  logic [15:0]                                   ireuse_i,
  input  logic                                          preload_i,
  input  logic                                          compute_en_i,
  // Input Handshake Signals
  input  logic [NPE-1:0]                                in_valid_i,
  output logic [NPE-1:0]                                in_ready_o,
  input  logic                                          flush_i,
  // Output Signals
  output logic [NPE-1:0][DST_WIDTH-1:0]                 result_o,
  // Output Control/Configuration Signals
  output fpnew_pkg::status_t [NPE-1:0]                  status_o,
  output logic [NPE-1:0]                                extension_bit_o,
  output TagType                                        tag_o,
  output logic                                          mask_o,
  output AuxType                                        aux_o,
  // Output Handshake Signals
  output logic [NPE-1:0]                                out_valid_o,
  input  logic [NPE-1:0]                                out_ready_i,
  // Preload Status Signals
  output logic                                          preload_done_o,
  output logic                                          tile_end_o,
  // Indication of valid data in flight
  output logic                                          busy_o
);

  // MXDOTP Array Signals
  logic [NPE-1:0]                                 mxdotp_in_valid, mxdotp_in_ready;
  logic [NPE-1:0]                                 mxdotp_result_valid;
  logic                                           mxdotp_result_ready;
  logic [NPE-1:0][DST_WIDTH-1:0]                  mxdotp_result;
  logic                                           mxdotp_busy;

  // Output Buffer Signals
  logic                                           obuff_result_valid, obuff_result_ready;
  logic                                           tile_result_valid, tile_result_ready;
  logic [NPE-1:0][DST_WIDTH-1:0]                  obuff_result;
  logic [NPE-1:0][DST_WIDTH-1:0]                  tile_result;
  logic                                           obuff_empty;

  // Input Multiplexing
  logic [NPE-1:0][VectorSize-1:0][SRC_WIDTH-1:0]  operands_a, operands_b;
  logic [NPE-1:0][1:0]                            operands_a_fp6_rem, operands_b_fp6_rem;
  logic [NPE-1:0][1:0][SCALE_WIDTH-1:0]           operands_c;
  logic [NPE-1:0][DST_WIDTH-1:0]                  operand_d;

  // Iteration Status Signals
  logic first_iter, last_iter, tile_end;
  logic in_accept, in_fire, out_fire;

  // Inputs after the first iteration also need their partial result from the output buffer
  assign in_accept        = (first_iter && !preload_i) || (obuff_result_valid && compute_en_i);
  assign mxdotp_in_valid  = in_valid_i & {NPE{in_accept}};
  assign in_ready_o       = mxdotp_in_ready & {NPE{in_accept}};
  assign in_fire          = (&in_valid_i) && (&in_ready_o);
  assign out_fire         = (&mxdotp_result_valid) && mxdotp_result_ready;

  assign obuff_result_ready = in_fire && (!first_iter || preload_i);
  assign tile_result_ready  = &out_ready_i;

  always_comb begin
    operands_a          = '0;
    operands_b          = '0;
    operands_a_fp6_rem  = '0;
    operands_b_fp6_rem  = '0;
    operands_c          = '0;
    operand_d           = '0;
    if (in_fire) begin
      operands_a          = operands_a_i;
      operands_b          = operands_b_i;
      operands_a_fp6_rem  = operands_a_fp6_rem_i;
      operands_b_fp6_rem  = operands_b_fp6_rem_i;
      operands_c          = operands_c_i;
      if (!first_iter || preload_i) begin
        operand_d         = obuff_result;
      end
    end
  end

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
    .last_iter_o  ( last_iter   ),
    .tile_end_o   ( tile_end    )
  );

  // MXDOTP Array
  mxcore_mxdotp_array i_mxdotp_array (
    .clk_i                ( clk_i                       ),
    .rst_ni               ( rst_ni                      ),
    .operands_a_i         ( operands_a                  ),
    .operands_b_i         ( operands_b                  ),
    .operands_a_fp6_rem_i ( operands_a_fp6_rem          ),
    .operands_b_fp6_rem_i ( operands_b_fp6_rem          ),
    .operands_c_i         ( operands_c                  ),
    .operand_d_i          ( operand_d                   ),
    .is_boxed_i           ( is_boxed_i                  ),
    .rnd_mode_i           ( rnd_mode_i                  ),
    .op_i                 ( op_i                        ),
    .op_mod_i             ( op_mod_i                    ),
    .src_fmt_i            ( src_fmt_i                   ),
    .int_fmt_i            ( int_fmt_i                   ),
    .dst_fmt_i            ( dst_fmt_i                   ),
    .tag_i                ( tag_i                       ),
    .mask_i               ( mask_i                      ),
    .aux_i                ( aux_i                       ),
    .in_valid_i           ( mxdotp_in_valid             ),
    .in_ready_o           ( mxdotp_in_ready             ),
    .flush_i              ( flush_i                     ),
    .result_o             ( mxdotp_result               ),
    .status_o             ( status_o                    ),
    .extension_bit_o      ( extension_bit_o             ),
    .tag_o                ( tag_o                       ),
    .mask_o               ( mask_o                      ),
    .aux_o                ( aux_o                       ),
    .out_valid_o          ( mxdotp_result_valid         ),
    .out_ready_i          ( {NPE{mxdotp_result_ready}}  ),
    .busy_o               ( mxdotp_busy                 )
  );

  mxcore_global_output_buffer #(
    .NPE    ( NPE   ),
    .Reuse  ( Reuse )
  ) i_global_output_buffer (
    .clk_i                    ( clk_i                 ),
    .rst_ni                   ( rst_ni                ),
    .clear_i                  ( clear_i               ),
    .mxdotp_result_valid_i    ( &mxdotp_result_valid  ),
    .mxdotp_result_ready_o    ( mxdotp_result_ready   ),
    .mxdotp_result_i          ( mxdotp_result         ),
    .last_iter_i              ( last_iter             ),
    .preload_i                ( preload_i             ),
    .tile_end_i               ( tile_end              ),
    .preload_bias_valid_i     ( preload_bias_i.valid  ),
    .preload_bias_ready_o     ( preload_bias_i.ready  ),
    .preload_bias_i           ( preload_bias_i.data   ),
    .preload_done_o           ( preload_done_o        ),
    .obuff_result_valid_o     ( obuff_result_valid    ),
    .obuff_result_ready_i     ( obuff_result_ready    ),
    .obuff_result_o           ( obuff_result          ),
    .tile_result_valid_o      ( tile_result_valid     ),
    .tile_result_ready_i      ( tile_result_ready     ),
    .tile_result_o            ( tile_result           ),
    .empty_o                  ( obuff_empty           )
  );

  assign out_valid_o  = {NPE{tile_result_valid}};
  assign result_o     = tile_result;
  assign tile_end_o   = tile_end;
  assign busy_o       = mxdotp_busy || !obuff_empty;

endmodule: mxcore_engine
