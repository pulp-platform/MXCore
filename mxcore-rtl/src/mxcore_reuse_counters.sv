// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_reuse_counters
#(
  parameter int unsigned  Reuse = 64
) (
  // Global Signals
  input  logic          clk_i,
  input  logic          rst_ni,
  input  logic          clear_i,
  // Per-Output-Tile Input Reuse Count
  input  logic [15:0]   ireuse_i,
  // Count Enable Signals
  input  logic          count_in_i,
  input  logic          count_out_i,
  // Iteration Status Signals
  output logic          first_iter_o,
  output logic          last_iter_o
);

  logic [15:0] in_count_d, in_count_q;
  logic [15:0] out_count_d, out_count_q;

  always_comb begin
    in_count_d  = in_count_q;
    out_count_d = out_count_q;
    // Input Reuse Count
    if (count_in_i) begin
      in_count_d = (in_count_q == ireuse_i - 1) ? '0 : in_count_q + 1;
    end
    // Output Reuse Count
    if (count_out_i) begin
      out_count_d = (out_count_q == ireuse_i - 1) ? '0 : out_count_q + 1;
    end
  end

  `FFARNC(in_count_q,  in_count_d,  clear_i, '0)
  `FFARNC(out_count_q, out_count_d, clear_i, '0)

  // First iteration: No Partial Results
  assign first_iter_o = (in_count_q < Reuse);
  // Last iteration: Final Tile Results
  assign last_iter_o  = (out_count_q + Reuse >= ireuse_i);

endmodule : mxcore_reuse_counters
