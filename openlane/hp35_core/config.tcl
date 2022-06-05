# SPDX-FileCopyrightText: 2022 AnalogMiko 
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

set script_dir [file dirname [file normalize [info script]]]
set ::env(ROUTING_CORES) "4"
set ::env(PDK) "sky130A"
set ::env(STD_CELL_LIBRARY) "sky130_fd_sc_hd"

set ::env(DESIGN_NAME) hp35_core
set ::env(DESIGN_IS_CORE) 0

set ::env(VERILOG_FILES) "\
	$::env(CARAVEL_ROOT)/verilog/rtl/defines.v \
	$script_dir/../../verilog/rtl/patently-obvious/*.v"

## Internal Macros
#set ::env(VERILOG_FILES_BLACKBOX) "\
#	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/verilog/sky130_sram_1kbyte_1rw1r_32x256_8.v"
#set ::env(EXTRA_LEFS) "\
#	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lef/sky130_sram_1kbyte_1rw1r_32x256_8.lef"
#set ::env(EXTRA_GDS_FILES) "\
#	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/gds/sky130_sram_1kbyte_1rw1r_32x256_8.gds"
#set ::env(EXTRA_LIBS) "\
#	$::env(PDK_ROOT)/sky130A/libs.ref/sky130_sram_macros/lib/sky130_sram_1kbyte_1rw1r_32x256_8_TT_1p8V_25C.lib"

set ::env(CLOCK_PORT) "osc_in"
set ::env(CLOCK_NET)  "osc_in"
set ::env(CLOCK_PERIOD) "10"

set ::env(RESET_PORT) "POR"

## Synthesis
set ::env(SYNTH_STRATEGY) "DELAY 0"
set ::env(SYNTH_MAX_FANOUT) 8
set ::env(SYNTH_READ_BLACKBOX_LIB) 1

## Floorplan
set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg
set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 500 1500"

set ::env(PL_TARGET_DENSITY) 0.15
set ::env(CELL_PAD) 0
# set ::env(PL_BASIC_PLACEMENT) 1

## PDN


## CTS
set ::env(CTS_CLK_BUFFER_LIST) "sky130_fd_sc_hd__clkbuf_4 sky130_fd_sc_hd__clkbuf_8 sky130_fd_sc_hd__clkbuf_16"
set ::env(CTS_SINK_CLUSTERING_MAX_DIAMETER) 50
set ::env(CTS_SINK_CLUSTERING_SIZE) 20

## Placement
set ::env(PL_RESIZER_DESIGN_OPTIMIZATIONS) 1
set ::env(PL_RESIZER_TIMING_OPTIMIZATIONS) 1

set ::env(PL_RESIZER_MAX_SLEW_MARGIN) 2
set ::env(PL_RESIZER_MAX_CAP_MARGIN) 2

## Routing

# Maximum layer used for routing is metal 4.
# This is because this macro will be inserted in a top level (user_project_wrapper) 
# where the PDN is planned on metal 5. So, to avoid having shorts between routes
# in this macro and the top level metal 5 stripes, we have to restrict routes to metal4.  
# 
# set ::env(GLB_RT_MAXLAYER) 5
set ::env(RT_MAX_LAYER) {met5}
# Repairing Global Routing Failureset ::env(GLB_RT_ADJUSTMENT) 0
set ::env(GLB_RT_L2_ADJUSTMENT) 0.21
set ::env(GLB_RT_L3_ADJUSTMENT) 0.21
set ::env(GLB_RT_L4_ADJUSTMENT) 0.1
# set ::env(GLB_RT_ALLOW_CONGESTION) 0
# set ::env(GLB_RT_OVERFLOW_ITERS) 200
set ::env(PL_RESIZER_HOLD_SLACK_MARGIN) 0.15
set ::env(GLB_RESIZER_TIMING_OPTIMIZATIONS) 1
set ::env(GLB_RESIZER_HOLD_SLACK_MARGIN) 0.3

# You can draw more power domains if you need to 
set ::env(VDD_NETS) [list {vccd1}]
set ::env(GND_NETS) [list {vssd1}]
# If you're going to use multiple power domains, then disable cvc run.
set ::env(RUN_CVC) 1

## Diode Insertion
set ::env(DIODE_INSERTION_STRATEGY) 4 

