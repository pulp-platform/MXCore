// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_fifo_buffer (
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Data
  hwpe_stream_intf_stream.sink      data_i,
  hwpe_stream_intf_stream.source    data_o
);

  hwpe_stream_intf_stream #(
    .DATA_WIDTH(512)
  ) data_fifo (
    .clk ( clk_i    )
  );

  logic reuse_cnt_d, reuse_cnt_q;

  always_comb begin
    // Default Assignments
    reuse_cnt_d     = reuse_cnt_q;
    data_o.data     = data_fifo.data[reuse_cnt_q*256+:256];
    data_o.strb     = data_fifo.strb[reuse_cnt_q*32+:32];
    data_o.valid    = data_fifo.valid;
    data_fifo.ready = reuse_cnt_q ? data_o.ready : 1'b0;
    if (data_o.ready && data_fifo.valid) begin
      reuse_cnt_d = !reuse_cnt_q;
    end
  end

  `FFARNC(reuse_cnt_q, reuse_cnt_d, clear_i, '0)

  hwpe_stream_fifo #(
    .DATA_WIDTH           ( 512 ),
    .FIFO_DEPTH           ( 2   ),
    .LATCH_FIFO           ( 1   ),
    .LATCH_FIFO_TEST_WRAP ( 0   )
  ) i_data_fifo (
    .clk_i      ( clk_i     ),
    .rst_ni     ( rst_ni    ),
    .clear_i    ( clear_i   ),
    .flags_o    (           ),
    .push_i     ( data_i    ),
    .pop_o      ( data_fifo )
  );

endmodule : mxcore_hwpe_fifo_buffer