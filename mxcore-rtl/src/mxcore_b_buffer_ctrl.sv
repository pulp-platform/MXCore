// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_b_buffer_ctrl #(
  parameter int unsigned InputDataWidth   = 512,
  parameter int unsigned OutputDataWidth  = 8192,
  parameter int unsigned NPE              = 32,
  parameter int unsigned ReuseFactor      = 64,
  parameter int unsigned ScaleFactor      = 1,
  // Do not change the following parameters
  parameter int unsigned WriteDataWidth   = (OutputDataWidth < InputDataWidth) ? OutputDataWidth : InputDataWidth
) (
  // Global Signals
  input  logic                        clk_i,
  input  logic                        rst_ni,
  input  logic                        clear_i,
  // Special Cases
  input  logic                        sbmat_lt_bw_i,
  // Input Data Stream
  input  logic                        data_valid_i,
  output logic                        data_ready_o,
  input  logic [InputDataWidth-1:0]   data_i,
  // Output Data Handshake
  output logic                        data_valid_o,
  input  logic                        data_ready_i,
  // Buffer Control
  output logic [NPE-1:0]              write_enable_o,
  output logic                        write_addr_o,
  output logic [WriteDataWidth-1:0]   write_data_o,
  output logic                        read_addr_o,
  // Buffer Status
  output logic                        empty_o
);

  localparam int unsigned PeDataWidth    = OutputDataWidth / NPE;
  localparam int unsigned UnitsPerWrite  = WriteDataWidth / PeDataWidth;
  localparam int unsigned NWORDS         = (OutputDataWidth > InputDataWidth) ? (OutputDataWidth / InputDataWidth) : 1;
  localparam int unsigned POP_COUNT      = (InputDataWidth > OutputDataWidth) ? (InputDataWidth / OutputDataWidth) : 1;

  logic [1:0]                           row_full_d, row_full_q;
  logic                                 write_addr_d, write_addr_q;
  logic                                 read_addr_d, read_addr_q;
  logic [$clog2(NWORDS+1)-1:0]          push_count_d, push_count_q;
  logic [$clog2(POP_COUNT+1)-1:0]       pop_count_d, pop_count_q;
  logic [$clog2(ReuseFactor+1)-1:0]     reuse_count_d, reuse_count_q;
  logic [$clog2(ScaleFactor+1)-1:0]     scale_reuse_count_d, scale_reuse_count_q;

  logic [NPE-1:0]                       write_enable;
  logic [WriteDataWidth-1:0]            write_data;

  generate
    if (InputDataWidth > OutputDataWidth) begin : gen_slice_write_data
      assign write_data = data_i[pop_count_q*OutputDataWidth+:OutputDataWidth];
    end else begin : gen_merge_write_data
      assign write_data = data_i;
    end
  endgenerate

  always_comb begin
    row_full_d          = row_full_q;
    write_addr_d        = write_addr_q;
    read_addr_d         = read_addr_q;
    push_count_d        = push_count_q;
    pop_count_d         = pop_count_q;
    reuse_count_d       = reuse_count_q;
    scale_reuse_count_d = scale_reuse_count_q;
    write_enable        = '0;
    data_ready_o        = 1'b0;
    // SLICE Mode - One Input Word Fills POP_COUNT Buffer Rows
    if (InputDataWidth > OutputDataWidth) begin
      if (data_valid_i && !row_full_q[write_addr_q]) begin
        write_enable              = '1;
        row_full_d[write_addr_q]  = 1'b1;
        write_addr_d              = !write_addr_q;
        if ((pop_count_q == POP_COUNT - 1) || sbmat_lt_bw_i) begin
          pop_count_d   = '0;
          data_ready_o  = 1'b1;
        end else begin
          pop_count_d   = pop_count_q + 1;
        end
      end
    // MERGE Mode - NWORDS Input Words Fill One Buffer Row
    end else begin
      data_ready_o  = !row_full_q[write_addr_q];
      if (data_valid_i && data_ready_o) begin
        write_enable[push_count_q*UnitsPerWrite+:UnitsPerWrite] = '1;
        if (push_count_q == NWORDS - 1) begin
          push_count_d              = '0;
          row_full_d[write_addr_q]  = 1'b1;
          write_addr_d              = !write_addr_q;
        end else begin
          push_count_d              = push_count_q + 1;
        end
      end
    end
    // Read - Release a Row after ReuseFactor x ScaleFactor Consumptions
    if (data_valid_o && data_ready_i) begin
      if (reuse_count_q == ReuseFactor - 1) begin
        reuse_count_d = '0;
        if (scale_reuse_count_q == ScaleFactor - 1) begin
          scale_reuse_count_d     = '0;
          row_full_d[read_addr_q] = 1'b0;
          read_addr_d             = !read_addr_q;
        end else begin
          scale_reuse_count_d     = scale_reuse_count_q + 1;
        end
      end else begin
        reuse_count_d = reuse_count_q + 1;
      end
    end
  end

  `FFARNC(row_full_q,          row_full_d,          clear_i, '0)
  `FFARNC(write_addr_q,        write_addr_d,        clear_i, '0)
  `FFARNC(read_addr_q,         read_addr_d,         clear_i, '0)
  `FFARNC(push_count_q,        push_count_d,        clear_i, '0)
  `FFARNC(pop_count_q,         pop_count_d,         clear_i, '0)
  `FFARNC(reuse_count_q,       reuse_count_d,       clear_i, '0)
  `FFARNC(scale_reuse_count_q, scale_reuse_count_d, clear_i, '0)

  assign data_valid_o   = row_full_q[read_addr_q];
  assign write_enable_o = write_enable;
  assign write_addr_o   = write_addr_q;
  assign write_data_o   = write_data;
  assign read_addr_o    = read_addr_d;
  assign empty_o        = ~|row_full_q;

endmodule : mxcore_b_buffer_ctrl
