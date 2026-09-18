// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

package mxcore_package;
  import fpnew_pkg::*;
  import fpnew_mxdotp_multi_pkg::*;

  parameter int unsigned    VectorSize  = `ifdef VECTOR_SIZE `VECTOR_SIZE `else 32 `endif;
  parameter int unsigned    NPE         = `ifdef NPE `NPE `else 32 `endif;
  parameter int unsigned    Reuse       = `ifdef REUSE `REUSE `else 64 `endif;
  parameter int unsigned    NumPipeRegs = `ifdef NUM_PIPE_REGS `NUM_PIPE_REGS `else 4 `endif;

  parameter type                     TagType     = logic;
  parameter type                     AuxType     = logic;
  parameter fpnew_pkg::pipe_config_t PipeConfig  = fpnew_pkg::BEFORE;

  parameter int unsigned             NumOperands   = 2*VectorSize+1;
  parameter int unsigned             LaneWidth     = VectorSize*SRC_WIDTH;

  // Microscaling (MX) Parameters
  parameter int unsigned BlockSize                = 32;
  parameter int unsigned MXFP8BlockSize           = BlockSize * SRC_WIDTH;
  parameter int unsigned FP4SrcWidth              = 4;
  parameter int unsigned FP4BlockSize             = 2 * BlockSize;

  parameter fpnew_pkg::fmt_logic_t   EnMxdotpSrcFpFmtConfig  = 9'b000101001; // FP8, FP8ALT, FP4
  parameter fpnew_pkg::ifmt_logic_t  EnMxdotpSrcIntFmtConfig = 4'b0000;      // No INT8
  parameter fpnew_pkg::fmt_logic_t   EnMxdotpDstFpFmtConfig  = 9'b100000000; // FP32

endpackage : mxcore_package