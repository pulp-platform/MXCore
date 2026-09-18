// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_fifo_scale_buffer
  import fpnew_mxdotp_multi_pkg::*;
#(
  parameter int unsigned InputDataWidth      = 512,
  parameter int unsigned OutputDataWidth     = 8,
  parameter int unsigned ReuseFactor         = 32,
  parameter int unsigned ScaleFactor         = 4,
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

  localparam int unsigned FIFO_FACTOR   = InputDataWidth / OutputDataWidth;
  localparam int unsigned SCALE_COUNT   = (ReuseFactor * SCALE_WIDTH > InputDataWidth) ? 1 : ScaleFactor;

  localparam int unsigned SCALE_BLOCK_WIDTH = ReuseFactor * OutputDataWidth;
  localparam int unsigned NBLOCKS           = (FIFO_FACTOR >= ReuseFactor) ? (FIFO_FACTOR / ReuseFactor) : 1;

  logic [$clog2(ReuseFactor)-1:0]  reuse_cnt_d, reuse_cnt_q;
  logic [$clog2(SCALE_COUNT)-1:0]   scale_reuse_cnt_d, scale_reuse_cnt_q;
  logic [$clog2(NBLOCKS)-1:0]       block_count_d, block_count_q;

  logic [$clog2(NBLOCKS)-1:0]       block_idx;
  logic [$clog2(FIFO_FACTOR)-1:0]   scale_idx;

  assign block_idx  = block_count_q;
  assign scale_idx  = (ReuseFactor > FIFO_FACTOR) ? (reuse_cnt_q % FIFO_FACTOR) : (block_idx*ReuseFactor + reuse_cnt_q);

  always_comb begin
    // Default Assignments
    reuse_cnt_d       = reuse_cnt_q;
    scale_reuse_cnt_d = scale_reuse_cnt_q;
    block_count_d     = block_count_q;
    data_o.data       = data_fifo.data[(scale_idx*OutputDataWidth)+:OutputDataWidth];
    data_o.strb       = data_fifo.strb[(scale_idx*OutputDataWidth/8)+:OutputDataWidth/8];
    data_o.valid      = data_fifo.valid;
    data_fifo.ready   = 1'b0;
    if (data_o.ready && data_fifo.valid) begin
      if (reuse_cnt_q == ReuseFactor - 1) begin
        reuse_cnt_d = '0;
        if (scale_reuse_cnt_q == SCALE_COUNT - 1) begin
          scale_reuse_cnt_d = '0;
          if (FIFO_FACTOR > ReuseFactor) begin
            if (block_count_q == NBLOCKS - 1) begin
              block_count_d     = '0;
              data_fifo.ready   = 1'b1;
            end else begin
              block_count_d = block_count_q + 1;
            end
          end else begin
            if (((reuse_cnt_q + 1) % FIFO_FACTOR) == 0) begin
              data_fifo.ready = 1'b1;
            end
          end
        end else begin
          scale_reuse_cnt_d = scale_reuse_cnt_q + 1;
        end
      end else begin
        reuse_cnt_d = reuse_cnt_q + 1;
        if ((ReuseFactor > FIFO_FACTOR) && (((reuse_cnt_q + 1) % FIFO_FACTOR) == 0)) begin
          data_fifo.ready = 1'b1;
        end
      end
    end
  end

  `FFARNC(reuse_cnt_q,       reuse_cnt_d,       clear_i, '0)
  `FFARNC(scale_reuse_cnt_q, scale_reuse_cnt_d, clear_i, '0)
  `FFARNC(block_count_q,     block_count_d,     clear_i, '0)

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

endmodule : mxcore_hwpe_fifo_scale_buffer