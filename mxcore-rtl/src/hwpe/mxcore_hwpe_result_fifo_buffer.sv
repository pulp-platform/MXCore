// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_result_fifo_buffer #(
  parameter int unsigned InputDataWidth      = 512,
  parameter int unsigned NFifo               = 1,   // Number of FIFOs in the Array (MERGE Mode)
  parameter int unsigned PopCount            = 1    // Number of Pops per Input (SLICE Mode)
) (
  // Global Signals
  input logic                       clk_i,
  input logic                       rst_ni,
  input logic                       clear_i,
  // Data Streams
  hwpe_stream_intf_stream.sink      data_i,
  hwpe_stream_intf_stream.source    data_o
);

  hwpe_stream_intf_stream #( .DATA_WIDTH (InputDataWidth) ) push_fifo   [NFifo] ( .clk ( clk_i  ) );  // PUSH Stream FIFO
  hwpe_stream_intf_stream #( .DATA_WIDTH (InputDataWidth) ) pop_fifo    [NFifo] ( .clk ( clk_i  ) );  // POP Stream FIFO

  // FIFO Input (PUSH) Stream
  logic [NFifo-1:0]                          push_fifo_valid;
  logic [NFifo-1:0]                          push_fifo_ready;
  logic [NFifo-1:0][InputDataWidth-1:0]      push_fifo_data;
  logic [NFifo-1:0][InputDataWidth/8-1:0]    push_fifo_strb;
  // FIFO Output (POP) Stream
  logic [NFifo-1:0]                          pop_fifo_valid;
  logic [NFifo-1:0]                          pop_fifo_ready;
  logic [NFifo-1:0][InputDataWidth-1:0]      pop_fifo_data;
  logic [NFifo-1:0][InputDataWidth/8-1:0]    pop_fifo_strb;

  generate
    // PUSH Stream Bindings
    for (genvar i = 0; i < NFifo; i++) begin : push_fifo_binding
      assign push_fifo[i].valid = push_fifo_valid[i];
      assign push_fifo_ready[i] = push_fifo[i].ready;
      assign push_fifo[i].data  = push_fifo_data[i];
      assign push_fifo[i].strb  = push_fifo_strb[i];
    end
    // POP Stream Bindings
    for (genvar i = 0; i < NFifo; i++) begin : pop_fifo_binding
      assign pop_fifo_valid[i] = pop_fifo[i].valid;
      assign pop_fifo[i].ready = pop_fifo_ready[i];
      assign pop_fifo_data[i]  = pop_fifo[i].data;
      assign pop_fifo_strb[i]  = pop_fifo[i].strb;
    end
  endgenerate

  logic [1:0]                           push_count_d, push_count_q;
  logic [1:0]                           pop_count_d, pop_count_q;

  always_comb begin
    push_count_d        = push_count_q;
    pop_count_d         = pop_count_q;
    data_o.valid        = 1'b0;
    data_o.data         = '0;
    data_o.strb         = '0;
    push_fifo_valid     = '0;
    push_fifo_data      = {NFifo{data_i.data}};
    push_fifo_strb      = {NFifo{{(InputDataWidth/8){1'b1}}}};
    pop_fifo_ready      = '0;
    data_i.ready        = (PopCount > 1) ? push_fifo_ready[0] : push_fifo_ready[push_count_q];
    // SLICE Mode - Single FIFO - Pop Partial Data for PopCount times
    if (PopCount > 1) begin
      push_fifo_valid[0]  = data_i.valid;
      data_o.valid        = pop_fifo_valid[0];
      data_o.data         = pop_fifo_data[0][pop_count_q*512+:512];
      data_o.strb         = pop_fifo_strb[0][pop_count_q*64+:64];
      pop_fifo_ready[0]   = 1'b0;
      if (data_o.ready && pop_fifo_valid[0]) begin
        if (pop_count_q == PopCount - 1) begin
          pop_count_d       = '0;
          pop_fifo_ready[0] = 1'b1;
        end else begin
          pop_count_d = pop_count_q + 1;
        end
      end
    // SLICE MODE - END
    // MERGE Mode - FIFO Array - Accumulate and Pop merged data
    end else begin
      if (data_i.valid && push_fifo_ready[push_count_q]) begin
        push_fifo_valid[push_count_q] = 1'b1;
        if (push_count_q == NFifo - 1) begin
          push_count_d  = '0;
        end else begin
          push_count_d  = push_count_q + 1;
        end
      end
      data_o.valid  = &pop_fifo_valid;
      data_o.data   = pop_fifo_data;
      data_o.strb   = pop_fifo_strb;
      if (&pop_fifo_valid && data_o.ready) begin
        pop_fifo_ready  = '1;
      end
    end
    // MERGE MODE - END
  end

  `FFARNC(push_count_q, push_count_d, clear_i, '0)
  `FFARNC(pop_count_q,  pop_count_d,  clear_i, '0)

  generate
    for (genvar i = 0; i < NFifo; i++) begin : fifo_array
      hwpe_stream_fifo #(
        .DATA_WIDTH           ( InputDataWidth  ),
        .FIFO_DEPTH           ( 2               ),
        .LATCH_FIFO           ( 1               ),
        .LATCH_FIFO_TEST_WRAP ( 0               )
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

endmodule : mxcore_hwpe_result_fifo_buffer