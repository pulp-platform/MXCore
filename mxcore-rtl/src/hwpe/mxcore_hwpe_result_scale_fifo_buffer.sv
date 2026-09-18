// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_result_scale_fifo_buffer #(
  parameter int unsigned InputDataWidth      = 8,
  parameter int unsigned OutputDataWidth     = 512,
  parameter int unsigned FifoDepth           = 8,
  parameter int unsigned LatchFifo           = 1,
  parameter int unsigned LatchFifoTestWrap   = 0
) (
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Data
  input logic                       engine_result_ready_i,
  input logic [31:0]                tot_pushes_i,
  hwpe_stream_intf_stream.sink      data_i,
  hwpe_stream_intf_stream.source    data_o
);

  localparam int unsigned NFIFO = (OutputDataWidth > InputDataWidth) ? (OutputDataWidth / InputDataWidth) : 1;

  hwpe_stream_intf_stream #( .DATA_WIDTH (InputDataWidth) ) push_fifo   [NFIFO] ( .clk ( clk_i  ) );  // PUSH Stream FIFO
  hwpe_stream_intf_stream #( .DATA_WIDTH (InputDataWidth) ) pop_fifo    [NFIFO] ( .clk ( clk_i  ) );  // POP Stream FIFO

  // FIFO Input (PUSH) Stream
  logic [NFIFO-1:0]                          push_fifo_valid;
  logic [NFIFO-1:0]                          push_fifo_ready;
  logic [NFIFO-1:0][InputDataWidth-1:0]    push_fifo_data;
  logic [NFIFO-1:0][InputDataWidth/8-1:0]  push_fifo_strb;
  // FIFO Output (POP) Stream
  logic [NFIFO-1:0]                          pop_fifo_valid;
  logic [NFIFO-1:0]                          pop_fifo_ready;
  logic [NFIFO-1:0][InputDataWidth-1:0]    pop_fifo_data;
  logic [NFIFO-1:0][InputDataWidth/8-1:0]  pop_fifo_strb;

  generate
    // PUSH Stream Bindings
    for (genvar i = 0; i < NFIFO; i++) begin : push_fifo_binding
      assign push_fifo[i].valid = push_fifo_valid[i];
      assign push_fifo_ready[i] = push_fifo[i].ready;
      assign push_fifo[i].data  = push_fifo_data[i];
      assign push_fifo[i].strb  = push_fifo_strb[i];
    end
    // POP Stream Bindings
    for (genvar i = 0; i < NFIFO; i++) begin : pop_fifo_binding
      assign pop_fifo_valid[i] = pop_fifo[i].valid;
      assign pop_fifo[i].ready = pop_fifo_ready[i];
      assign pop_fifo_data[i]  = pop_fifo[i].data;
      assign pop_fifo_strb[i]  = pop_fifo[i].strb;
    end
  endgenerate

  logic [$clog2(NFIFO+1)-1:0]           push_count_d, push_count_q;
  logic [31:0]                          push_total_d, push_total_q;
  logic                                 flush_pending;
  logic [NFIFO-1:0]                     lane_active;
  logic [NFIFO-1:0][InputDataWidth/8-1:0] pop_fifo_strb_masked;

  assign flush_pending = (push_total_q == tot_pushes_i) && (push_count_q != '0);

  generate
    for (genvar i = 0; i < NFIFO; i++) begin : lane_mask_binding
      assign lane_active[i]          = flush_pending ? (i < push_count_q) : 1'b1;
      assign pop_fifo_strb_masked[i] = lane_active[i] ? pop_fifo_strb[i] : '0;
    end
  endgenerate

  always_comb begin
    // Default Assignments
    push_count_d        = push_count_q;
    push_total_d        = push_total_q;
    push_fifo_valid     = '0;
    push_fifo_data      = {NFIFO{data_i.data}};
    push_fifo_strb      = {NFIFO{data_i.strb}};
    pop_fifo_ready      = '0;
    data_i.ready        = push_fifo_ready[push_count_q] && engine_result_ready_i;
    if (data_i.valid && data_i.ready) begin
      push_fifo_valid[push_count_q] = 1'b1;
      push_count_d = (push_count_q == NFIFO-1) ? '0 : push_count_q + 1;
      push_total_d = push_total_q + 1;
    end

    data_o.valid        = flush_pending ? &(pop_fifo_valid | ~lane_active) : &pop_fifo_valid;
    data_o.data         = pop_fifo_data;
    data_o.strb         = pop_fifo_strb_masked;
    if (data_o.valid && data_o.ready) begin
      pop_fifo_ready  = lane_active;
      push_total_d    = flush_pending ? '0 : push_total_d;
    end
  end

  `FFARNC(push_count_q, push_count_d, clear_i, '0)
  `FFARNC(push_total_q, push_total_d, clear_i, '0)

  generate
    for (genvar i = 0; i < NFIFO; i++) begin : fifo_array
      hwpe_stream_fifo #(
        .DATA_WIDTH           ( InputDataWidth      ),
        .FIFO_DEPTH           ( FifoDepth            ),
        .LATCH_FIFO           ( LatchFifo            ),
        .LATCH_FIFO_TEST_WRAP ( LatchFifoTestWrap  )
      ) i_fifo (
        .clk_i      ( clk_i         ),
        .rst_ni     ( rst_ni        ),
        .clear_i    ( clear_i        ),
        .flags_o    (               ),
        .push_i     ( push_fifo[i]  ),
        .pop_o      ( pop_fifo[i]   )
      );
    end
  endgenerate

endmodule : mxcore_hwpe_result_scale_fifo_buffer