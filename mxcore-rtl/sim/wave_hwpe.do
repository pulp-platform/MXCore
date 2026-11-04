# Copyright 2026 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_mxcore_hwpe/dut/i_mxcore/clk_i
add wave -noupdate -expand -group MXCore_Engine -label busy -color Cyan /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/busy_o
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/vector_a
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/scale_a
add wave -noupdate -expand -group MXCore_Engine -label vector_b_pe0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/vector_b}
add wave -noupdate -expand -group MXCore_Engine -label scale_b_pe0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/scale_b}
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/vector_b_valid
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/scale_b_valid
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/inputs_valid
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/in_accept
add wave -noupdate -expand -group MXCore_Engine -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/in_fire
add wave -noupdate -expand -group MXCore_Engine -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/out_fire
add wave -noupdate -expand -group MXCore_Engine -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/iter_count_i
add wave -noupdate -expand -group MXCore_Engine -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/in_count_q
add wave -noupdate -expand -group MXCore_Engine -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/out_count_q
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/first_iter
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/last_iter
add wave -noupdate -expand -group MXCore_Engine -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/tile_end
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/compute_en_i
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/preload_i
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/mxdotp_busy
add wave -noupdate -expand -group MXCore_Engine /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/obuff_empty
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/in_valid_i
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/in_ready_o
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/out_valid_o
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/out_ready_i
add wave -noupdate -expand -group MXCore_Engine -group PE_Array /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/tile_result_o
add wave -noupdate -expand -group MXCore_Engine -group PE_Array /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/busy_o
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/pe_in_ready
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/pe_out_valid
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/vector_a_i}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/scale_a_i}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/vector_b}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/scale_b}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/operand_d}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 -color Yellow {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/i_fpnew_mxdotp_multi/in_valid_i}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 -color Orange {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/i_fpnew_mxdotp_multi/in_ready_o}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 -color Yellow {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/i_fpnew_mxdotp_multi/out_valid_o}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 -color Orange {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/i_fpnew_mxdotp_multi/out_ready_i}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/mxdotp_result}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/obuff_result}
add wave -noupdate -expand -group MXCore_Engine -group PE_Array -group PE_0 {/tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_pe_array/gen_mxcore_pe[0]/i_mxcore_pe/tile_result}
add wave -noupdate -color Cyan /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/busy_o
add wave -noupdate -group Output_Buffer_Ctrl -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/mxdotp_result_valid_i
add wave -noupdate -group Output_Buffer_Ctrl -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/mxdotp_result_ready_o
add wave -noupdate -group Output_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/obuff_result_valid_o
add wave -noupdate -group Output_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/obuff_result_ready_i
add wave -noupdate -group Output_Buffer_Ctrl -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/status_q
add wave -noupdate -group Output_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/read_addr_q
add wave -noupdate -group Output_Buffer_Ctrl -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/write_enable
add wave -noupdate -group Output_Buffer_Ctrl -color Yellow -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/write_addr_q
add wave -noupdate -group Output_Buffer_Ctrl -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/tile_status_q
add wave -noupdate -group Output_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/empty_o
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/preload_bias_valid_i
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/preload_bias_ready_o
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/bias_allowed
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/bias_row_open
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/bias_write_enable
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/bias_addr_q
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/bias_word_q
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/preload_count_q
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/final_count_q
add wave -noupdate -group Output_Buffer_Ctrl -group Preload_Bias_Write -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/preload_ready_o
add wave -noupdate -group Tile_Read -color Cyan /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/last_iter_i
add wave -noupdate -group Tile_Read /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/tile_end_i
add wave -noupdate -group Tile_Read -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/tile_result_valid_o
add wave -noupdate -group Tile_Read -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/tile_result_ready_i
add wave -noupdate -group Tile_Read /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/tile_result
add wave -noupdate -group Tile_Read -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_output_buffer_ctrl/tile_addr_q
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/clear_i
add wave -noupdate -group ReuseCounters -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/iter_count_i
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/count_in_i
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/count_out_i
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/first_iter_o
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/last_iter_o
add wave -noupdate -group ReuseCounters /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/tile_end_o
add wave -noupdate -group ReuseCounters -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/in_count_q
add wave -noupdate -group ReuseCounters -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_reuse_counters/out_count_q
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vector_a/valid
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vector_a/ready
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vector_a/data
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vector_a/strb
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vectors_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vectors_b/valid
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vectors_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vectors_b/ready
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vectors_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vectors_b/data
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_vectors_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_vectors_b/strb
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_a/valid
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_a/ready
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_a/data
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_a/strb
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_b/valid
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_b/ready
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_b/data
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_scale_b /tb_mxcore_hwpe/dut/i_mxcore/mxcore_scale_b/strb
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/valid
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/ready
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/data
add wave -noupdate -group Inputs -group Inputs_From_Streamer -group mxcore_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/strb
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_vector_a/valid
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_vector_a/ready
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_vector_a/data
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_vector_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_vector_a/strb
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_scale_a/valid
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_scale_a/ready
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_scale_a/data
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_scale_a /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_scale_a/strb
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/valid
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/ready
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/data
add wave -noupdate -group Inputs -group Inputs_Engine -group mxcore_engine_preload_bias /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/strb
add wave -noupdate -group Result -expand -group Result_Engine -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_result/valid
add wave -noupdate -group Result -expand -group Result_Engine -color Orange /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_result/ready
add wave -noupdate -group Result -expand -group Result_Engine /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_result/data
add wave -noupdate -group Result -expand -group Result_Engine /tb_mxcore_hwpe/dut/i_mxcore/mxcore_engine_result/strb
add wave -noupdate -group Result -group Result_Demux /tb_mxcore_hwpe/dut/i_mxcore/quantize_any
add wave -noupdate -group Result -group Result_Demux /tb_mxcore_hwpe/dut/i_mxcore/quantize_mxfp8_any
add wave -noupdate -group Result -group Result_Demux -group To_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/valid
add wave -noupdate -group Result -group Result_Demux -group To_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/ready
add wave -noupdate -group Result -group Result_Demux -group To_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/data
add wave -noupdate -group Result -group Result_Demux -group To_FP32_FIFO /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_fifo/valid
add wave -noupdate -group Result -group Result_Demux -group To_FP32_FIFO /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_fifo/ready
add wave -noupdate -group Result -group Result_Demux -group To_FP32_FIFO /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_fifo/data
add wave -noupdate -group Result -group Result_MXFP8_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/valid
add wave -noupdate -group Result -group Result_MXFP8_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/ready
add wave -noupdate -group Result -group Result_MXFP8_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/data
add wave -noupdate -group Result -group Result_MXFP8_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/strb
add wave -noupdate -group Result -group Result_MXFP4_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/valid
add wave -noupdate -group Result -group Result_MXFP4_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/ready
add wave -noupdate -group Result -group Result_MXFP4_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/data
add wave -noupdate -group Result -group Result_MXFP4_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/strb
add wave -noupdate -group Result -group Result_BF16_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/valid
add wave -noupdate -group Result -group Result_BF16_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/ready
add wave -noupdate -group Result -group Result_BF16_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/data
add wave -noupdate -group Result -group Result_BF16_Quantized /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/strb
add wave -noupdate -group Result -group Result_Streamer -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/valid
add wave -noupdate -group Result -group Result_Streamer -color Orange /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/ready
add wave -noupdate -group Result -group Result_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/data
add wave -noupdate -group Result -group Result_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/strb
add wave -noupdate -group Vector_B_Buffer_Ctrl -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/data_valid_i
add wave -noupdate -group Vector_B_Buffer_Ctrl -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/data_ready_o
add wave -noupdate -group Vector_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/data_valid_o
add wave -noupdate -group Vector_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/data_ready_i
add wave -noupdate -group Vector_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/write_enable_o
add wave -noupdate -group Vector_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/write_addr_o
add wave -noupdate -group Vector_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/read_addr_o
add wave -noupdate -group Vector_B_Buffer_Ctrl -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/row_full_q
add wave -noupdate -group Vector_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/push_count_q
add wave -noupdate -group Vector_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/pop_count_q
add wave -noupdate -group Vector_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_vector_b_buffer_ctrl/reuse_count_q
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/data_valid_i
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/data_ready_o
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/data_valid_o
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/data_ready_i
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/sbmat_lt_bw_i
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/write_enable_o
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/write_addr_o
add wave -noupdate -group Scale_B_Buffer_Ctrl /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/read_addr_o
add wave -noupdate -group Scale_B_Buffer_Ctrl -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/row_full_q
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/push_count_q
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/pop_count_q
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/reuse_count_q
add wave -noupdate -group Scale_B_Buffer_Ctrl -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_engine/i_mxcore_engine/i_scale_b_buffer_ctrl/scale_reuse_count_q
add wave -noupdate -group Vector_A_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_vector_a_buffer/reuse_cnt_q
add wave -noupdate -group Scale_A_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/ReuseFactor
add wave -noupdate -group Scale_A_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/ScaleFactor
add wave -noupdate -group Scale_A_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/FIFO_FACTOR
add wave -noupdate -group Scale_A_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/SCALE_COUNT
add wave -noupdate -group Scale_A_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/NBLOCKS
add wave -noupdate -group Scale_A_Buffer -group data_fifo /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/data_fifo/valid
add wave -noupdate -group Scale_A_Buffer -group data_fifo /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/data_fifo/ready
add wave -noupdate -group Scale_A_Buffer -group data_fifo /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/data_fifo/data
add wave -noupdate -group Scale_A_Buffer -group data_fifo /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/data_fifo/strb
add wave -noupdate -group Scale_A_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/reuse_cnt_q
add wave -noupdate -group Scale_A_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/scale_reuse_cnt_q
add wave -noupdate -group Scale_A_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_scale_a_buffer/block_count_q
add wave -noupdate -group Memory -expand /tb_mxcore_hwpe/i_data_memory/memory
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/req
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/gnt
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/r_valid
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/r_ready
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/add
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/wen
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/data
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/be
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/id
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/r_data
add wave -noupdate -group LDST_TCDM /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/ldst_tcdm/r_id
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/clk
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/req
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/gnt
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_valid
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_ready
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/add
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/wen
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/data
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/be
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/user
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/id
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_data
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_user
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_id
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_opc
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/ecc
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_ecc
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/ereq
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/egnt
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_evalid
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/r_eready
add wave -noupdate -group TCDM /tb_mxcore_hwpe/dut/i_mxcore/tcdm/clk_assert
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/clear_i
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_req
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_gnt
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_r_valid
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_lrdy
add wave -noupdate -group LDST_MUX -expand /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_add
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_wen
add wave -noupdate -group LDST_MUX /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_ldst_mux/in_data
add wave -noupdate -group Streamer_Ctrl -label A_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vector_a_source_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label B_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.vectors_b_source_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label Scale_A_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_a_source_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label Scale_B_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.scale_b_source_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label Preload_Bias_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label Result_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_sink_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Ctrl -label Result_Scale_Ctrl -childformat {{tot_len -radix unsigned} {d0_len -radix unsigned} {d0_stride -radix unsigned} {d1_len -radix unsigned} {d1_stride -radix decimal} {d2_len -radix unsigned} {d2_stride -radix unsigned} {d3_stride -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.tot_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d0_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d0_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d1_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d1_stride {-radix decimal} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d2_len {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d2_stride {-radix unsigned} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl.d3_stride {-radix unsigned}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.result_scale_sink_ctrl.addressgen_ctrl
add wave -noupdate -group Streamer_Flags -label A_Flags /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.vector_a_source_flags
add wave -noupdate -group Streamer_Flags -label B_Flags /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.vectors_b_source_flags
add wave -noupdate -group Streamer_Flags -label Scale_A_Flags -childformat {{/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_a_source_flags.addressgen_flags.d0_counter_val -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_a_source_flags.addressgen_flags.d0_counter_val {-height 16 -radix unsigned -radixshowbase 0}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_a_source_flags.addressgen_flags
add wave -noupdate -group Streamer_Flags -label Scale_B_Flags -childformat {{/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_b_source_flags.addressgen_flags.d0_counter_val -radix unsigned}} -subitemconfig {/tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_b_source_flags.addressgen_flags.d0_counter_val {-height 16 -radix unsigned -radixshowbase 0}} /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.scale_b_source_flags.addressgen_flags
add wave -noupdate -group Streamer_Flags -label Preload_Bias_Flags /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.preload_bias_source_flags
add wave -noupdate -group Streamer_Flags -label Result_Flags /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.result_sink_flags
add wave -noupdate -group Streamer_Flags -label Result_Scale_Flags /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.result_scale_sink_flags
add wave -noupdate -group AddressGenV3_B -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/overall_counter_q
add wave -noupdate -group AddressGenV3_B -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/d0_counter_q
add wave -noupdate -group AddressGenV3_B -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/d1_counter_q
add wave -noupdate -group AddressGenV3_B -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/d2_counter_q
add wave -noupdate -group AddressGenV3_B -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/d3_counter_q
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d0_len
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d0_stride
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d1_len
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d1_stride
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d2_len
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d2_stride
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.d3_stride
add wave -noupdate -group AddressGenV3_B /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_vectors_b_stream_source/i_addressgen/ctrl_i.dim_enable_1h
add wave -noupdate -group AddressGenV3_Preload_Bias -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_preload_bias_stream_source/i_addressgen/overall_counter_q
add wave -noupdate -group AddressGenV3_Preload_Bias -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/i_preload_bias_stream_source/i_addressgen/d0_counter_q
add wave -noupdate -group Result_Scales_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/valid
add wave -noupdate -group Result_Scales_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/ready
add wave -noupdate -group Result_Scales_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/data
add wave -noupdate -group Result_Scales_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/strb
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/engine_result_ready_i
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_fifo_valid
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_fifo_ready
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_fifo_data
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_fifo_strb
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/pop_fifo_valid
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/pop_fifo_ready
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/pop_fifo_data
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/pop_fifo_strb
add wave -noupdate -group Result_Scale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_count_q
add wave -noupdate -group Result_Scale_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_total_q
add wave -noupdate -group Result_Scale_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/tot_pushes_i
add wave -noupdate -group Result_Scale_Buffer -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/flush_pending
add wave -noupdate -group Result_Scale_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/lane_active
add wave -noupdate -group Result_Scales_TCDM /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/valid
add wave -noupdate -group Result_Scales_TCDM /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/ready
add wave -noupdate -group Result_Scales_TCDM /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/data
add wave -noupdate -group Result_Scales_TCDM /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/strb
add wave -noupdate -group MX_Quantizer -expand -group FP32_Result /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/valid
add wave -noupdate -group MX_Quantizer -expand -group FP32_Result /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/ready
add wave -noupdate -group MX_Quantizer -expand -group FP32_Result /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/data
add wave -noupdate -group MX_Quantizer -expand -group FP32_Result /tb_mxcore_hwpe/dut/i_mxcore/engine_result_to_quantizer/strb
add wave -noupdate -group MX_Quantizer -expand -group MXFP8_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/valid
add wave -noupdate -group MX_Quantizer -expand -group MXFP8_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/ready
add wave -noupdate -group MX_Quantizer -expand -group MXFP8_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/data
add wave -noupdate -group MX_Quantizer -expand -group MXFP8_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/strb
add wave -noupdate -group MX_Quantizer -group MXFP4_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/valid
add wave -noupdate -group MX_Quantizer -group MXFP4_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/ready
add wave -noupdate -group MX_Quantizer -group MXFP4_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/data
add wave -noupdate -group MX_Quantizer -group MXFP4_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/strb
add wave -noupdate -group MX_Quantizer -group BF16_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/valid
add wave -noupdate -group MX_Quantizer -group BF16_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/ready
add wave -noupdate -group MX_Quantizer -group BF16_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/data
add wave -noupdate -group MX_Quantizer -group BF16_Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/strb
add wave -noupdate -group MX_Quantizer -expand -group MX_Result_Scales /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/valid
add wave -noupdate -group MX_Quantizer -expand -group MX_Result_Scales /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/ready
add wave -noupdate -group MX_Quantizer -expand -group MX_Result_Scales /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/data
add wave -noupdate -group MX_Quantizer -expand -group MX_Result_Scales /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/strb
add wave -noupdate -group MX_Quantizer -expand -group MX_Result_Scales {/tb_mxcore_hwpe/dut/i_mxcore/i_result_quantizer/quantizer_array[0]/i_quantizer/block_poison}
add wave -noupdate -group MX_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_fifo_valid
add wave -noupdate -group MX_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_fifo_ready
add wave -noupdate -group MX_Result_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_fifo_data
add wave -noupdate -group MX_Result_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_fifo_strb
add wave -noupdate -group MX_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/pop_fifo_valid
add wave -noupdate -group MX_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/pop_fifo_ready
add wave -noupdate -group MX_Result_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/pop_fifo_data
add wave -noupdate -group MX_Result_Buffer /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/pop_fifo_strb
add wave -noupdate -group MX_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_count_q
add wave -noupdate -group MX_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/pop_count_q
add wave -noupdate -group MXFP4_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/push_fifo_valid
add wave -noupdate -group MXFP4_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/push_fifo_ready
add wave -noupdate -group MXFP4_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/pop_fifo_valid
add wave -noupdate -group MXFP4_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/pop_fifo_ready
add wave -noupdate -group MXFP4_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/push_count_q
add wave -noupdate -group MXFP4_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/pop_count_q
add wave -noupdate -group BF16_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/push_fifo_valid
add wave -noupdate -group BF16_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/push_fifo_ready
add wave -noupdate -group BF16_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/pop_fifo_valid
add wave -noupdate -group BF16_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/pop_fifo_ready
add wave -noupdate -group BF16_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/push_count_q
add wave -noupdate -group BF16_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/pop_count_q
add wave -noupdate -group FP32_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/push_fifo_valid
add wave -noupdate -group FP32_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/push_fifo_ready
add wave -noupdate -group FP32_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/pop_fifo_valid
add wave -noupdate -group FP32_Result_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/pop_fifo_ready
add wave -noupdate -group FP32_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/push_count_q
add wave -noupdate -group FP32_Result_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/pop_count_q
add wave -noupdate -group OScale_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/valid
add wave -noupdate -group OScale_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/ready
add wave -noupdate -group OScale_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/data
add wave -noupdate -group OScale_Streamer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/strb
add wave -noupdate -group OScale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/valid
add wave -noupdate -group OScale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/ready
add wave -noupdate -group OScale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/data
add wave -noupdate -group OScale_Buffer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/strb
add wave -noupdate -group OScale_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/valid
add wave -noupdate -group OScale_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/ready
add wave -noupdate -group OScale_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/data
add wave -noupdate -group OScale_Quantizer /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/strb
add wave -noupdate -color Cyan /tb_mxcore_hwpe/dut/i_mxcore/i_streamer/flags_fifo_o.empty
add wave -noupdate -group HWPE_Ctrl_FSM -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/state_q
add wave -noupdate -group HWPE_Ctrl_FSM -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/counter_pending
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/sources_ready
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/output_compatible
add wave -noupdate -group HWPE_Ctrl_FSM -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/start_job
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/latch_output
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/arm_output_q
add wave -noupdate -group HWPE_Ctrl_FSM -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/tile_count_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/last_tile
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/preload_wait_q
add wave -noupdate -group HWPE_Ctrl_FSM -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/compute_done
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/compute_pending_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/output_armed_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/slave_done_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/quantize_mx
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/data_drained_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/scale_drained_q
add wave -noupdate -group HWPE_Ctrl_FSM -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/output_done
add wave -noupdate -group HWPE_Ctrl_FSM -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/job_done
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/pending_evt_q
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/evt_o
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_engine_o
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/job_output
add wave -noupdate -group HWPE_Ctrl_FSM /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_output_q
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/slave_clear
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/stream_clear
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/clear_o
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/slave_ctrl
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/slave_flags
add wave -noupdate -group HWPE_Ctrl_Slave /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/reg_file
add wave -noupdate /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o
add wave -noupdate /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i
add wave -noupdate -group TILING_PARAMS -group MKN -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/M
add wave -noupdate -group TILING_PARAMS -group MKN -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/N
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/A_ROW_TILES
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/B_COL_TILES
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/INNER_TILES
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SA_VEC_PER_BLOCK
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/INNER_BLOCKS
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/TOT_TILES
add wave -noupdate -group TILING_PARAMS -group TILES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ITER_COUNT
add wave -noupdate -group TILING_PARAMS -group MATSIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/A_MAT_SIZE
add wave -noupdate -group TILING_PARAMS -group MATSIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/B_MAT_SIZE
add wave -noupdate -group TILING_PARAMS -group MATSIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SA_MAT_SIZE
add wave -noupdate -group TILING_PARAMS -group MATSIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SB_MAT_SIZE
add wave -noupdate -group TILING_PARAMS -group MATSIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/RESULT_SCALE_MAT_SIZE
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/A_TILE_SIZE_REG
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/B_TILE_SIZE_REG
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SA_TILE_SIZE
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SB_TILE_SIZE
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/PRELOAD_TILE_SIZE_REG
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/RESULT_TILE_SIZE_REG
add wave -noupdate -group TILING_PARAMS -group TILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/RESULT_SCALE_TILE_SIZE_REG
add wave -noupdate -group TILING_PARAMS -group ROWCOLTILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/A_ROW_TILE_SIZE
add wave -noupdate -group TILING_PARAMS -group ROWCOLTILESIZES -radix decimal -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SA_ROW_TILE_SIZE
add wave -noupdate -group TILING_PARAMS -group TILE_FLAGS /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SATILE_GT_BW
add wave -noupdate -group TILING_PARAMS -group TILE_FLAGS /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SBMAT_LT_BW
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/A_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/B_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SCALE_A_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SCALE_A_D0_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SCALE_B_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/SCALE_B_D0_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/PRELOAD_BIAS_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/RESULT_TOT_LEN
add wave -noupdate -group TILING_PARAMS -group TOT_LENS -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/RESULT_SCALE_TOT_LEN
add wave -noupdate -group Quantizer_Standalone -group Mode -label quantize_standalone /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.quantize_standalone
add wave -noupdate -group Quantizer_Standalone -group Mode -label standalone_input_bf16 /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.standalone_input_bf16
add wave -noupdate -group Quantizer_Standalone -group Mode -label quantize_mxfp8 /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.quantize_mxfp8
add wave -noupdate -group Quantizer_Standalone -group Mode -label quantize_mxfp8alt /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.quantize_mxfp8alt
add wave -noupdate -group Quantizer_Standalone -group Mode -label quantize_mxfp4 /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.quantize_mxfp4
add wave -noupdate -group Quantizer_Standalone -group Mode -label quantize_bf16 /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.quantize_bf16
add wave -noupdate -group Quantizer_Standalone -group Mode -label block_poison_enable /tb_mxcore_hwpe/dut/i_mxcore/engine_ctrl.block_poison_enable
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -label req_start /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.req_start
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -label base_addr /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.base_addr
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -label tot_len -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/ctrl_streamer_o.preload_bias_source_ctrl.addressgen_ctrl.tot_len
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/valid
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -color Orange /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/ready
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream /tb_mxcore_hwpe/dut/i_mxcore/mxcore_preload_bias/data
add wave -noupdate -group Quantizer_Standalone -expand -group Input_Stream -label input_done -color Orange /tb_mxcore_hwpe/dut/i_mxcore/i_ctrl/flags_streamer_i.preload_bias_source_flags.done
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group To_Engine /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/valid
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group To_Engine /tb_mxcore_hwpe/dut/i_mxcore/engine_preload_bias/ready
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group FP32_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_input/valid
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group FP32_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_input/ready
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group FP32_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_input/data
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group BF16_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_input/valid
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group BF16_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_input/ready
add wave -noupdate -group Quantizer_Standalone -group Input_Demux -group BF16_Input /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_input/data
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_standalone_fp32_buffer/push_fifo_valid
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_standalone_fp32_buffer/push_fifo_ready
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -radix binary /tb_mxcore_hwpe/dut/i_mxcore/i_standalone_fp32_buffer/pop_fifo_valid
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_standalone_fp32_buffer/push_count_q
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -group FP32_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_row/valid
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -group FP32_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_row/ready
add wave -noupdate -group Quantizer_Standalone -group FP32_Merge_Buffer -group FP32_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_fp32_row/data
add wave -noupdate -group Quantizer_Standalone -group BF16_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_row/valid
add wave -noupdate -group Quantizer_Standalone -group BF16_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_row/ready
add wave -noupdate -group Quantizer_Standalone -group BF16_Row /tb_mxcore_hwpe/dut/i_mxcore/standalone_bf16_row/data
add wave -noupdate -group Quantizer_Standalone -expand -group Quantizer_Source -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/quantizer_source/valid
add wave -noupdate -group Quantizer_Standalone -expand -group Quantizer_Source -color Orange /tb_mxcore_hwpe/dut/i_mxcore/quantizer_source/ready
add wave -noupdate -group Quantizer_Standalone -expand -group Quantizer_Source /tb_mxcore_hwpe/dut/i_mxcore/quantizer_source/data
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP8 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/valid
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP8 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/ready
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP8 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp8_result/data
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP4 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/valid
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP4 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/ready
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MXFP4 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mxfp4_result/data
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group BF16 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/valid
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group BF16 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/ready
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group BF16 /tb_mxcore_hwpe/dut/i_mxcore/mxcore_bf16_quant_result/data
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MX_Scale /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/valid
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MX_Scale /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/ready
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MX_Scale /tb_mxcore_hwpe/dut/i_mxcore/mxcore_mx_result_scale/data
add wave -noupdate -group Quantizer_Standalone -group Result_Quantizer -group MX_Scale {/tb_mxcore_hwpe/dut/i_mxcore/i_result_quantizer/quantizer_array[0]/i_quantizer/block_poison}
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group MXFP8_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mx_buffer/push_count_q
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group MXFP4_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_mxfp4_buffer/push_count_q
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group BF16_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_bf16_buffer/push_count_q
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group FP32_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_buffer/pop_count_q
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group Scale_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/push_total_q
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group Scale_Buffer -color Cyan -radix unsigned -radixshowbase 0 /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/tot_pushes_i
add wave -noupdate -group Quantizer_Standalone -group Result_Buffers -group Scale_Buffer -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/i_result_scale_mx_buffer/flush_pending
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/valid
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result -color Orange /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/ready
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result/data
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result_Scale -color Yellow /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/valid
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result_Scale -color Orange /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/ready
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result_Scale /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/data
add wave -noupdate -group Quantizer_Standalone -expand -group Result_Sinks -group Result_Scale /tb_mxcore_hwpe/dut/i_mxcore/mxcore_result_scale/strb
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 193
configure wave -valuecolwidth 245
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {494550 ps}
