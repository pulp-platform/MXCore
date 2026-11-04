// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

module mxcore_hwpe_top
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
  input  logic                                    clk_i,
  input  logic                                    rst_ni,
  input  logic                                    test_mode_i,
  // Events
  output logic [NumCores-1:0][REGFILE_N_EVT-1:0]  evt_o,
  output logic                                    busy_o,
  // TCDM Master Ports
  hci_core_intf.initiator                         tcdm,
  // Peripheral Slave Port
  hwpe_ctrl_intf_periph.slave                     periph
);

  // Control and Status Signals
  logic                 enable, clear;
  logic                 quantize_any, quantize_mxfp8_any, mx_result_ready;
  ctrl_streamer_t       streamer_ctrl;
  flags_streamer_t      streamer_flags;
  ctrl_engine_t         engine_ctrl;
  flags_engine_t        engine_flags;
  flags_fifo_t          flags_fifo;

  // ---------------- BEGIN: Input and Output HWPE Data Streams ---------------- //
  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_vector_a (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_vectors_b (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_scale_a (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_scale_b (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_preload_bias (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_result (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_result_scale (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreVectorDataWidth   )
  ) mxcore_engine_vector_a (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreScaleDataWidth    )
  ) mxcore_engine_scale_a (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) mxcore_engine_result (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) engine_preload_bias (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) standalone_fp32_input (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( 2*MXCoreTCDMDataWidth )
  ) standalone_bf16_input (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) standalone_fp32_row (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) standalone_bf16_row (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) quantizer_source (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreQuantResultDataWidth )
  ) mxcore_mxfp8_result (
    .clk  ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreMXFP4ResultDataWidth )
  ) mxcore_mxfp4_result (
    .clk  ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreQuantScaleDataWidth )
  ) mxcore_mx_result_scale (
    .clk  ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreBF16ResultDataWidth )
  ) mxcore_bf16_quant_result (
    .clk  ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_bf16_result (
    .clk  ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) engine_result_to_quantizer (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreEngineResultDataWidth )
  ) engine_result_to_fifo (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_quantized_result (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_mxfp4_quantized_result (
    .clk ( clk_i )
  );

  hwpe_stream_intf_stream #(
    .DATA_WIDTH ( MXCoreTCDMDataWidth )
  ) mxcore_fp32_result (
    .clk ( clk_i )
  );
  // ----------------- END: Input and Output HWPE Data Streams ----------------- //

  // ---------------------- BEGIN: Broadcast Input Buffers  --------------------- //
  // Matrix A Buffer
  mxcore_hwpe_fifo_buffer #(
    .InputDataWidth   ( MXCoreTCDMDataWidth   ),
    .OutputDataWidth  ( MXCoreVectorDataWidth ),
    .FifoDepth        ( 2                     )
  ) i_vector_a_buffer (
    .clk_i  ( clk_i                         ),
    .rst_ni ( rst_ni                        ),
    .clear_i( clear                         ),
    .data_i ( mxcore_vector_a.sink          ),
    .data_o ( mxcore_engine_vector_a.source )
  );

  // Scale A Buffer
  mxcore_hwpe_fifo_scale_buffer #(
    .InputDataWidth   ( MXCoreTCDMDataWidth     ),
    .OutputDataWidth  ( MXCoreScaleDataWidth    ),
    .ReuseFactor      ( Reuse                   ),
    .ScaleFactor      ( BlockSize / VectorSize  ),
    .FifoDepth        ( 2                       )
  ) i_scale_a_buffer (
    .clk_i              ( clk_i                         ),
    .rst_ni             ( rst_ni                        ),
    .clear_i            ( clear                         ),
    .data_i             ( mxcore_scale_a.sink           ),
    .data_o             ( mxcore_engine_scale_a.source  )
  );
  // ---------------------- END: Broadcast Input Buffers  ----------------------- //

  // ------------------------- MXCore HWPE Controller -------------------------- //
  mxcore_hwpe_ctrl #(
    .NumCores ( NumCores )
  ) i_ctrl (
    .clk_i            ( clk_i           ),
    .rst_ni           ( rst_ni          ),
    .test_mode_i      ( test_mode_i     ),
    .clear_o          ( clear           ),
    .evt_o            ( evt_o           ),
    .busy_o           ( busy_o          ),
    .ctrl_streamer_o  ( streamer_ctrl   ),
    .flags_streamer_i ( streamer_flags  ),
    .ctrl_engine_o    ( engine_ctrl     ),
    .flags_engine_i   ( engine_flags    ),
    .flags_fifo_i     ( flags_fifo      ),
    .periph           ( periph          )
  );

  // -------------------------- MXCore Engine ---------------------------------- //
  mxcore_hwpe_engine i_engine (
    .clk_i          ( clk_i                         ),
    .rst_ni         ( rst_ni                        ),
    .clear_i        ( clear                         ),
    .test_mode_i    ( test_mode_i                   ),
    .vector_a_i     ( mxcore_engine_vector_a.sink   ),
    .vectors_b_i    ( mxcore_vectors_b.sink         ),
    .scale_a_i      ( mxcore_engine_scale_a.sink    ),
    .scale_b_i      ( mxcore_scale_b.sink           ),
    .preload_bias_i ( engine_preload_bias.sink      ),
    .result_o       ( mxcore_engine_result.source   ),
    .ctrl_i         ( engine_ctrl                   ),
    .flags_o        ( engine_flags                  )
  );

  // ----------------------- Standalone Quantizer Input ------------------------ //
  logic [2*MXCoreTCDMDataWidth-1:0] standalone_bf16_wide;

  assign engine_preload_bias.valid    = !engine_ctrl.quantize_standalone && mxcore_preload_bias.valid;
  assign engine_preload_bias.data     = mxcore_preload_bias.data;
  assign engine_preload_bias.strb     = mxcore_preload_bias.strb;
  assign standalone_fp32_input.valid  = engine_ctrl.quantize_standalone && !engine_ctrl.standalone_input_bf16 && mxcore_preload_bias.valid;
  assign standalone_fp32_input.data   = mxcore_preload_bias.data;
  assign standalone_fp32_input.strb   = mxcore_preload_bias.strb;
  assign standalone_bf16_input.valid  = engine_ctrl.quantize_standalone && engine_ctrl.standalone_input_bf16 && mxcore_preload_bias.valid;
  assign standalone_bf16_input.data   = standalone_bf16_wide;
  assign standalone_bf16_input.strb   = '1;
  assign mxcore_preload_bias.ready    = !engine_ctrl.quantize_standalone  ? engine_preload_bias.ready   :
                                        engine_ctrl.standalone_input_bf16 ? standalone_bf16_input.ready : standalone_fp32_input.ready;

  generate
    for (genvar i = 0; i < MXCoreTCDMDataWidth/16; i++) begin : gen_bf16_widen
      assign standalone_bf16_wide[i*32+:32] = {mxcore_preload_bias.data[i*16+:16], 16'b0};
    end
  endgenerate

  // FP32 Input Buffer
  mxcore_hwpe_result_fifo_buffer #(
    .InputDataWidth     ( MXCoreTCDMDataWidth         ),
    .OutputDataWidth    ( MXCoreEngineResultDataWidth ),
    .FifoDepth          ( 2                           )
  ) i_standalone_fp32_buffer (
    .clk_i    ( clk_i                         ),
    .rst_ni   ( rst_ni                        ),
    .clear_i  ( clear                         ),
    .data_i   ( standalone_fp32_input.sink    ),
    .data_o   ( standalone_fp32_row.source    )
  );

  // BF16 Input Buffer
  generate
    if (2*MXCoreTCDMDataWidth == MXCoreEngineResultDataWidth) begin : gen_bf16_direct
      assign standalone_bf16_row.valid    = standalone_bf16_input.valid;
      assign standalone_bf16_row.data     = standalone_bf16_input.data;
      assign standalone_bf16_row.strb     = standalone_bf16_input.strb;
      assign standalone_bf16_input.ready  = standalone_bf16_row.ready;
    end else begin : gen_bf16_buffer
      mxcore_hwpe_result_fifo_buffer #(
        .InputDataWidth     ( 2*MXCoreTCDMDataWidth       ),
        .OutputDataWidth    ( MXCoreEngineResultDataWidth ),
        .FifoDepth          ( 2                           )
      ) i_standalone_bf16_buffer (
        .clk_i    ( clk_i                         ),
        .rst_ni   ( rst_ni                        ),
        .clear_i  ( clear                         ),
        .data_i   ( standalone_bf16_input.sink    ),
        .data_o   ( standalone_bf16_row.source    )
      );
    end
  endgenerate

  // ------------------------- Quantizer Source MUX ---------------------------- //
  assign quantizer_source.valid     = !engine_ctrl.quantize_standalone  ? mxcore_engine_result.valid :
                                      engine_ctrl.standalone_input_bf16 ? standalone_bf16_row.valid  : standalone_fp32_row.valid;
  assign quantizer_source.data      = !engine_ctrl.quantize_standalone  ? mxcore_engine_result.data  :
                                      engine_ctrl.standalone_input_bf16 ? standalone_bf16_row.data   : standalone_fp32_row.data;
  assign quantizer_source.strb      = !engine_ctrl.quantize_standalone  ? mxcore_engine_result.strb  :
                                      engine_ctrl.standalone_input_bf16 ? standalone_bf16_row.strb   : standalone_fp32_row.strb;
  assign mxcore_engine_result.ready = !engine_ctrl.quantize_standalone && quantizer_source.ready;
  assign standalone_fp32_row.ready  = engine_ctrl.quantize_standalone && !engine_ctrl.standalone_input_bf16 && quantizer_source.ready;
  assign standalone_bf16_row.ready  = engine_ctrl.quantize_standalone && engine_ctrl.standalone_input_bf16 && quantizer_source.ready;

  // ------------------------ MXCore Engine Result DEMUX ----------------------- //
  assign quantize_mxfp8_any               = engine_ctrl.quantize_mxfp8 || engine_ctrl.quantize_mxfp8alt;
  assign quantize_any                     = quantize_mxfp8_any || engine_ctrl.quantize_mxfp4 || engine_ctrl.quantize_bf16;
  assign engine_result_to_quantizer.valid = quantize_any ? quantizer_source.valid : 1'b0;
  assign engine_result_to_quantizer.data  = quantizer_source.data;
  assign engine_result_to_quantizer.strb  = quantizer_source.strb;
  assign engine_result_to_fifo.valid      = quantize_any ? 1'b0 : quantizer_source.valid;
  assign engine_result_to_fifo.data       = quantizer_source.data;
  assign engine_result_to_fifo.strb       = quantizer_source.strb;
  assign quantizer_source.ready           = quantize_any ? engine_result_to_quantizer.ready : engine_result_to_fifo.ready;

  // ------------------------- MX Result Quantizer ----------------------------- //
  mxcore_hwpe_block_quantizer #(
    .BlockSize         ( BlockSize                   ),
    .ScaleWidth        ( SCALE_WIDTH                 ),
    .InputDataWidth    ( MXCoreEngineResultDataWidth )
  ) i_result_quantizer (
    .clk_i                ( clk_i                           ),
    .rst_ni               ( rst_ni                          ),
    .block_poison_i       ( engine_ctrl.block_poison_enable ),
    .quantize_mxfp4_i     ( engine_ctrl.quantize_mxfp4      ),
    .quantize_mxfp8alt_i  ( engine_ctrl.quantize_mxfp8alt   ),
    .quantize_mxfp8_i     ( engine_ctrl.quantize_mxfp8      ),
    .quantize_bf16_i      ( engine_ctrl.quantize_bf16       ),
    .fp32_result_i        ( engine_result_to_quantizer.sink ),
    .mxfp8_result_o       ( mxcore_mxfp8_result.source      ),
    .mxfp4_result_o       ( mxcore_mxfp4_result.source      ),
    .mx_result_scale_o    ( mxcore_mx_result_scale.source   ),
    .bf16_result_o        ( mxcore_bf16_quant_result.source )
  );

  // ----------------------- MXCore Result FIFO Buffers ------------------------ //
  // Quantized Result Buffer
  mxcore_hwpe_result_fifo_buffer #(
    .InputDataWidth     ( MXCoreQuantResultDataWidth  ),
    .OutputDataWidth    ( MXCoreTCDMDataWidth         ),
    .FifoDepth          ( 2                           )
  ) i_result_mx_buffer (
    .clk_i    ( clk_i                           ),
    .rst_ni   ( rst_ni                          ),
    .clear_i  ( clear                           ),
    .data_i   ( mxcore_mxfp8_result.sink        ),
    .data_o   ( mxcore_quantized_result.source  )
  );
  // MXFP4 Quantized Result Buffer
  mxcore_hwpe_result_fifo_buffer #(
    .InputDataWidth     ( MXCoreMXFP4ResultDataWidth  ),
    .OutputDataWidth    ( MXCoreTCDMDataWidth         ),
    .FifoDepth          ( 2                           )
  ) i_result_mxfp4_buffer (
    .clk_i    ( clk_i                                 ),
    .rst_ni   ( rst_ni                                ),
    .clear_i  ( clear                                 ),
    .data_i   ( mxcore_mxfp4_result.sink              ),
    .data_o   ( mxcore_mxfp4_quantized_result.source  )
  );
  // MX Result Block Scale Buffer
  assign mx_result_ready = engine_ctrl.quantize_mxfp4 ? mxcore_mxfp4_result.ready : mxcore_mxfp8_result.ready;
  mxcore_hwpe_result_scale_fifo_buffer #(
    .InputDataWidth     ( MXCoreQuantScaleDataWidth ),
    .OutputDataWidth    ( MXCoreTCDMDataWidth       ),
    .FifoDepth          ( 2                         )
  ) i_result_scale_mx_buffer (
    .clk_i                  ( clk_i                               ),
    .rst_ni                 ( rst_ni                              ),
    .clear_i                ( clear                               ),
    .engine_result_ready_i  ( mx_result_ready                     ),
    .tot_pushes_i           ( engine_ctrl.result_scale_tot_pushes ),
    .data_i                 ( mxcore_mx_result_scale.sink         ),
    .data_o                 ( mxcore_result_scale.source          )
  );
  // BF16 Result Buffer
  mxcore_hwpe_result_fifo_buffer #(
    .InputDataWidth     ( MXCoreBF16ResultDataWidth   ),
    .OutputDataWidth    ( MXCoreTCDMDataWidth         ),
    .FifoDepth          ( 2                           )
  ) i_result_bf16_buffer (
    .clk_i    ( clk_i                           ),
    .rst_ni   ( rst_ni                          ),
    .clear_i  ( clear                           ),
    .data_i   ( mxcore_bf16_quant_result.sink   ),
    .data_o   ( mxcore_bf16_result.source       )
  );
  // Non-Quantized Result Buffer
  mxcore_hwpe_result_fifo_buffer #(
    .InputDataWidth     ( MXCoreEngineResultDataWidth ),
    .OutputDataWidth    ( MXCoreTCDMDataWidth         ),
    .FifoDepth          ( 2                           )
  ) i_result_buffer (
    .clk_i    ( clk_i                       ),
    .rst_ni   ( rst_ni                      ),
    .clear_i  ( clear                       ),
    .data_i   ( engine_result_to_fifo.sink  ),
    .data_o   ( mxcore_fp32_result.source   )
  );

  // ------------------------- MXCore Engine Result MUX ------------------------ //
  assign mxcore_result.valid                  = engine_ctrl.quantize_bf16  ? mxcore_bf16_result.valid            :
                                                quantize_mxfp8_any         ? mxcore_quantized_result.valid       :
                                                engine_ctrl.quantize_mxfp4 ? mxcore_mxfp4_quantized_result.valid : mxcore_fp32_result.valid;
  assign mxcore_result.data                   = engine_ctrl.quantize_bf16  ? mxcore_bf16_result.data             :
                                                quantize_mxfp8_any         ? mxcore_quantized_result.data        :
                                                engine_ctrl.quantize_mxfp4 ? mxcore_mxfp4_quantized_result.data  : mxcore_fp32_result.data;
  assign mxcore_result.strb                   = engine_ctrl.quantize_bf16  ? mxcore_bf16_result.strb             :
                                                quantize_mxfp8_any         ? mxcore_quantized_result.strb        :
                                                engine_ctrl.quantize_mxfp4 ? mxcore_mxfp4_quantized_result.strb  : mxcore_fp32_result.strb;
  assign mxcore_bf16_result.ready             = engine_ctrl.quantize_bf16  ? mxcore_result.ready : 1'b0;
  assign mxcore_quantized_result.ready        = quantize_mxfp8_any         ? mxcore_result.ready : 1'b0;
  assign mxcore_mxfp4_quantized_result.ready  = engine_ctrl.quantize_mxfp4 ? mxcore_result.ready : 1'b0;
  assign mxcore_fp32_result.ready             = quantize_any               ? 1'b0 : mxcore_result.ready;

  // -------------------------- MXCore HWPE Streamer --------------------------- //
  assign enable = 1'b1;
  mxcore_hwpe_streamer i_streamer (
    .clk_i          ( clk_i                      ),
    .rst_ni         ( rst_ni                     ),
    .test_mode_i    ( test_mode_i                ),
    .enable_i       ( enable                     ),
    .clear_i        ( clear                      ),
    .vector_a_o     ( mxcore_vector_a.source     ),
    .vectors_b_o    ( mxcore_vectors_b.source    ),
    .scale_a_o      ( mxcore_scale_a.source      ),
    .scale_b_o      ( mxcore_scale_b.source      ),
    .preload_bias_o ( mxcore_preload_bias.source ),
    .result_i       ( mxcore_result.sink         ),
    .result_scale_i ( mxcore_result_scale.sink   ),
    .tcdm_o         ( tcdm                       ),
    .ctrl_i         ( streamer_ctrl              ),
    .flags_o        ( streamer_flags             ),
    .flags_fifo_o   ( flags_fifo                 )
  );

endmodule : mxcore_hwpe_top
