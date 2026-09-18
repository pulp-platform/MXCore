# Copyright 2026 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Jayanth Jonnalagadda <jjonnalagadd@iis.ee.ethz.ch>

set DEBUG ON

# Set working library.
set LIB work

if {$DEBUG == "ON"} {
    set VOPT_ARG "+acc"
    echo $VOPT_ARG
    set DB_SW "-debugdb"
} else {
    set DB_SW ""
}

quit -sim

vsim -voptargs=$VOPT_ARG $DB_SW -pedanticerrors -lib $LIB  tb_mxcore_hwpe

if {$DEBUG == "ON"} {
    add log -r /*
    do ../wave_hwpe.do
}

run -a
