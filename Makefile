# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

SHELL = /usr/bin/env bash
ROOT_DIR := $(patsubst %/,%, $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

INSTALL_PREFIX       ?= install
INSTALL_DIR           = ${ROOT_DIR}/${INSTALL_PREFIX}
BENDER_INSTALL_DIR    = ${INSTALL_DIR}/bender

VENV_BIN=venv/bin/

BENDER_VERSION = 0.28.1
SIM_PATH   ?= mxcore-rtl/sim/build

BENDER_TARGETS = -t rtl -t test

target ?= tb_mxcore_hwpe
ALL_FORMATS := FP8 FP8ALT FP6 FP6ALT FP4
enabled_formats ?= FP8 FP8ALT

# Source and Destination Data Formats
src_fmt ?= FP4
dst_fmt ?= FP32
block_size ?= 32
# MXCore Configuration
vector_size ?= 32
num_compute_units ?= 32
num_out_buffers ?= 64
num_pipe_regs ?= 4
tcdm_bw ?= 512
# Output Quantization
quantize_mxfp8 ?= 1
quantize_bf16 ?= 0
# Accumulator Preload
preload ?= 0
# Stalling in TB
no_stalls ?= 1
prob_stall ?= 10 # 10% stall probability
# Input Parameters
mdim ?= 128
kdim ?= 128
ndim ?= 128

ifeq ($(preload), 1)
	TV_DIR           ?= ${ROOT_DIR}/testvectors/preload
else
	TV_DIR           ?= ${ROOT_DIR}/testvectors/nopreload
endif
MEM_DIR			     ?= ${TV_DIR}/memory
ifeq ($(quantize_bf16), 1)
	RES_DIR		     ?= ${TV_DIR}/result_bf16
else ifeq ($(quantize_mxfp8), 1)
	RES_DIR		     ?= ${TV_DIR}/result_mx
else
	RES_DIR			 ?= ${TV_DIR}/result
endif

memory_file ?= data_memory_${src_fmt}_VS${vector_size}_MX${num_compute_units}_O${num_out_buffers}_M${mdim}_K${kdim}_N${ndim}_BS${block_size}.txt
result_file ?= result_${src_fmt}_VS${vector_size}_MX${num_compute_units}_O${num_out_buffers}_M${mdim}_K${kdim}_N${ndim}_BS${block_size}.txt

vlog_defs := $(foreach fmt,$(ALL_FORMATS), \
  -DEN_$(fmt)=$(if $(filter $(fmt),$(enabled_formats)),1,0) )
vlog_defs += -DMEM_FILE="\"$(MEM_DIR)/$(memory_file)\"" -DRES_FILE="\"$(RES_DIR)/$(result_file)\""
vlog_defs += -DSRC_FMT="\"$(src_fmt)\"" -DDST_FMT="\"$(dst_fmt)\""
vlog_defs += -DVECTOR_SIZE=$(vector_size) -DNPE=$(num_compute_units) -DREUSE=$(num_out_buffers) -DNUM_PIPE_REGS=$(num_pipe_regs) -DTCDM_BW=$(tcdm_bw)
vlog_defs += -DM=$(mdim) -DK=$(kdim) -DN=$(ndim) -DQUANTIZE_MXFP8=$(quantize_mxfp8) -DQUANTIZE_BF16=$(quantize_bf16) -DPRELOAD=$(preload)
vlog_defs += -DPROB_STALL=$(prob_stall) -DNO_STALLS=$(no_stalls)

ifeq ($(target), tb_mxcore_hwpe)
	BENDER_TARGETS += -t mxcore_hwpe -t mxcore_hwpe_test
	vlog_defs += -DHCI_ASSERT_DELAY=\#41ps
endif

VLOG_FLAGS += -svinputport=compat
VLOG_FLAGS += -timescale 1ns/1ps

.PHONY: clean-sim sim-script sim
all: sim

clean-sim:
	rm -rf $(SIM_PATH)/work
	rm -rf $(SIM_PATH)/compile.tcl
	rm -rf $(SIM_PATH)/wlft*
	rm -rf $(SIM_PATH)/transcript
	rm -rf $(SIM_PATH)/modelsim.ini
	rm -rf $(SIM_PATH)/vsim.wlf

sim-script: clean-sim
	mkdir -p $(SIM_PATH)
	$(BENDER_INSTALL_DIR)/bender script vsim $(BENDER_TARGETS) $(vlog_defs) --vlog-arg="$(VLOG_FLAGS)" >> $(SIM_PATH)/compile.tcl

sim: sim-script
	cd mxcore-rtl/sim && \
	$(MAKE) $(target)

# Bender
bender: check-bender
	$(BENDER_INSTALL_DIR)/bender checkout
	$(BENDER_INSTALL_DIR)/bender vendor init

check-bender:
	@if [ -x $(BENDER_INSTALL_DIR)/bender ]; then \
		req="bender $(BENDER_VERSION)"; \
		current="$$($(BENDER_INSTALL_DIR)/bender --version)"; \
		if [ "$$(printf '%s\n' "$${req}" "$${current}" | sort -V | head -n1)" != "$${req}" ]; then \
			rm -rf $(BENDER_INSTALL_DIR); \
		fi \
	fi
	@$(MAKE) -C $(ROOT_DIR) $(BENDER_INSTALL_DIR)/bender

$(BENDER_INSTALL_DIR)/bender:
	mkdir -p $(BENDER_INSTALL_DIR) && cd $(BENDER_INSTALL_DIR) && \
	curl --proto '=https' --tlsv1.2 https://pulp-platform.github.io/bender/init -sSf | sh -s -- $(BENDER_VERSION)