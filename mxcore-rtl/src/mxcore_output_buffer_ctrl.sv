// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_output_buffer_ctrl #(
  parameter int unsigned Reuse            = 64,
  parameter int unsigned NPE              = 32,
  parameter int unsigned PeDataWidth      = 32,
  parameter int unsigned InputDataWidth   = 512,
  parameter int unsigned PreloadThreshold = Reuse / 2,
  // Do not change the following parameters
  parameter int unsigned AddrWidth        = (Reuse > 1) ? $clog2(Reuse) : 1
) (
  // Global Signals
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  clear_i,
  // Handshake Signals - Result Data from MXDOTP Array
  input  logic                  mxdotp_result_valid_i,
  output logic                  mxdotp_result_ready_o,
  // Last Iteration Signal - Written Result is a Final Tile Result
  input  logic                  last_iter_i,
  // Accumulator Preload
  input  logic                  preload_i,
  input  logic                  tile_end_i,
  input  logic                  preload_bias_valid_i,
  output logic                  preload_bias_ready_o,
  output logic                  preload_ready_o,
  // Handshake Signals - Partial Results from the Output Buffer to MXDOTP Array
  output logic                  obuff_result_valid_o,
  input  logic                  obuff_result_ready_i,
  // Handshake Signals - Final Tile Results from the Output Buffer to TCDM
  output logic                  tile_result_valid_o,
  input  logic                  tile_result_ready_i,
  // Output Buffer Control
  output logic                  write_enable_o,
  output logic [AddrWidth-1:0]  write_addr_o,
  output logic [NPE-1:0]        bias_write_enable_o,
  output logic [AddrWidth-1:0]  bias_write_addr_o,
  output logic [AddrWidth-1:0]  read_addr_o,
  output logic [AddrWidth-1:0]  tile_addr_o,
  // Buffer Status
  output logic                  empty_o
);

  localparam int unsigned BiasRowWidth    = NPE * PeDataWidth;
  localparam int unsigned BiasWords       = (BiasRowWidth > InputDataWidth) ? (BiasRowWidth / InputDataWidth) : 1;
  localparam int unsigned UnitsPerWrite   = ((BiasRowWidth < InputDataWidth) ? BiasRowWidth : InputDataWidth) / PeDataWidth;
  localparam int unsigned BiasWordWidth   = (BiasWords > 1) ? $clog2(BiasWords) : 1;

  if (BiasRowWidth < InputDataWidth) begin : gen_bias_width_check
    $fatal(1, "mxcore_output_buffer_ctrl: NPE*PeDataWidth (%0d) must be >= InputDataWidth (%0d)", BiasRowWidth, InputDataWidth);
  end

  // Status Registers
  logic [Reuse-1:0]               status_d, status_q;
  logic [Reuse-1:0]               tile_status_d, tile_status_q;

  // Write Signals
  logic                           write_enable;
  logic [AddrWidth-1:0]           write_addr_d, write_addr_q;

  // Preload Write Signals
  logic [NPE-1:0]                 bias_write_enable;
  logic                           bias_allowed, bias_row_open;
  logic [AddrWidth-1:0]           bias_addr_d, bias_addr_q;
  logic [BiasWordWidth-1:0]       bias_word_d, bias_word_q;

  // Read - Port 1 Signals
  logic [AddrWidth-1:0]           read_addr_d, read_addr_q;

  // Read - Port 2 Signals
  logic [AddrWidth-1:0]           tile_addr_d, tile_addr_q;

  // Preload Counters
  logic [$clog2(2*Reuse+1)-1:0]   preload_count_d, preload_count_q;
  logic [$clog2(Reuse+1)-1:0]     final_count_d, final_count_q;

  assign bias_row_open = (bias_word_q != '0);

  always_comb begin
    // Default Assignments
    status_d              = status_q;
    tile_status_d         = tile_status_q;
    write_enable          = 1'b0;
    bias_write_enable     = '0;
    write_addr_d          = write_addr_q;
    bias_addr_d           = bias_addr_q;
    bias_word_d           = bias_word_q;
    read_addr_d           = read_addr_q;
    tile_addr_d           = tile_addr_q;
    preload_count_d       = preload_count_q;
    final_count_d         = final_count_q;
    // Write Port - MXDOTP Results
    mxdotp_result_ready_o = !status_q[write_addr_q] && !(bias_row_open && (write_addr_q == bias_addr_q));
    if (mxdotp_result_valid_i && mxdotp_result_ready_o) begin
      write_enable                = 1'b1;
      status_d[write_addr_q]      = 1'b1;
      tile_status_d[write_addr_q] = last_iter_i;
      write_addr_d                = (write_addr_q == Reuse-1) ? '0 : write_addr_q + 1;
      if (last_iter_i) begin
        final_count_d = final_count_q + 1;
      end
    end
    // Write Port - Preload Bias Rows (BiasWords Input Words per Row)
    bias_allowed          = preload_count_q < (Reuse + final_count_q);
    preload_bias_ready_o  = preload_i && (bias_allowed || bias_row_open) && !status_q[bias_addr_q];
    if (preload_bias_valid_i && preload_bias_ready_o) begin
      bias_write_enable[bias_word_q*UnitsPerWrite+:UnitsPerWrite] = '1;
      if (bias_word_q == BiasWords-1) begin
        bias_word_d                 = '0;
        status_d[bias_addr_q]       = 1'b1;
        tile_status_d[bias_addr_q]  = 1'b0;
        bias_addr_d                 = (bias_addr_q == Reuse-1) ? '0 : bias_addr_q + 1;
        preload_count_d             = preload_count_d + 1;
      end else begin
        bias_word_d                 = bias_word_q + 1;
      end
    end
    if (tile_end_i) begin
      final_count_d = '0;
      if (preload_i) begin
        preload_count_d = preload_count_d - Reuse;
      end
    end
    // Read - Port 1 - Partial Results
    obuff_result_valid_o = status_q[read_addr_q] && !tile_status_q[read_addr_q];
    if (obuff_result_valid_o && obuff_result_ready_i) begin
      status_d[read_addr_q] = 1'b0;
      read_addr_d           = (read_addr_q == Reuse-1) ? '0 : read_addr_q + 1;
    end
    // Read - Port 2 - Final Tile Results
    tile_result_valid_o = tile_status_q[tile_addr_q];
    if (tile_result_valid_o && tile_result_ready_i) begin
      status_d[tile_addr_q]       = 1'b0;
      tile_status_d[tile_addr_q]  = 1'b0;
      tile_addr_d                 = (tile_addr_q == Reuse-1) ? '0 : tile_addr_q + 1;
    end
  end

  `FFARNC(status_q,        status_d,        clear_i, '0)
  `FFARNC(tile_status_q,   tile_status_d,   clear_i, '0)
  `FFARNC(write_addr_q,    write_addr_d,    clear_i, '0)
  `FFARNC(bias_addr_q,     bias_addr_d,     clear_i, '0)
  `FFARNC(bias_word_q,     bias_word_d,     clear_i, '0)
  `FFARNC(read_addr_q,     read_addr_d,     clear_i, '0)
  `FFARNC(tile_addr_q,     tile_addr_d,     clear_i, '0)
  `FFARNC(preload_count_q, preload_count_d, clear_i, '0)
  `FFARNC(final_count_q,   final_count_d,   clear_i, '0)

  assign write_enable_o       = write_enable;
  assign write_addr_o         = write_addr_q;
  assign bias_write_enable_o  = bias_write_enable;
  assign bias_write_addr_o    = bias_addr_q;
  assign read_addr_o          = read_addr_q;
  assign tile_addr_o          = tile_addr_q;
  assign empty_o              = ~|status_q;
  assign preload_ready_o      = preload_i && (preload_count_q >= PreloadThreshold);

endmodule : mxcore_output_buffer_ctrl
