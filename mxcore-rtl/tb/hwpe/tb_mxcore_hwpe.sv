// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "hci_helpers.svh"

import fpnew_pkg::*;
import fpnew_mxdotp_multi_pkg::*;
import mxcore_package::*;
import mxcore_hwpe_package::*;
import hci_package::*;
import hwpe_stream_package::*;

module tb_mxcore_hwpe;
  timeunit 10ps;
  timeprecision 1ps;

  localparam time     CLK_PERIOD      = 2000ps;
  localparam time     APPL_DELAY      = 400ps;
  localparam time     ACQ_DELAY       = 1600ps;
  localparam unsigned RST_CLK_CYCLES  = 10;

  // Simulation Inputs
  string memory_file  = `MEM_FILE;
  string result_file  = `RES_FILE;

  // MXCore Parameters
  localparam int unsigned VECTOR_SIZE  = `ifdef VECTOR_SIZE `VECTOR_SIZE `else 32 `endif;
  localparam int unsigned NPE          = `ifdef NPE `NPE `else 32 `endif;
  localparam int unsigned REUSE        = `ifdef REUSE `REUSE `else 64 `endif;

  localparam int unsigned MX_BLOCK_SIZE = 32;

  parameter bit QuantizeOutput = `ifdef QUANTIZE_OUTPUT `QUANTIZE_OUTPUT `else 1 `endif;

  // HWPE Parameters
  parameter real ProbStall = `ifdef NO_STALLS ((`NO_STALLS == 1) ? 0 : 0.1) `else 0.1 `endif;

  localparam unsigned MXCORE_REG_OFFSET = 32'h20;

  parameter int unsigned AccDataWidth   = MXCoreTCDMDataWidth;
  parameter int unsigned IdWidth        = 3;

  // System Parameters
  parameter int unsigned MemDataWidth   = 32;
  parameter int unsigned MP             = (AccDataWidth / MemDataWidth);

  // Input Parameters
  localparam int unsigned MDIM    = `ifdef M `M `else 128 `endif;
  localparam int unsigned KDIM    = `ifdef K `K `else 128 `endif;
  localparam int unsigned NDIM    = `ifdef N `N `else 128 `endif;

  fpnew_pkg::fp_format_e SRC_FMT  = (`SRC_FMT == "FP8") ? fpnew_pkg::FP8 :
                                    (`SRC_FMT == "FP8ALT") ? fpnew_pkg::FP8ALT :
                                    (`SRC_FMT == "FP6") ? fpnew_pkg::FP6 :
                                    (`SRC_FMT == "FP6ALT") ? fpnew_pkg::FP6ALT :
                                    (`SRC_FMT == "FP4") ? fpnew_pkg::FP4 :
                                    fpnew_pkg::FP8;

  fpnew_pkg::fp_format_e DST_FMT  = (`DST_FMT == "FP32") ? fpnew_pkg::FP32 :
                                    (`DST_FMT == "BF16") ? fpnew_pkg::FP16ALT :
                                    fpnew_pkg::FP32;

  localparam int unsigned SRC_WIDTH   = fpnew_pkg::max_fp_width(MxdotpSrcFpFmtConfig);
  localparam int unsigned DST_WIDTH   = fpnew_pkg::max_fp_width(MxdotpDstFpFmtConfig);
  localparam int unsigned SCALE_WIDTH = 8;

  localparam int unsigned FP4_SRC_WIDTH   = 4;
  localparam int unsigned FP4_BLOCK_SIZE  = 2 * MX_BLOCK_SIZE;

  // Matrix Size Parameters (in Bits)
  localparam int unsigned MAT_A_SIZE            = (`SRC_FMT == "FP4") ? MDIM*KDIM*FP4_SRC_WIDTH : MDIM*KDIM*SRC_WIDTH;
  localparam int unsigned MAT_B_SIZE            = (`SRC_FMT == "FP4") ? KDIM*NDIM*FP4_SRC_WIDTH : KDIM*NDIM*SRC_WIDTH;
  localparam int unsigned NUM_SCALE_BLOCKS_K    = (`SRC_FMT == "FP4") ? ((KDIM + FP4_BLOCK_SIZE - 1) / FP4_BLOCK_SIZE) : ((KDIM + MX_BLOCK_SIZE - 1) / MX_BLOCK_SIZE);
  localparam int unsigned MAT_SCALE_A_SIZE      = MDIM*NUM_SCALE_BLOCKS_K*SCALE_WIDTH;
  localparam int unsigned MAT_SCALE_B_SIZE      = NDIM*NUM_SCALE_BLOCKS_K*SCALE_WIDTH;
  localparam int unsigned MAT_RESULT_SIZE       = (QuantizeOutput == 1) ? (MDIM*NDIM*SRC_WIDTH) : (MDIM*NDIM*DST_WIDTH);
  localparam int unsigned MAT_RESULT_SCALE_SIZE = MDIM*NDIM*SCALE_WIDTH/MX_BLOCK_SIZE;

  // Data Memory Size
  localparam int unsigned GEMM_SIZE_FP32        = ((MAT_A_SIZE + MAT_B_SIZE + MAT_SCALE_A_SIZE + MAT_SCALE_B_SIZE + MDIM*NDIM*DST_WIDTH) / 8);
  localparam int unsigned GEMM_SIZE_MXFP8       = ((MAT_A_SIZE + MAT_B_SIZE + MAT_SCALE_A_SIZE + MAT_SCALE_B_SIZE + MDIM*NDIM*SRC_WIDTH + MDIM*NDIM*SCALE_WIDTH/MX_BLOCK_SIZE) / 8);

  parameter MemorySize   = (QuantizeOutput == 1) ? GEMM_SIZE_MXFP8 : GEMM_SIZE_FP32;

  // Input/Output Base Address Pointers
  integer       BASE_PTR[6];
  logic [31:0]  BASE_PTR_VECTOR_A;
  logic [31:0]  BASE_PTR_VECTORS_B;
  logic [31:0]  BASE_PTR_SCALE_A;
  logic [31:0]  BASE_PTR_SCALE_B;
  logic [31:0]  BASE_PTR_RESULT;
  logic [31:0]  BASE_PTR_RESULT_SCALE;

  // Signals
  logic clk, rst_n;
  logic [NumCores-1:0][1:0]  evt;
  logic busy;

  logic [MP-1:0]                        tcdm_req;
  logic [MP-1:0]                        tcdm_gnt;
  logic [MP-1:0][MemDataWidth-1:0]      tcdm_add;
  logic [MP-1:0]                        tcdm_wen;
  logic [MP-1:0][(MemDataWidth/8)-1:0]  tcdm_be;
  logic [MP-1:0][MemDataWidth-1:0]      tcdm_data;
  logic [MP-1:0][MemDataWidth-1:0]      tcdm_r_data;
  logic [MP-1:0]                        tcdm_r_valid;
  logic [MP-1:0]                        tcdm_r_ready;

  hwpe_ctrl_intf_periph #(
    .ID_WIDTH  (IdWidth)
  ) periph (
    .clk (clk)
  );

  localparam hci_size_parameter_t `HCI_SIZE_PARAM(tcdm_mem) = '{
    DW:  MXCoreTCDMDataWidth,
    AW:  DEFAULT_AW,
    BW:  DEFAULT_BW,
    UW:  DEFAULT_UW,
    IW:  DEFAULT_IW,
    EW:  DEFAULT_EW,
    EHW: DEFAULT_EHW
  };
  `HCI_INTF_ARRAY(tcdm_mem, clk_i, MP-1:0);

  initial begin
    $timeformat(-9, 1, " ns", 11);

    BASE_PTR[0] = 0;
    BASE_PTR[1] = BASE_PTR[0] + MAT_A_SIZE/8;
    BASE_PTR[2] = BASE_PTR[1] + MAT_B_SIZE/8;
    BASE_PTR[3] = BASE_PTR[2] + MAT_SCALE_A_SIZE/8;
    BASE_PTR[4] = BASE_PTR[3] + MAT_SCALE_B_SIZE/8;
    BASE_PTR[5] = BASE_PTR[4] + MAT_RESULT_SIZE/8;

    // Base Pointers
    BASE_PTR_VECTOR_A     = BASE_PTR[0];
    BASE_PTR_VECTORS_B    = BASE_PTR[1];
    BASE_PTR_SCALE_A      = BASE_PTR[2];
    BASE_PTR_SCALE_B      = BASE_PTR[3];
    BASE_PTR_RESULT       = BASE_PTR[4];
    BASE_PTR_RESULT_SCALE = BASE_PTR[5];
  end

  generate
    for (genvar ii=0; ii<MP; ii++) begin : tcdm_binding
      assign tcdm_mem[ii].req  = tcdm_req[ii];
      assign tcdm_mem[ii].add  = tcdm_add[ii];
      assign tcdm_mem[ii].wen  = tcdm_wen[ii];
      assign tcdm_mem[ii].be   = tcdm_be[ii];
      assign tcdm_mem[ii].data = tcdm_data[ii];
      assign tcdm_gnt[ii] = tcdm_mem[ii].gnt;
      assign tcdm_r_valid[ii] = tcdm_mem[ii].r_valid;
      assign tcdm_r_data[ii] = tcdm_mem[ii].r_data;
      // Default Values -> Check if needed
      assign tcdm_mem[ii].user = '0;
      assign tcdm_mem[ii].id = '0;
      assign tcdm_mem[ii].ecc = '0;
      assign tcdm_mem[ii].ereq = '0;
      assign tcdm_mem[ii].r_ready = 1'b1;
      assign tcdm_mem[ii].r_eready = 1'b1;
    end : tcdm_binding
  endgenerate

  clk_rst_gen #(
    .CLK_PERIOD     (CLK_PERIOD    ),
    .RST_CLK_CYCLES (RST_CLK_CYCLES)
  ) i_clk_rst_gen (
    .clk_o (clk  ),
    .rst_no(rst_n)
  );

  // Instantiate the DUT
  mxcore_hwpe_wrap #(
    .AccDataWidth   ( MXCoreTCDMDataWidth  ),
    .IdWidth        ( IdWidth         ),
    .MemDataWidth   ( MemDataWidth    )
  ) dut (
    .clk_i              ( clk             ),
    .rst_ni             ( rst_n           ),
    .test_mode_i        ( 1'b0            ),
    .evt_o              ( evt             ),
    .busy_o             ( busy            ),

    .tcdm_req_o         ( tcdm_req        ),
    .tcdm_add_o         ( tcdm_add        ),
    .tcdm_wen_o         ( tcdm_wen        ),
    .tcdm_be_o          ( tcdm_be         ),
    .tcdm_data_o        ( tcdm_data       ),
    .tcdm_gnt_i         ( tcdm_gnt        ),
    .tcdm_r_data_i      ( tcdm_r_data     ),
    .tcdm_r_valid_i     ( tcdm_r_valid    ),

    .periph_req_i       ( periph.req      ),
    .periph_gnt_o       ( periph.gnt      ),
    .periph_add_i       ( periph.add      ),
    .periph_wen_i       ( periph.wen      ),
    .periph_be_i        ( periph.be       ),
    .periph_data_i      ( periph.data     ),
    .periph_id_i        ( periph.id       ),
    .periph_r_data_o    ( periph.r_data   ),
    .periph_r_valid_o   ( periph.r_valid  ),
    .periph_r_id_o      ( periph.r_id     )
  );

  tb_dummy_memory #(
    .MP             ( MP            ),
    .MEMORY_SIZE    ( MemorySize    ),
    .BASE_ADDR      ( 32'h0         ),
    .PROB_STALL     ( ProbStall     ),
    .TCP            ( CLK_PERIOD    ),
    .TA             ( APPL_DELAY    ),
    .TT             ( ACQ_DELAY     )
  ) i_data_memory (
    .clk_i        ( clk       ),
    .enable_i     ( 1'b1      ),
    .stallable_i  ( 1'b1      ),
    .tcdm         ( tcdm_mem  )
  );

  function automatic integer open_stim_file(string filename);
    integer stim_fd;
    if (filename == "")
      return 0;
    stim_fd = $fopen(filename, "r");
    if (stim_fd == 0) begin
      $fatal(1, "[TB] MXCORE: Could not open %s stimuli file!", filename);
    end
    return stim_fd;
  endfunction

  initial begin
    logic [31:0] status;
    $timeformat(-9, 2, " ns", 10);

    // Wait for Reset to be released
    wait (rst_n);

    // Load Memory
    $readmemh(memory_file, tb_mxcore_hwpe.i_data_memory.memory);

    // Soft Clear
    PERIPH_WRITE(32'h14, 32'h0, 32'h0, clk);

    // Acquire Job
    status = -1;
    while(status < 32'h00)
      PERIPH_READ(32'h04, 32'h0, status, clk);

    // MXCORE Compute
    mxcore_compute(MDIM, KDIM, NDIM, fpnew_pkg::RNE, fpnew_pkg::SDOTP, 0, SRC_FMT, DST_FMT, '0, '0, '0, 0, QuantizeOutput, clk);

    // Wait for Finish
    wait(evt);

    // Soft Clear
    PERIPH_WRITE(32'h14, 32'h0, 32'h0, clk);

    #(10ns);

    compare_output(result_file, BASE_PTR[4]);

    // Finish the Simulation
    $finish;
  end

  task automatic mxcore_compute(
    input logic [31:0]              MDIM,
    input logic [31:0]              KDIM,
    input logic [31:0]              NDIM,
    input fpnew_pkg::roundmode_e    rnd_mode,
    input fpnew_pkg::operation_e    op,
    input logic                     op_mod,
    input fpnew_pkg::fp_format_e    src_fmt,
    input fpnew_pkg::fp_format_e    dst_fmt,
    input TagType                   tag,
    input logic                     mask,
    input AuxType                   aux,
    input logic                     flush,
    input logic                     quantize,
    ref   logic                     clk_i
  );
    logic [31:0] ctrl_engine_val;
    logic [31:0] vector_a_base_ptr      = BASE_PTR_VECTOR_A;
    logic [31:0] vectors_b_base_ptr     = BASE_PTR_VECTORS_B;
    logic [31:0] scale_a_base_ptr       = BASE_PTR_SCALE_A;
    logic [31:0] scale_b_base_ptr       = BASE_PTR_SCALE_B;
    logic [31:0] result_base_ptr        = BASE_PTR_RESULT;
    logic [31:0] result_scale_base_ptr  = BASE_PTR_RESULT_SCALE;

    //  Get the Engine Control Value
    ctrl_engine_val_compute(rnd_mode, op, op_mod, src_fmt, dst_fmt, tag, mask, aux, flush, quantize, ctrl_engine_val);
    $display(" - MXCore Engine Control Register: 0x%0h", ctrl_engine_val);

    // Program MXCore
    PROGRAM_MXCORE(vector_a_base_ptr, vectors_b_base_ptr, scale_a_base_ptr, scale_b_base_ptr, result_base_ptr, result_scale_base_ptr, ctrl_engine_val, MDIM, KDIM, NDIM, clk_i);

    // Wait for MXCore to finish
    @(posedge clk_i);
    wait(busy == 1'b0);
    // Trigger MXCore
    PERIPH_WRITE( 32'h0, 32'h0, 32'h0, clk_i );

    #(10ns);
  endtask

  task automatic ctrl_engine_val_compute(
    input  fpnew_pkg::roundmode_e   rnd_mode,
    input  fpnew_pkg::operation_e   op,
    input  logic                    op_mod,
    input  fpnew_pkg::fp_format_e   src_fmt,
    input  fpnew_pkg::fp_format_e   dst_fmt,
    input  TagType                  tag,
    input  logic                    mask,
    input  AuxType                  aux,
    input  logic                    flush,
    input  logic                    quantize,
    output logic [31:0]             ctrl_engine_val
  );
    ctrl_engine_val[31:22]  = '0;
    ctrl_engine_val[21]     = quantize;
    ctrl_engine_val[20:17]  = {flush, aux, mask, tag};
    ctrl_engine_val[16:13]  = dst_fmt;
    ctrl_engine_val[12:9]   = src_fmt;
    ctrl_engine_val[8]      = op_mod;
    ctrl_engine_val[7:3]    = op;
    ctrl_engine_val[2:0]    = rnd_mode;
  endtask

  function automatic bit is_signed_zero_byte(input logic [7:0] exp_byte, input logic [7:0] got_byte);
    return (exp_byte[6:0] == 7'h00) && (got_byte[6:0] == 7'h00) && (exp_byte[7] != got_byte[7]);
  endfunction

  function automatic bit is_signed_zero_word(input logic [31:0] exp_word, input logic [31:0] got_word);
    bit result;
    result = 1'b1;
    for (int b = 0; b < 4; b++) begin
      if (exp_word[b*8+:8] !== got_word[b*8+:8]) begin
        if (!is_signed_zero_byte(exp_word[b*8+:8], got_word[b*8+:8])) begin
          result = 1'b0;
        end
      end
    end
    return result;
  endfunction

  task automatic compare_output(string STIM_DATA, integer address);
    integer stim_fd;
    integer ret_code;
    integer counter;
    integer line_num;
    integer exp_res;
    integer err_cnt;
    integer signed_zero_cnt;

    $display("Comparing Output for %s @ 0x%0h @ %0t", STIM_DATA, address, $time);

    stim_fd = open_stim_file(STIM_DATA);

    // Warning: Make sure the counter points to the correct output address
    err_cnt          = 0;
    signed_zero_cnt  = 0;
    counter = address/4;
    line_num = 0;
    while (!$feof(stim_fd)) begin
      ret_code = $fscanf(stim_fd, "%x\n", exp_res);
      line_num++;
      if (exp_res !== tb_mxcore_hwpe.i_data_memory.memory[counter]) begin
        if (is_signed_zero_word(exp_res, tb_mxcore_hwpe.i_data_memory.memory[counter])) begin
          signed_zero_cnt += 1;
          $display("Warning: Signed/Unsigned Zero Mismatch occurs at Address %x, Index %0d, Line %0d: Expected %x, Got %x", counter*4, counter*4-address, line_num, exp_res, tb_mxcore_hwpe.i_data_memory.memory[counter]);
        end else begin
          err_cnt += 1;
          $display("Output Mismatch at Address %x, Index %0d, Line %0d: Expected %x, Got %x", counter*4, counter*4-address, line_num, exp_res, tb_mxcore_hwpe.i_data_memory.memory[counter]);
        end
      end
      counter++;
    end
    if (err_cnt == 0) begin
      if (signed_zero_cnt == 0)
        $display(":) Passed with no mismatches! :)");
      else
        $display(":) Passed with no mismatches (%0d signed/unsigned zero warnings)! :)", signed_zero_cnt);
    end else
      $display(":( Failed with %d mismatches! :(", err_cnt);
    $fclose(stim_fd);
  endtask

  task automatic PROGRAM_MXCORE(
    input logic [31:0]  vector_a_ptr,
    input logic [31:0]  vectors_b_ptr,
    input logic [31:0]  scale_a_ptr,
    input logic [31:0]  scale_b_ptr,
    input logic [31:0]  result_ptr,
    input logic [31:0]  result_scale_ptr,
    input logic [31:0]  ctrl_engine_val,
    input logic [31:0]  MDIM,
    input logic [31:0]  KDIM,
    input logic [31:0]  NDIM,
    ref   logic         clk_i
  );
    logic [3:0]  a_row_tiles_val;
    logic [4:0]  b_col_tiles_val;
    logic [6:0]  inner_tiles_val, inner_blocks_val;
    logic [31:0] a_tile_size_val, b_tile_size_val, result_tile_size_val, iter_count_val;
    a_row_tiles_val      = MDIM / REUSE;
    b_col_tiles_val      = NDIM / NPE;
    inner_tiles_val      = KDIM / VECTOR_SIZE;
    inner_blocks_val     = (`SRC_FMT == "FP4") ? ((KDIM + FP4_BLOCK_SIZE - 1) / FP4_BLOCK_SIZE) : ((KDIM + MX_BLOCK_SIZE - 1) / MX_BLOCK_SIZE);
    a_tile_size_val      = (`SRC_FMT == "FP4") ? (REUSE*VECTOR_SIZE*FP4_SRC_WIDTH) : (REUSE*VECTOR_SIZE*SRC_WIDTH);
    b_tile_size_val      = (`SRC_FMT == "FP4") ? (VECTOR_SIZE*NPE*FP4_SRC_WIDTH) : (VECTOR_SIZE*NPE*SRC_WIDTH);
    result_tile_size_val = (QuantizeOutput == 1) ? (NPE*REUSE*SRC_WIDTH) : (NPE*REUSE*DST_WIDTH);
    iter_count_val       = (`SRC_FMT == "FP4") ? ((KDIM*REUSE)/(2*VECTOR_SIZE)) : ((KDIM*REUSE)/VECTOR_SIZE);
    PERIPH_WRITE(  4*MXCoreRegVectorAPtr,     MXCORE_REG_OFFSET,  vector_a_ptr,     clk_i  );
    PERIPH_WRITE(  4*MXCoreRegVectorsBPtr,    MXCORE_REG_OFFSET,  vectors_b_ptr,    clk_i  );
    PERIPH_WRITE(  4*MXCoreRegScaleAPtr,      MXCORE_REG_OFFSET,  scale_a_ptr,      clk_i  );
    PERIPH_WRITE(  4*MXCoreRegScaleBPtr,      MXCORE_REG_OFFSET,  scale_b_ptr,      clk_i  );
    PERIPH_WRITE(  4*MXCoreRegResultPtr,       MXCORE_REG_OFFSET,  result_ptr,       clk_i  );
    PERIPH_WRITE(  4*MXCoreRegResultScalePtr, MXCORE_REG_OFFSET,  result_scale_ptr, clk_i  );
    PERIPH_WRITE(  4*MXCoreRegGEMMSize,        MXCORE_REG_OFFSET,  {NDIM[9:0], KDIM[11:0], MDIM[9:0]}, clk_i  );
    PERIPH_WRITE(  4*MXCoreRegCtrlEngine,      MXCORE_REG_OFFSET,  ctrl_engine_val,  clk_i  );
    PERIPH_WRITE(  4*MXCoreRegTileCounts,      MXCORE_REG_OFFSET,  {9'b0, inner_blocks_val, inner_tiles_val, b_col_tiles_val, a_row_tiles_val}, clk_i  );
    PERIPH_WRITE(  4*MXCoreRegATileSize,      MXCORE_REG_OFFSET,  a_tile_size_val,      clk_i  );
    PERIPH_WRITE(  4*MXCoreRegBTileSize,      MXCORE_REG_OFFSET,  b_tile_size_val,      clk_i  );
    PERIPH_WRITE(  4*MXCoreRegResultTileSize, MXCORE_REG_OFFSET,  result_tile_size_val, clk_i  );
    PERIPH_WRITE(  4*MXCoreRegIterCount,       MXCORE_REG_OFFSET,  iter_count_val,       clk_i  );
  endtask : PROGRAM_MXCORE

  localparam ID = 0;    // Core ID

  task automatic PERIPH_WRITE(
    input logic [31:0]  base_addr,
    input logic [31:0]  offset,
    input logic [31:0]  data,
    ref   logic         clk_i
  );
    //Initialize Bus Configuration for a Write Operation
    periph.req  = 1'b0;
    periph.add  = 32'b0;
    periph.wen  = 1'b1;
    periph.be   = 4'b0; // 'be' is 4 bits for byte enable
    periph.data = 32'b0;
    periph.id   = ID;

    // Setup Phase
    @(posedge clk_i);
    #APPL_DELAY;
    periph.req  = 1'b1;
    periph.add  = base_addr + offset;
    periph.wen  = 1'b0;     // Indicating Write Operation
    periph.be   = 4'b1111;  // Assuming full byte write
    periph.data = data;

    // Wait for GRANT, it can arrive in the same cycle too
    wait(periph.gnt);

    // Hold Phase
    @(posedge clk_i);
    #APPL_DELAY;

    // Termination Phase
    periph.req  = 1'b0;
    periph.add  = 32'b0;
    periph.wen  = 1'b1;     // Default State
    periph.be   = 4'b1111;  // Maintaining byte enable
    @(posedge clk_i);
  endtask : PERIPH_WRITE

  task automatic PERIPH_READ(
    input  logic [31:0]  base_addr,
    input  logic [31:0]  offset,
    output logic [31:0]  data,
    ref    logic         clk_i
  );
    // Initialize Bus for a Read Operation
    periph.req  = 1'b0;
    periph.add  = 32'b0;
    periph.wen  = 1'b1;   // Indicating not a write operation
    periph.be   = 4'b0;   // 'be' is for byte enable, reset to 0
    periph.data = 32'b0;  // Data not used in read setup
    periph.id   = ID;

    // Setup Phase
    @(posedge clk_i);
    #APPL_DELAY;
    periph.req  = 1'b1;
    periph.add  = base_addr + offset;
    periph.wen  = 1'b1; // Indicating not a write operation
    periph.be   = 4'b1111;

    // Wait for GRANT
    wait(periph.gnt);

    // Wait for Read Data to be valid
    @(posedge clk_i);
    wait(periph.r_valid);
    data = periph.r_data;

    // Termination Phase
    @(posedge clk_i);
    periph.req  = 1'b0;
    periph.add  = 32'b0;
    periph.wen  = 1'b1;     // Default State
    periph.be   = 4'b1111;  // Maintaining byte enable for consistency
  endtask : PERIPH_READ

endmodule : tb_mxcore_hwpe