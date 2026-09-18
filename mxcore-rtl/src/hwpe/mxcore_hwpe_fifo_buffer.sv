// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_fifo_buffer #(
  parameter int unsigned InputDataWidth      = 32,
  parameter int unsigned OutputDataWidth     = 32,
  parameter int unsigned FifoDepth           = 8,
  parameter int unsigned LatchFifo           = 1,
  parameter int unsigned LatchFifoTestWrap   = 0
) (
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Data
  hwpe_stream_intf_stream.sink      data_i,
  hwpe_stream_intf_stream.source    data_o
);

  hwpe_stream_intf_stream #(
    .DATA_WIDTH(InputDataWidth)
  ) data_fifo (
    .clk ( clk_i    )
  );

  localparam int unsigned ReuseFactor  = InputDataWidth / OutputDataWidth;

  logic [$clog2(ReuseFactor)-1:0]  reuse_cnt_d, reuse_cnt_q;

  always_comb begin
    // Default Assignments
    reuse_cnt_d     = reuse_cnt_q;
    data_o.data     = data_fifo.data[(reuse_cnt_q)*OutputDataWidth+:OutputDataWidth];
    data_o.strb     = data_fifo.strb[(reuse_cnt_q)*OutputDataWidth/8+:OutputDataWidth/8];
    data_o.valid    = data_fifo.valid;
    data_fifo.ready = (reuse_cnt_q == ReuseFactor - 1) ? data_o.ready : 0;
    if (data_o.ready && data_fifo.valid) begin
      reuse_cnt_d = reuse_cnt_q + 1;
      if (reuse_cnt_q == ReuseFactor - 1) begin
          reuse_cnt_d = '0;
      end
    end
  end

  `FFARNC(reuse_cnt_q, reuse_cnt_d, clear_i, '0)

  hwpe_stream_fifo #(
    .DATA_WIDTH (InputDataWidth),
    .FIFO_DEPTH (FifoDepth),
    .LATCH_FIFO (LatchFifo),
    .LATCH_FIFO_TEST_WRAP (LatchFifoTestWrap)
  ) i_data_fifo (
    .clk_i      ( clk_i     ),
    .rst_ni     ( rst_ni    ),
    .clear_i    ( clear_i   ),
    .flags_o    (           ),
    .push_i     ( data_i    ),
    .pop_o      ( data_fifo )
  );

endmodule : mxcore_hwpe_fifo_buffer