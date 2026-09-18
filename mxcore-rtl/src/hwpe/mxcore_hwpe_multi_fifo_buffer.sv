// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_multi_fifo_buffer #(
  parameter int unsigned InputDataWidth      = 512,
  parameter int unsigned OutputDataWidth     = 8192,
  parameter int unsigned ReuseFactor         = 64,
  parameter int unsigned FifoDepth           = 8,
  parameter int unsigned LatchFifo           = 1,
  parameter int unsigned LatchFifoTestWrap   = 0
) (
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Data Streams
  hwpe_stream_intf_stream.sink      data_i,
  hwpe_stream_intf_stream.source    data_o
);

  localparam int unsigned NFIFO       = (OutputDataWidth > InputDataWidth) ? (OutputDataWidth / InputDataWidth) : 1;  // Number of FIFOs in the Array
  localparam int unsigned POP_COUNT   = (InputDataWidth > OutputDataWidth) ? (InputDataWidth / OutputDataWidth) : 1;  // Number of Pops per Output in SLICE Mode

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
  logic [$clog2(POP_COUNT+1)-1:0]       pop_count_d, pop_count_q;
  logic [$clog2(ReuseFactor+1)-1:0]    reuse_count_d, reuse_count_q;

  always_comb begin
    push_count_d        = push_count_q;
    pop_count_d         = pop_count_q;
    reuse_count_d       = reuse_count_q;
    data_o.valid        = 1'b0;
    data_o.data         = '0;
    data_o.strb         = '0;
    push_fifo_valid     = '0;
    push_fifo_data      = {NFIFO{data_i.data}};
    push_fifo_strb      = {NFIFO{{(InputDataWidth/8){1'b1}}}};
    pop_fifo_ready      = '0;
    data_i.ready        = (InputDataWidth > OutputDataWidth) ? push_fifo_ready[0] : push_fifo_ready[push_count_q];
    // SLICE Mode - Single FIFO - Pop Partial Data for POP_COUNT times
    if (InputDataWidth > OutputDataWidth) begin
      push_fifo_valid[0]  = data_i.valid;
      data_o.valid        = pop_fifo_valid[0];
      data_o.data         = pop_fifo_data[0][(pop_count_q)*OutputDataWidth+:OutputDataWidth];
      data_o.strb         = pop_fifo_strb[0][(pop_count_q)*OutputDataWidth/8+:OutputDataWidth/8];
      pop_fifo_ready[0]   = 1'b0;
      if (data_o.ready && pop_fifo_valid[0]) begin
        if (reuse_count_q == ReuseFactor - 1) begin
          reuse_count_d = '0;
          if (pop_count_q == POP_COUNT - 1) begin
            pop_count_d       = '0;
            pop_fifo_ready[0] = 1'b1;
          end else begin
            pop_count_d = pop_count_q + 1;
          end
        end else begin
          reuse_count_d = reuse_count_q + 1;
        end
      end
    // SLICE MODE - END
    // MERGE Mode - FIFO Array - Accumulate and Pop merged data
    end else begin
      if (data_i.valid && push_fifo_ready[push_count_q]) begin
        push_fifo_valid[push_count_q] = 1'b1;
        if (push_count_q == NFIFO - 1) begin
          push_count_d  = '0;
        end else begin
          push_count_d  = push_count_q + 1;
        end
      end
      data_o.valid  = &pop_fifo_valid;
      data_o.data   = pop_fifo_data;
      data_o.strb   = pop_fifo_strb;
      if (&pop_fifo_valid && data_o.ready) begin
        if (reuse_count_q == ReuseFactor - 1) begin
          reuse_count_d   = '0;
          pop_fifo_ready  = '1;
        end else begin
          reuse_count_d   = reuse_count_q + 1;
          pop_fifo_ready  = '0;
        end
      end
    end
    // MERGE MODE - END
  end

  `FFARNC(push_count_q,  push_count_d,  clear_i, '0)
  `FFARNC(pop_count_q,   pop_count_d,   clear_i, '0)
  `FFARNC(reuse_count_q, reuse_count_d, clear_i, '0)

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

endmodule : mxcore_hwpe_multi_fifo_buffer