// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_output_buffer_ctrl #(
  parameter int unsigned Reuse      = 64,
  parameter int unsigned AddrWidth  = (Reuse > 1) ? $clog2(Reuse) : 1
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
  // Handshake Signals - Partial Results from the Output Buffer to MXDOTP Array
  output logic                  obuff_result_valid_o,
  input  logic                  obuff_result_ready_i,
  // Handshake Signals - Final Tile Results from the Output Buffer to TCDM
  output logic                  tile_result_valid_o,
  input  logic                  tile_result_ready_i,
  // Output Buffer Control
  output logic                  write_enable_o,
  output logic [AddrWidth-1:0]  write_addr_o,
  output logic [AddrWidth-1:0]  read_addr_o,
  output logic [AddrWidth-1:0]  tile_addr_o,
  // Buffer Status
  output logic                  empty_o
);

  // Status Registers
  logic [Reuse-1:0]       status_d, status_q;
  logic [Reuse-1:0]       tile_status_d, tile_status_q;

  // Write Signals
  logic                   write_enable;
  logic [AddrWidth-1:0]   write_addr_d, write_addr_q;

  // Read - Port 1 Signals
  logic [AddrWidth-1:0]   read_addr_d, read_addr_q;

  // Read - Port 2 Signals
  logic [AddrWidth-1:0]   tile_addr_d, tile_addr_q;

  always_comb begin
    // Default Assignments
    status_d              = status_q;
    tile_status_d         = tile_status_q;
    write_enable          = 1'b0;
    write_addr_d          = write_addr_q;
    read_addr_d           = read_addr_q;
    tile_addr_d           = tile_addr_q;
    // Write Port
    mxdotp_result_ready_o = !status_q[write_addr_q];
    if (mxdotp_result_valid_i && mxdotp_result_ready_o) begin
      write_enable                = 1'b1;
      status_d[write_addr_q]      = 1'b1;
      tile_status_d[write_addr_q] = last_iter_i;
      write_addr_d                = (write_addr_q == Reuse-1) ? '0 : write_addr_q + 1;
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

  `FFARNC(status_q,       status_d,       clear_i, '0)
  `FFARNC(tile_status_q,  tile_status_d,  clear_i, '0)
  `FFARNC(write_addr_q,   write_addr_d,   clear_i, '0)
  `FFARNC(read_addr_q,    read_addr_d,    clear_i, '0)
  `FFARNC(tile_addr_q,    tile_addr_d,    clear_i, '0)

  assign write_enable_o = write_enable;
  assign write_addr_o   = write_addr_q;
  assign read_addr_o    = read_addr_q;
  assign tile_addr_o    = tile_addr_q;
  assign empty_o        = ~|status_q;

endmodule : mxcore_output_buffer_ctrl
