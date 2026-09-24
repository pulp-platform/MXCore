// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_global_output_buffer
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
#(
  parameter int unsigned NPE    = 32,
  parameter int unsigned Reuse  = 64
) (
  // Global Signals
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic                    clear_i,
  // Handshake Signals - Result Data from MXDOTP Array
  input  logic                    mxdotp_result_valid_i,
  output logic                    mxdotp_result_ready_o,
  // Data In
  input  [NPE-1:0][DST_WIDTH-1:0] mxdotp_result_i,
  // Last Iteration Signal - Written Result is a Final Tile Result
  input  logic                    last_iter_i,
  // Accumulator Preload
  input  logic                    preload_i,
  input  logic                    tile_end_i,
  input  logic                    preload_bias_valid_i,
  output logic                    preload_bias_ready_o,
  input  [NPE-1:0][DST_WIDTH-1:0] preload_bias_i,
  output logic                    preload_done_o,
  // Handshake Signals - Partial Results from the Output Buffer to MXDOTP Array
  output logic                    obuff_result_valid_o,
  input  logic                    obuff_result_ready_i,
  // Data Out - Partial Results - READ PORT 1
  output [NPE-1:0][DST_WIDTH-1:0] obuff_result_o,
  // Handshake Signals - Final Tile Results from the Output Buffer to TCDM
  output logic                    tile_result_valid_o,
  input  logic                    tile_result_ready_i,
  // Data Out - Final Tile Results - READ PORT 2
  output [NPE-1:0][DST_WIDTH-1:0] tile_result_o,
  // Buffer Status
  output logic                    empty_o
);

  localparam int unsigned AddrWidth = (Reuse > 1) ? $clog2(Reuse) : 1;

  // Status Registers
  logic [Reuse-1:0]               status_d, status_q;
  logic [Reuse-1:0]               tile_status_d, tile_status_q;

  // Write Signals
  logic                           write_enable;
  logic [AddrWidth-1:0]           write_addr_d, write_addr_q;

  // Read - Port 1 Signals
  logic                           read_enable;
  logic [AddrWidth-1:0]           read_addr_d, read_addr_q;

  // Read - Port 2 Signals
  logic                           tile_read_enable;
  logic [AddrWidth-1:0]           tile_addr_d, tile_addr_q;

  logic [NPE-1:0][DST_WIDTH-1:0]  read_data [Reuse];

  // Preload Signals
  logic [$clog2(Reuse+1)-1:0]     preload_count_d, preload_count_q;
  logic                           preload_phase, write_free, write_fire;
  logic [NPE-1:0][DST_WIDTH-1:0]  write_data;

  always_comb begin
    // Default Assignments
    status_d              = status_q;
    tile_status_d         = tile_status_q;
    write_enable          = 1'b0;
    read_enable           = 1'b0;
    tile_read_enable      = 1'b0;
    write_addr_d          = write_addr_q;
    read_addr_d           = read_addr_q;
    tile_addr_d           = tile_addr_q;
    preload_count_d       = preload_count_q;
    // Write Port
    preload_phase        = preload_i && (preload_count_q < Reuse);
    write_free            = !status_q[write_addr_q];
    preload_bias_ready_o  = preload_phase && write_free;
    mxdotp_result_ready_o = !preload_phase && write_free;
    write_fire            = write_free && (preload_phase ? preload_bias_valid_i : mxdotp_result_valid_i);
    write_data            = preload_phase ? preload_bias_i : mxdotp_result_i;
    if (write_fire) begin
      write_enable                = 1'b1;
      status_d[write_addr_q]      = 1'b1;
      tile_status_d[write_addr_q] = preload_phase ? 1'b0 : last_iter_i;
      write_addr_d                = (write_addr_q == Reuse-1) ? '0 : write_addr_q + 1;
      if (preload_phase) begin
        preload_count_d = preload_count_q + 1;
      end
    end
    if (tile_end_i) begin
      preload_count_d = '0;
    end
    // Read - Port 1 - Partial Results
    obuff_result_valid_o = status_q[read_addr_q] && !tile_status_q[read_addr_q];
    if (obuff_result_valid_o && obuff_result_ready_i) begin
      read_enable           = 1'b1;
      status_d[read_addr_q] = 1'b0;
      read_addr_d           = (read_addr_q == Reuse-1) ? '0 : read_addr_q + 1;
    end
    // Read - Port 2 - Final Tile Results
    tile_result_valid_o = tile_status_q[tile_addr_q];
    if (tile_result_valid_o && tile_result_ready_i) begin
      tile_read_enable            = 1'b1;
      status_d[tile_addr_q]       = 1'b0;
      tile_status_d[tile_addr_q]  = 1'b0;
      tile_addr_d                 = (tile_addr_q == Reuse-1) ? '0 : tile_addr_q + 1;
    end
  end

  `FFARNC(status_q,        status_d,        clear_i, '0)
  `FFARNC(tile_status_q,   tile_status_d,   clear_i, '0)
  `FFARNC(write_addr_q,    write_addr_d,    clear_i, '0)
  `FFARNC(read_addr_q,     read_addr_d,     clear_i, '0)
  `FFARNC(tile_addr_q,     tile_addr_d,     clear_i, '0)
  `FFARNC(preload_count_q, preload_count_d, clear_i, '0)

  generate
    for (genvar i = 0; i < Reuse; i++) begin : output_buffer_array
      mxcore_register_file_1r_1w_1row #(
        .DATA_WIDTH ( NPE*DST_WIDTH  )
      ) bram_cut (
        .clk          ( clk_i                               ),
        .ReadEnable   ( read_enable || tile_read_enable     ),
        .ReadData     ( read_data[i]                        ),
        .WriteEnable  ( write_enable && (write_addr_q == i) ),
        .WriteData    ( write_data                          )
      );
    end
  endgenerate

  assign obuff_result_o = read_data [read_addr_q];
  assign tile_result_o  = read_data [tile_addr_q];
  assign empty_o        = ~|status_q;
  assign preload_done_o = preload_i && (preload_count_q == Reuse);

endmodule : mxcore_global_output_buffer
