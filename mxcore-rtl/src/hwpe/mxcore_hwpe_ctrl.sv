// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module mxcore_hwpe_ctrl
  import fpnew_pkg::*;
  import fpnew_mxdotp_multi_pkg::*;
  import mxcore_package::*;
  import mxcore_hwpe_package::*;
  import hwpe_ctrl_package::*;
  import hwpe_stream_package::*;
#(
  parameter int unsigned NumCores = mxcore_hwpe_package::NumCores
) (
  // Global Signals
  input  logic                                  clk_i,
  input  logic                                  rst_ni,
  input  logic                                  test_mode_i,
  output logic                                  clear_o,
  // Events
  output logic [NumCores-1:0][REGFILE_N_EVT-1:0] evt_o,
  output logic                                  busy_o,
  // Control & Flags
  output ctrl_streamer_t                        ctrl_streamer_o,
  input  flags_streamer_t                       flags_streamer_i,
  output ctrl_engine_t                          ctrl_engine_o,
  input  flags_engine_t                         flags_engine_i,
  input  flags_fifo_t                           flags_fifo_i,
  // Periph Slave Port
  hwpe_ctrl_intf_periph.slave                   periph
);

  localparam int unsigned LOG_CONTEXT = NumContext > 1 ? $clog2(NumContext) : 1;

  logic                 slave_clear, stream_clear;
  ctrl_slave_t          slave_ctrl;
  flags_slave_t         slave_flags;
  ctrl_regfile_t        reg_file;
  logic [LOG_CONTEXT:0] counter_pending;
  /* HWPE Controller Slave Port + Register File */
  hwpe_ctrl_slave #(
    .N_CORES        ( NumCores        ),
    .N_CONTEXT      ( NumContext      ),
    .N_IO_REGS      ( MXCoreIoRegs    ),
    .N_GENERIC_REGS ( 0               ),
    .ID_WIDTH       ( IdWidth         )
  ) i_slave (
    .clk_i            ( clk_i           ),
    .rst_ni           ( rst_ni          ),
    .clear_o          ( slave_clear     ),
    .cfg              ( periph          ),
    .ctrl_i           ( slave_ctrl      ),
    .flags_o          ( slave_flags     ),
    .reg_file         ( reg_file        ),
    .counter_pending  ( counter_pending )
  );

  assign evt_o      = slave_flags.evt;
  assign busy_o     = slave_flags.is_working;
  assign clear_o    = slave_clear || stream_clear;

  // Operand Matrix Size Parameters
  logic [9:0]  M, N;
  assign M = reg_file.hwpe_params[MXCoreRegGEMMSize][9:0];
  assign N = reg_file.hwpe_params[MXCoreRegGEMMSize][31:22];

  // Tiling Parameters
  logic [31:0]  A_ROW_TILES, B_COL_TILES, INNER_TILES, INNER_BLOCKS;
  logic [31:0]  A_TILE_SIZE_REG, B_TILE_SIZE_REG, PRELOAD_TILE_SIZE_REG, RESULT_TILE_SIZE_REG, RESULT_SCALE_TILE_SIZE_REG;
  logic [31:0]  A_MAT_SIZE, B_MAT_SIZE, SA_MAT_SIZE, SB_MAT_SIZE, RESULT_SCALE_MAT_SIZE;
  logic [31:0]  A_ROW_TILE_SIZE, SA_ROW_TILE_SIZE;
  logic [31:0]  TOT_TILES;
  logic [31:0]  ITER_COUNT;
  assign A_ROW_TILES                = reg_file.hwpe_params[MXCoreRegTileCounts][3:0];
  assign B_COL_TILES                = reg_file.hwpe_params[MXCoreRegTileCounts][8:4];
  assign INNER_TILES                = reg_file.hwpe_params[MXCoreRegTileCounts][15:9];
  assign INNER_BLOCKS               = reg_file.hwpe_params[MXCoreRegTileCounts][22:16];
  assign A_TILE_SIZE_REG            = reg_file.hwpe_params[MXCoreRegATileSize];
  assign B_TILE_SIZE_REG            = reg_file.hwpe_params[MXCoreRegBTileSize];
  assign PRELOAD_TILE_SIZE_REG      = reg_file.hwpe_params[MXCoreRegPreloadTileSize];
  assign RESULT_TILE_SIZE_REG       = reg_file.hwpe_params[MXCoreRegResultTileSize];
  assign RESULT_SCALE_TILE_SIZE_REG = reg_file.hwpe_params[MXCoreRegResultScaleTileSize];
  assign TOT_TILES                  = A_ROW_TILES * B_COL_TILES;
  assign ITER_COUNT                 = reg_file.hwpe_params[MXCoreRegIterCount];

  localparam int unsigned VEC_PER_BLOCK = BlockSize / VectorSize;
  localparam int unsigned SA_TILE_SIZE  = Reuse*SCALE_WIDTH;
  localparam int unsigned SB_TILE_SIZE  = NPE*SCALE_WIDTH;
  localparam bit          SATILE_GT_BW  = (SA_TILE_SIZE > MXCoreTCDMDataWidth);

  logic SBMAT_LT_BW;
  always_comb begin
    A_ROW_TILE_SIZE       = A_TILE_SIZE_REG * INNER_TILES;
    SA_ROW_TILE_SIZE      = SA_TILE_SIZE * INNER_BLOCKS;
    A_MAT_SIZE            = A_ROW_TILE_SIZE * A_ROW_TILES;
    B_MAT_SIZE            = B_TILE_SIZE_REG * INNER_TILES * B_COL_TILES;
    SA_MAT_SIZE           = SA_ROW_TILE_SIZE * A_ROW_TILES;
    SB_MAT_SIZE           = SB_TILE_SIZE * INNER_BLOCKS * B_COL_TILES;
    RESULT_SCALE_MAT_SIZE = RESULT_SCALE_TILE_SIZE_REG * TOT_TILES;
    SBMAT_LT_BW           = (SB_MAT_SIZE < MXCoreTCDMDataWidth);
  end

  engine_state_t  state_d, state_q;

  always_comb begin
    // Engine Control Signals - Output to Engine
    ctrl_engine_o                         = '0;
    ctrl_engine_o.rnd_mode                = fpnew_pkg::roundmode_e'(reg_file.hwpe_params[MXCoreRegCtrlEngine][2:0]);
    ctrl_engine_o.op                      = fpnew_pkg::operation_e'(reg_file.hwpe_params[MXCoreRegCtrlEngine][7:3]);
    ctrl_engine_o.op_mod                  = reg_file.hwpe_params[MXCoreRegCtrlEngine][8];
    ctrl_engine_o.src_fmt                 = fpnew_pkg::fp_format_e'(reg_file.hwpe_params[MXCoreRegCtrlEngine][12:9]);
    ctrl_engine_o.dst_fmt                 = fpnew_pkg::fp_format_e'(reg_file.hwpe_params[MXCoreRegCtrlEngine][16:13]);
    ctrl_engine_o.tag                     = reg_file.hwpe_params[MXCoreRegCtrlEngine][17];
    ctrl_engine_o.mask                    = reg_file.hwpe_params[MXCoreRegCtrlEngine][18];
    ctrl_engine_o.aux                     = reg_file.hwpe_params[MXCoreRegCtrlEngine][19];
    ctrl_engine_o.flush                   = reg_file.hwpe_params[MXCoreRegCtrlEngine][20];
    ctrl_engine_o.quantize_bf16           = reg_file.hwpe_params[MXCoreRegCtrlEngine][21];
    ctrl_engine_o.quantize_mxfp8          = reg_file.hwpe_params[MXCoreRegCtrlEngine][22] && !reg_file.hwpe_params[MXCoreRegCtrlEngine][21];
    ctrl_engine_o.block_poison_enable     = reg_file.hwpe_params[MXCoreRegCtrlEngine][23];
    ctrl_engine_o.preload                 = reg_file.hwpe_params[MXCoreRegCtrlEngine][24];
    ctrl_engine_o.iter_count              = ITER_COUNT[15:0];
    ctrl_engine_o.sbmat_lt_bw             = SBMAT_LT_BW;
    ctrl_engine_o.compute_en              = !ctrl_engine_o.preload || (state_q == Compute);
    ctrl_engine_o.result_scale_tot_pushes = TOT_TILES * Reuse;
  end

  logic [31:0]  vector_a_addr, vectors_b_addr, scale_a_addr, scale_b_addr, preload_bias_addr, result_addr, result_scale_addr;
  assign vector_a_addr      = reg_file.hwpe_params[MXCoreRegVectorAPtr];
  assign vectors_b_addr     = reg_file.hwpe_params[MXCoreRegVectorsBPtr];
  assign scale_a_addr       = reg_file.hwpe_params[MXCoreRegScaleAPtr];
  assign scale_b_addr       = reg_file.hwpe_params[MXCoreRegScaleBPtr];
  assign preload_bias_addr  = reg_file.hwpe_params[MXCoreRegPreloadBiasPtr];
  assign result_addr        = reg_file.hwpe_params[MXCoreRegResultPtr];
  assign result_scale_addr  = reg_file.hwpe_params[MXCoreRegResultScalePtr];

  // -------- Standard Dataflow Streamer Configuration Parameters ---------- //
  logic [31:0]  A_TOT_LEN, A_D0_STRIDE, A_D0_LEN, A_D1_STRIDE, A_D1_LEN, A_D2_STRIDE, A_D2_LEN, A_D3_STRIDE;                                                  // Matrix A
  logic [31:0]  B_TOT_LEN, B_D0_STRIDE, B_D0_LEN, B_D1_STRIDE, B_D1_LEN, B_D2_STRIDE, B_D2_LEN, B_D3_STRIDE;                                                  // Matrix B
  logic [31:0]  SCALE_A_TOT_LEN, SCALE_A_D0_STRIDE, SCALE_A_D0_LEN, SCALE_A_D1_STRIDE, SCALE_A_D1_LEN, SCALE_A_D2_STRIDE, SCALE_A_D2_LEN, SCALE_A_D3_STRIDE, SCALE_A_D3_LEN;  // Scale Matrix A
  logic [31:0]  SCALE_B_TOT_LEN, SCALE_B_D0_STRIDE, SCALE_B_D0_LEN, SCALE_B_D1_STRIDE, SCALE_B_D1_LEN, SCALE_B_D2_STRIDE, SCALE_B_D2_LEN, SCALE_B_D3_STRIDE;  // Scale Matrix B
  logic [31:0]  PRELOAD_BIAS_TOT_LEN;                                                                                                                         // Preload Bias Matrix
  logic [31:0]  RESULT_TOT_LEN;                                                                                                                               // Result Matrix
  logic [31:0]  RESULT_SCALE_TOT_LEN;                                                                                                                         // Result Scale Matrix
  logic [3:0]   A_DIM_ENABLE, B_DIM_ENABLE, SCALE_A_DIM_ENABLE, SCALE_B_DIM_ENABLE;

  always_comb begin
    // // ------------------------ Matrix A ---------------------------- // //
    A_TOT_LEN           = (A_MAT_SIZE * B_COL_TILES) / MXCoreTCDMDataWidth;
    A_D0_STRIDE         = MXCoreTCDMDataWidth / 8;
    A_D0_LEN            = A_ROW_TILE_SIZE / MXCoreTCDMDataWidth;
    A_D1_STRIDE         = '0;
    A_D1_LEN            = B_COL_TILES;
    A_D2_STRIDE         = A_ROW_TILE_SIZE / 8;
    A_D2_LEN            = A_ROW_TILES;
    A_D3_STRIDE         = '0;
    A_DIM_ENABLE        = 4'b0011;
    // // ------------------------ Matrix B ---------------------------- // //
    B_TOT_LEN           = (B_MAT_SIZE * A_ROW_TILES) / MXCoreTCDMDataWidth;
    B_D0_STRIDE         = MXCoreTCDMDataWidth / 8;
    B_D0_LEN            = B_MAT_SIZE / MXCoreTCDMDataWidth;
    B_D1_STRIDE         = '0;
    B_D1_LEN            = A_ROW_TILES;
    B_D2_STRIDE         = '0;
    B_D2_LEN            = '0;
    B_D3_STRIDE         = '0;
    B_DIM_ENABLE        = 4'b0001;
    // // ----------------------- Scale Matrix A ----------------------- // //
    if (SATILE_GT_BW) begin
      SCALE_A_TOT_LEN     = (SA_TILE_SIZE * VEC_PER_BLOCK * INNER_BLOCKS * B_COL_TILES) / MXCoreTCDMDataWidth;
      SCALE_A_D0_STRIDE   = MXCoreTCDMDataWidth / 8;
      SCALE_A_D0_LEN      = SA_TILE_SIZE / MXCoreTCDMDataWidth;
      SCALE_A_D1_STRIDE   = '0;
      SCALE_A_D1_LEN      = VEC_PER_BLOCK;
      SCALE_A_D2_STRIDE   = SA_TILE_SIZE / 8;
      SCALE_A_D2_LEN      = INNER_BLOCKS;
      SCALE_A_D3_STRIDE   = '0;
      SCALE_A_D3_LEN      = B_COL_TILES;
      SCALE_A_DIM_ENABLE  = 4'b0111;
    end else begin
      SCALE_A_TOT_LEN     = (SA_MAT_SIZE * B_COL_TILES + MXCoreTCDMDataWidth - 1) / MXCoreTCDMDataWidth;
      SCALE_A_D0_STRIDE   = MXCoreTCDMDataWidth / 8;
      SCALE_A_D0_LEN      = (SA_ROW_TILE_SIZE + MXCoreTCDMDataWidth - 1) / MXCoreTCDMDataWidth;
      SCALE_A_D1_STRIDE   = '0;
      SCALE_A_D1_LEN      = B_COL_TILES;
      SCALE_A_D2_STRIDE   = SA_ROW_TILE_SIZE / 8;
      SCALE_A_D2_LEN      = A_ROW_TILES;
      SCALE_A_D3_STRIDE   = '0;
      SCALE_A_D3_LEN      = '0;
      SCALE_A_DIM_ENABLE  = 4'b0011;
    end
    // // ----------------------- Scale Matrix B ----------------------- // //
    if (SBMAT_LT_BW) begin
      SCALE_B_TOT_LEN     = 1;
      SCALE_B_D0_STRIDE   = MXCoreTCDMDataWidth / 8;
      SCALE_B_D0_LEN      = 1;
      SCALE_B_D1_STRIDE   = '0;
      SCALE_B_D1_LEN      = '0;
      SCALE_B_D2_STRIDE   = '0;
      SCALE_B_D2_LEN      = '0;
      SCALE_B_D3_STRIDE   = '0;
      SCALE_B_DIM_ENABLE  = 4'b0000;
    end else begin
      SCALE_B_TOT_LEN     = SB_MAT_SIZE * A_ROW_TILES / MXCoreTCDMDataWidth;
      SCALE_B_D0_STRIDE   = MXCoreTCDMDataWidth / 8;
      SCALE_B_D0_LEN      = SB_MAT_SIZE / MXCoreTCDMDataWidth;
      SCALE_B_D1_STRIDE   = '0;
      SCALE_B_D1_LEN      = A_ROW_TILES;
      SCALE_B_D2_STRIDE   = '0;
      SCALE_B_D2_LEN      = '0;
      SCALE_B_D3_STRIDE   = '0;
      SCALE_B_DIM_ENABLE  = 4'b0001;
    end
    // // ---------------------- Preload Bias Matrix --------------------- // //
    PRELOAD_BIAS_TOT_LEN  = (PRELOAD_TILE_SIZE_REG * A_ROW_TILES * B_COL_TILES) / MXCoreTCDMDataWidth;
    // // ---------------------- Result Matrix --------------------------- // //
    RESULT_TOT_LEN        = (RESULT_TILE_SIZE_REG * A_ROW_TILES * B_COL_TILES) / MXCoreTCDMDataWidth;
    RESULT_SCALE_TOT_LEN  = (RESULT_SCALE_MAT_SIZE < MXCoreTCDMDataWidth) ? 1 : (RESULT_SCALE_MAT_SIZE / MXCoreTCDMDataWidth);
  end

  logic [31:0]  tile_count_d, tile_count_q;

  always_comb begin
    // Default Assignments
    state_d                                             = state_q;
    tile_count_d                                        = tile_count_q;
    ctrl_streamer_o.vector_a_source_ctrl.req_start      = 1'b0;
    ctrl_streamer_o.vectors_b_source_ctrl.req_start     = 1'b0;
    ctrl_streamer_o.scale_a_source_ctrl.req_start       = 1'b0;
    ctrl_streamer_o.scale_b_source_ctrl.req_start       = 1'b0;
    ctrl_streamer_o.preload_bias_source_ctrl.req_start  = 1'b0;
    ctrl_streamer_o.result_sink_ctrl.req_start          = 1'b0;
    ctrl_streamer_o.result_scale_sink_ctrl.req_start    = 1'b0;
    slave_ctrl                                          = '0;
    stream_clear                                        = 0;

    case (state_q)
      MXCoreIdle: begin
        if (slave_flags.start) begin
          state_d                                             = ctrl_engine_o.preload ? Preload : Done;
          ctrl_streamer_o.vector_a_source_ctrl.req_start      = 1'b1;
          ctrl_streamer_o.vectors_b_source_ctrl.req_start     = 1'b1;
          ctrl_streamer_o.scale_a_source_ctrl.req_start       = 1'b1;
          ctrl_streamer_o.scale_b_source_ctrl.req_start       = 1'b1;
          ctrl_streamer_o.preload_bias_source_ctrl.req_start  = ctrl_engine_o.preload;
          ctrl_streamer_o.result_sink_ctrl.req_start          = 1'b1;
          ctrl_streamer_o.result_scale_sink_ctrl.req_start    = ctrl_engine_o.quantize_mxfp8;
        end
      end
      Preload: begin
        if (flags_engine_i.preload_done) begin
          state_d = Compute;
        end
      end
      Compute: begin
        if (flags_engine_i.tile_end) begin
          if (tile_count_q == TOT_TILES - 1) begin
            state_d = Done;
          end else begin
            state_d       = Preload;
            tile_count_d  = tile_count_q + 1;
          end
        end
      end
      Done: begin
        if (~flags_engine_i.busy && flags_streamer_i.vector_a_source_flags.ready_start && flags_streamer_i.vectors_b_source_flags.ready_start && flags_streamer_i.scale_a_source_flags.ready_start && flags_streamer_i.scale_b_source_flags.ready_start && flags_streamer_i.preload_bias_source_flags.ready_start && flags_streamer_i.result_sink_flags.ready_start && flags_streamer_i.result_scale_sink_flags.ready_start && flags_fifo_i.empty) begin
          state_d         = MXCoreIdle;
          tile_count_d    = '0;
          slave_ctrl.done = 1'b1;
          stream_clear    = 1'b1;
        end
      end
    endcase

    // ------------------------------------------ Matrix A Streamer Configuration ------------------------------------------- //
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.base_addr      = vector_a_addr;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.tot_len        = A_TOT_LEN;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d0_stride      = A_D0_STRIDE;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d0_len         = A_D0_LEN;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d1_stride      = A_D1_STRIDE;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d1_len         = A_D1_LEN;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d2_stride      = A_D2_STRIDE;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d2_len         = A_D2_LEN;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d3_stride      = A_D3_STRIDE;
    ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.dim_enable_1h  = A_DIM_ENABLE;

    // ------------------------------------------ Matrix B Streamer Configuration ------------------------------------------- //
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.base_addr     = vectors_b_addr;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.tot_len       = B_TOT_LEN;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d0_stride     = B_D0_STRIDE;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d0_len        = B_D0_LEN;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d1_stride     = B_D1_STRIDE;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d1_len        = B_D1_LEN;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d2_stride     = B_D2_STRIDE;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d2_len        = B_D2_LEN;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d3_stride     = B_D3_STRIDE;
    ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.dim_enable_1h = B_DIM_ENABLE;

    // ------------------------------------------ Scale A Streamer Configuration ------------------------------------------- //
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.base_addr       = scale_a_addr;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.tot_len         = SCALE_A_TOT_LEN;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d0_stride       = SCALE_A_D0_STRIDE;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d0_len          = SCALE_A_D0_LEN;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d1_stride       = SCALE_A_D1_STRIDE;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d1_len          = SCALE_A_D1_LEN;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d2_stride       = SCALE_A_D2_STRIDE;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d2_len          = SCALE_A_D2_LEN;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d3_stride       = SCALE_A_D3_STRIDE;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d3_len          = SCALE_A_D3_LEN;
    ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.dim_enable_1h   = SCALE_A_DIM_ENABLE;

    // ------------------------------------------ Scale B Streamer Configuration ------------------------------------------- //
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.base_addr       = scale_b_addr;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.tot_len         = SCALE_B_TOT_LEN;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d0_stride       = SCALE_B_D0_STRIDE;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d0_len          = SCALE_B_D0_LEN;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d1_stride       = SCALE_B_D1_STRIDE;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d1_len          = SCALE_B_D1_LEN;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d2_stride       = SCALE_B_D2_STRIDE;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d2_len          = SCALE_B_D2_LEN;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d3_stride       = SCALE_B_D3_STRIDE;
    ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.dim_enable_1h   = SCALE_B_DIM_ENABLE;

    // -------------------------------------- Preload Bias Streamer Configuration --------------------------------------- //
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.base_addr      = preload_bias_addr;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.tot_len        = PRELOAD_BIAS_TOT_LEN;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d0_stride      = MXCoreTCDMDataWidth / 8;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d0_len         = PRELOAD_BIAS_TOT_LEN;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d1_stride      = '0;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d1_len         = '0;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d2_stride      = '0;
    ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.dim_enable_1h  = 4'b0000;

    // ------------------------------------------ Result Streamer Configuration ------------------------------------------- //
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.base_addr          = result_addr;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.tot_len            = RESULT_TOT_LEN;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d0_stride          = MXCoreTCDMDataWidth / 8;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d0_len             = RESULT_TOT_LEN;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d1_stride          = '0;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d1_len             = '0;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d2_stride          = '0;
    ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.dim_enable_1h      = 4'b0000;

    // --------------------------------------- Result Scale Streamer Configuration --------------------------------------- //
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.base_addr      = result_scale_addr;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.tot_len        = RESULT_SCALE_TOT_LEN;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d0_stride      = MXCoreTCDMDataWidth / 8;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d0_len         = RESULT_SCALE_TOT_LEN;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d1_stride      = '0;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d1_len         = '0;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d2_stride      = '0;
    ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.dim_enable_1h  = 4'b0000;
  end

  `FF(state_q,      state_d,      MXCoreIdle)
  `FF(tile_count_q, tile_count_d, '0)

endmodule : mxcore_hwpe_ctrl
