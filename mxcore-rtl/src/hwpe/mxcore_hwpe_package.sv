// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

package mxcore_hwpe_package;
  import fpnew_pkg::*;
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;

  // HWPE Configuration
  parameter int unsigned NumCores               = 9;
  parameter int unsigned NumContext             = 1;
  parameter int unsigned IdWidth                = 3;
  parameter int unsigned MXCoreIoRegs           = 16;

  // Input/Output Datawidths
  parameter int unsigned MXCoreVectorADataWidth       = VectorSize*SRC_WIDTH;
  parameter int unsigned MXCoreVectorsBDataWidth      = NPE*VectorSize*SRC_WIDTH;
  parameter int unsigned MXCoreScaleADataWidth        = SCALE_WIDTH;
  parameter int unsigned MXCoreScaleBDataWidth        = NPE*SCALE_WIDTH;
  parameter int unsigned MXCoreEngineResultDataWidth  = NPE*DST_WIDTH;
  parameter int unsigned MXCoreQuantResultDataWidth   = NPE*SRC_WIDTH;
  parameter int unsigned MXCoreBF16ResultDataWidth    = NPE*16;
  parameter int unsigned MXCoreQuantScaleDataWidth    = (NPE/BlockSize)*SCALE_WIDTH;

  // TCDM Bandwidth available to MXCore
  parameter int unsigned MXCoreTCDMDataWidth           = `ifdef TCDM_BW `TCDM_BW `else 512 `endif;

  // Register File Map
  parameter int unsigned MXCoreRegVectorAPtr          = 0;   // Vector A Pointer
  parameter int unsigned MXCoreRegVectorsBPtr         = 1;   // Vectors B Pointer
  parameter int unsigned MXCoreRegScaleAPtr           = 2;   // Scale A Pointer
  parameter int unsigned MXCoreRegScaleBPtr           = 3;   // Scale B Pointer
  parameter int unsigned MXCoreRegPreloadBiasPtr      = 4;   // Preload Bias Pointer
  parameter int unsigned MXCoreRegResultPtr           = 5;   // Result Pointer
  parameter int unsigned MXCoreRegResultScalePtr      = 6;   // Result Scale Pointer
  parameter int unsigned MXCoreRegGEMMSize            = 7;   // [9:0]: M, [21:10]: K, [31:22]: N
  parameter int unsigned MXCoreRegCtrlEngine          = 8;   // Engine Control Parameters
  parameter int unsigned MXCoreRegTileCounts          = 9;   // [3:0]: A_ROW_TILES = M/Reuse (< 16); [8:4]: B_COL_TILES = N/NPE (< 32);
                                                                  // [15:9]: INNER_TILES = K/VectorSize (< 128); [22:16]: INNER_BLOCKS = K/BlockSize or K/FP4BlockSize (< 128)
  parameter int unsigned MXCoreRegATileSize           = 10;  // Reuse*VectorSize*W_A bits
  parameter int unsigned MXCoreRegBTileSize           = 11;  // VectorSize*NPE*W_B bits
  parameter int unsigned MXCoreRegPreloadTileSize     = 12;  // NPE*Reuse*W_PRELOAD bits
  parameter int unsigned MXCoreRegResultTileSize      = 13;  // NPE*Reuse*W_RESULT bits
  parameter int unsigned MXCoreRegResultScaleTileSize = 14;  // (NPE/BlockSize)*Reuse*SCALE_WIDTH bits
  parameter int unsigned MXCoreRegIterCount           = 15;  // (K/VectorSize) * Reuse cycles (< 8192)

  typedef struct packed {
    fpnew_pkg::roundmode_e    rnd_mode; // [2:0] (3)          // REG_CTRL_ENGINE[2:0]
    fpnew_pkg::operation_e    op;       // [4:0] (5)          // REG_CTRL_ENGINE[7:3]
    logic                     op_mod;   // (1)                // REG_CTRL_ENGINE[8]
    fpnew_pkg::fp_format_e    src_fmt;  // [3:0] (4)          // REG_CTRL_ENGINE[12:9]
    fpnew_pkg::fp_format_e    dst_fmt;  // [3:0] (4)          // REG_CTRL_ENGINE[16:13]
    logic                     tag;      // (1)                // REG_CTRL_ENGINE[17]
    logic                     mask;     // (1)                // REG_CTRL_ENGINE[18]
    logic                     aux;      // (1)                // REG_CTRL_ENGINE[19]
    logic                     flush;    // (1)                // REG_CTRL_ENGINE[20]
    logic                     quantize_bf16; // (1)           // REG_CTRL_ENGINE[21]
    logic                     quantize_mxfp8; // (1)          // REG_CTRL_ENGINE[22]
    logic                     block_poison_enable; // (1)     // REG_CTRL_ENGINE[23]
    logic                     preload; // (1)                 // REG_CTRL_ENGINE[24]
    logic [15:0]              iter_count;                     // REG_ITER_COUNT: per-output-tile iteration count
    logic                     sbmat_lt_bw;                    // If Scale B Matrix is smaller than TCDM BW (a single transaction)
    logic                     compute_en;                     // Compute enable (gated by the Preload state)
    logic [31:0]              result_scale_tot_pushes;        // Total M*N/NPE pushes expected into the result scale merge buffer
  } ctrl_engine_t;

  typedef struct packed {
    fpnew_pkg::status_t [NPE-1:0] status;
    logic               [NPE-1:0] extension_bit;
    logic                         tag;
    logic                         mask;
    logic                         aux;
    logic                         busy;
    logic                         preload_done;
    logic                         tile_end;
  } flags_engine_t;

  typedef struct packed {
    hci_package::hci_streamer_ctrl_t  vector_a_source_ctrl;
    hci_package::hci_streamer_ctrl_t  vectors_b_source_ctrl;
    hci_package::hci_streamer_ctrl_t  scale_a_source_ctrl;
    hci_package::hci_streamer_ctrl_t  scale_b_source_ctrl;
    hci_package::hci_streamer_ctrl_t  preload_bias_source_ctrl;
    hci_package::hci_streamer_ctrl_t  result_sink_ctrl;
    hci_package::hci_streamer_ctrl_t  result_scale_sink_ctrl;
  } ctrl_streamer_t;

  typedef struct packed {
    hci_package::hci_streamer_flags_t vector_a_source_flags;
    hci_package::hci_streamer_flags_t vectors_b_source_flags;
    hci_package::hci_streamer_flags_t scale_a_source_flags;
    hci_package::hci_streamer_flags_t scale_b_source_flags;
    hci_package::hci_streamer_flags_t preload_bias_source_flags;
    hci_package::hci_streamer_flags_t result_sink_flags;
    hci_package::hci_streamer_flags_t result_scale_sink_flags;
  } flags_streamer_t;

  typedef enum logic  [1:0] {
    MXCoreIdle,
    Preload,
    Compute,
    Done
  } engine_state_t;

endpackage : mxcore_hwpe_package