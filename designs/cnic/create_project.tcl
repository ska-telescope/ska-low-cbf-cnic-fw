
set time_raw [clock seconds];
set date_string [clock format $time_raw -format "%y%m%d_%H%M%S"]

if { $env(TARGET_ALVEO) == "u55" } {
  set DEVICE "xcu55c-fsvh2892-2L-e"
  set BOARD "xilinx.com:au55c:part0:1.0"
  set CNIC_TARGET "u55"
  set VITIS_TARGET "u55"
}

if { $env(TARGET_ALVEO) == "u50" } {
  set DEVICE "xcu50-fsvh2104-2lv-e"
  set BOARD "xilinx.com:au50lv:part0:1.2"
  set CNIC_TARGET "u50"
  set VITIS_TARGET "u50"
}

set proj_dir "$env(RADIOHDL)/build/$env(PERSONALITY)/$env(PERSONALITY)_${CNIC_TARGET}_build_$date_string"
set ARGS_PATH "$env(RADIOHDL)/build/ARGS/$env(PERSONALITY)"
set DESIGN_PATH "$env(RADIOHDL)/designs/$env(PERSONALITY)"
set RLIBRARIES_PATH "$env(RADIOHDL)/libraries"
set COMMON_PATH "$env(RADIOHDL)/common/libraries"


puts "RADIOHDL directory:"
puts $env(RADIOHDL)

puts "Timeslave IP in submodule"
# RADIOHDL is ENV_VAR for current project REPO. 
set timeslave_repo "$env(RADIOHDL)/pub-timeslave/hw/cores"


# Create the new build directory
puts "Creating build_directory $proj_dir"
file mkdir $proj_dir

# This script sets the project variables
puts "Creating new project: $env(PERSONALITY)"
cd $proj_dir

set workingDir [pwd]
puts "Working directory:"
puts $workingDir

# WARNING - proj_dir must be relative to workingDir.
# But cannot be empty because args generates tcl with the directory specified as "$proj_dir/"
set proj_dir "../$env(PERSONALITY)_${CNIC_TARGET}_build_$date_string"


create_project $env(PERSONALITY) -part $DEVICE -force
set_property board_part $BOARD [current_project]
set_property target_language VHDL [current_project]
set_property target_simulator XSim [current_project]
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]

############################################################
# Board specific files
############################################################

############################################################
# ARGS generated files
############################################################

# This script uses the construct $workingDir/$proj_dir
# So $proj_dir must be relative to $workingDir
# 
source $ARGS_PATH/$env(PERSONALITY)_bd.tcl


add_files -fileset sources_1 [glob \
$ARGS_PATH/cnic_bus_pkg.vhd \
$ARGS_PATH/cnic_bus_top.vhd \
$ARGS_PATH/cnic/system/cnic_system_reg_pkg.vhd \
$ARGS_PATH/cnic/system/cnic_system_reg.vhd \
]

set_property library $env(PERSONALITY)_lib [get_files {\
*_bus_pkg.vhd \
*_bus_top.vhd \
*_system_reg_pkg.vhd \
*_system_reg.vhd \
}]

############################################################
# Design specific files
############################################################


set PERSONALITYCORE $DESIGN_PATH/src/vhdl/$env(PERSONALITY)Core.vhd
set PERSONALITYCORE_MATCH src/vhdl/$env(PERSONALITY)Core.vhd

set PERSONALITY_TB_TOP $DESIGN_PATH/src/vhdl/tb_$env(PERSONALITY)_top.vhd 
set PERSONALITY_TB_TOP_MATCH src/vhdl/tb_$env(PERSONALITY)_top.vhd 


puts $PERSONALITYCORE
puts $PERSONALITYCORE_MATCH
puts $PERSONALITY_TB_TOP
puts $PERSONALITY_TB_TOP_MATCH

add_files -fileset sources_1 [glob \
$DESIGN_PATH/src/vhdl/${VITIS_TARGET}/cnic.vhd \
$DESIGN_PATH/src/vhdl/cnic_core.vhd \
$DESIGN_PATH/src/vhdl/cdma_wrapper.vhd \
$DESIGN_PATH/src/vhdl/mac_100g_wrapper.vhd \
$DESIGN_PATH/src/vhdl/krnl_control_axi.vhd \
$DESIGN_PATH/src/vhdl/version_pkg.vhd \
]

add_files -fileset sim_1 [glob \
$DESIGN_PATH/src/tb/tb_$env(PERSONALITY).vhd \
$DESIGN_PATH/src/tb/tb_$env(PERSONALITY)_top.vhd \
$DESIGN_PATH/src/vhdl/lbus_packet_receive.vhd \
$DESIGN_PATH/src/vhdl/highLatencyRamModel.vhd \
$DESIGN_PATH/src/vhdl/HBM_axi_tbModel.vhd \
$DESIGN_PATH/src/tb/registers_tb.txt \
$DESIGN_PATH/src/tb/registers.txt \
]

set_property library $env(PERSONALITY)_lib [get_files {\
*/src/vhdl/${VITIS_TARGET}/cnic.vhd \
*/src/vhdl/cnic_core.vhd \
*/src/tb/tb_cnic.vhd \
*/src/tb/tb_cnic_top.vhd \
*/src/vhdl/lbus_packet_receive.vhd \
*/src/vhdl/cdma_wrapper.vhd \
*/src/vhdl/mac_100g_wrapper.vhd \
*/src/vhdl/krnl_control_axi.vhd \
*/src/vhdl/highLatencyRamModel.vhd \
*/src/vhdl/HBM_axi_tbModel.vhd \
*/src/vhdl/version_pkg.vhd \
*/src/tb/registers_tb.txt \
*/src/tb/registers.txt \
}]
set_property file_type {VHDL 2008} [get_files  $DESIGN_PATH/src/vhdl/highLatencyRamModel.vhd]
set_property file_type {VHDL 2008} [get_files  $DESIGN_PATH/src/vhdl/HBM_axi_tbModel.vhd]
set_property file_type {VHDL 2008} [get_files  $DESIGN_PATH/src/vhdl/${VITIS_TARGET}/cnic.vhd]
set_property file_type {VHDL 2008} [get_files  $DESIGN_PATH/src/vhdl/cnic_core.vhd]

# top level testbench
set_property top tb_cnic [get_filesets sim_1]


# tcl scripts for ip generation-
source $DESIGN_PATH/src/ip/cnic.tcl

############################################################
# Timeslave files
############################################################
set_property  ip_repo_paths  $timeslave_repo [current_project]
update_ip_catalog

# only generate this if u55.
if { ${VITIS_TARGET} == "u55" } {
  # generate_ref design - Instance 1 - U55C TOP PORT.
  source $COMMON_PATH/ptp/src/genBD_timeslave.tcl

  make_wrapper -files [get_files $workingDir/$env(PERSONALITY).srcs/sources_1/bd/ts/ts.bd] -top
  add_files -norecurse $workingDir/$env(PERSONALITY).gen/sources_1/bd/ts/hdl/ts_wrapper.vhd
}

if { ${VITIS_TARGET} == "u50" || ${VITIS_TARGET} == "u55"} {
    # generate_ref design - Instance 2, timeslave_b has equivalent CMAC GTs for U50 and U55C BOTTOM PORT.
    source $COMMON_PATH/ptp/src/genBD_timeslave_b.tcl

    make_wrapper -files [get_files $workingDir/$env(PERSONALITY).srcs/sources_1/bd/ts_b/ts_b.bd] -top
    add_files -norecurse $workingDir/$env(PERSONALITY).gen/sources_1/bd/ts_b/hdl/ts_b_wrapper.vhd
}

add_files -fileset sources_1 [glob \
 $COMMON_PATH/ptp/src/CMAC_100G_wrap_w_timeslave.vhd \
 $COMMON_PATH/ptp/src/timeslave_stats.vhd \
 $COMMON_PATH/ptp/src/timeslave_scheduler.vhd \
]
set_property library Timeslave_CMAC_lib [get_files {\
 */src/CMAC_100G_wrap_w_timeslave.vhd \
 */src/timeslave_stats.vhd \
 */src/timeslave_scheduler.vhd \
}]

add_files -fileset sources_1 [glob \
 $ARGS_PATH/CMAC/cmac/CMAC_cmac_reg_pkg.vhd \
 $ARGS_PATH/CMAC/cmac/CMAC_cmac_reg.vhd \
 $ARGS_PATH/CMAC_B/cmac_b/CMAC_B_cmac_b_reg_pkg.vhd \
 $ARGS_PATH/Timeslave/timeslave/Timeslave_timeslave_reg_pkg.vhd \
 $ARGS_PATH/Timeslave/timeslave/Timeslave_timeslave_reg.vhd \
]
set_property library Timeslave_CMAC_lib [get_files {\
 *CMAC/cmac/CMAC_cmac_reg_pkg.vhd \
 *CMAC/cmac/CMAC_cmac_reg.vhd \
 *CMAC_B/cmac_b/CMAC_B_cmac_b_reg_pkg.vhd \
 */Timeslave/timeslave/Timeslave_timeslave_reg_pkg.vhd \
 */Timeslave/timeslave/Timeslave_timeslave_reg.vhd \ 
}]

############################################################
# AXI4
add_files -fileset sources_1 [glob \
$COMMON_PATH/base/axi4/src/vhdl/axi4_lite_pkg.vhd \
$COMMON_PATH/base/axi4/src/vhdl/axi4_full_pkg.vhd \
$COMMON_PATH/base/axi4/src/vhdl/axi4_stream_pkg.vhd \
$COMMON_PATH/base/axi4/src/vhdl/mem_to_axi4_lite.vhd \
]
set_property library axi4_lib [get_files {\
*libraries/base/axi4/src/vhdl/axi4_lite_pkg.vhd \
*libraries/base/axi4/src/vhdl/axi4_full_pkg.vhd \
*libraries/base/axi4/src/vhdl/axi4_stream_pkg.vhd \
*libraries/base/axi4/src/vhdl/mem_to_axi4_lite.vhd \
}]

# Technology select package
add_files -fileset sources_1 [glob \
 $RLIBRARIES_PATH/technology/technology_pkg.vhd \
 $RLIBRARIES_PATH/technology/technology_select_pkg.vhd \
 $RLIBRARIES_PATH/technology/mac_100g/tech_mac_100g_pkg.vhd \
]
set_property library technology_lib [get_files {\
 *libraries/technology/technology_pkg.vhd \
 *libraries/technology/technology_select_pkg.vhd \
 *libraries/technology/mac_100g/tech_mac_100g_pkg.vhd \
}]
# #############################################################
# # Common
 add_files -fileset sources_1 [glob \
  $COMMON_PATH/base/common/src/vhdl/common_reg_r_w.vhd \
  $COMMON_PATH/base/common/src/vhdl/common_pkg.vhd \
  $COMMON_PATH/base/common/src/vhdl/common_str_pkg.vhd \
  $COMMON_PATH/base/common/src/vhdl/common_mem_pkg.vhd \
  $COMMON_PATH/base/common/src/vhdl/common_field_pkg.vhd \
  $COMMON_PATH/base/common/src/vhdl/common_accumulate.vhd\
  $COMMON_PATH/base/common/src/vhdl/common_pipeline.vhd \

 ]

set_property library common_lib [get_files {\
  *libraries/base/common/src/vhdl/common_reg_r_w.vhd \
  *libraries/base/common/src/vhdl/common_pkg.vhd \
  *libraries/base/common/src/vhdl/common_str_pkg.vhd \
  *libraries/base/common/src/vhdl/common_mem_pkg.vhd \
  *libraries/base/common/src/vhdl/common_field_pkg.vhd \
  *libraries/base/common/src/vhdl/common_accumulate.vhd \
  *libraries/base/common/src/vhdl/common_pipeline.vhd \
}]

#############################################################
# DRP

add_files -fileset sources_1 [glob \
 $ARGS_PATH/DRP/drp/DRP_drp_reg_pkg.vhd \
 $ARGS_PATH/DRP/drp/DRP_drp_reg.vhd \
]
set_property library DRP_lib [get_files {\
 *DRP/drp/DRP_drp_reg_pkg.vhd \
 *DRP/drp/DRP_drp_reg.vhd \
}]

#############################################################
# tech memory
# (Used by ARGs)
add_files -fileset sources_1 [glob \
 $RLIBRARIES_PATH/technology/memory/tech_memory_component_pkg.vhd \
]
set_property library tech_memory_lib [get_files {\
 *libraries/technology/memory/tech_memory_component_pkg.vhd \
}]

#############################################################
# HBM_PktController
add_files -fileset sources_1 [glob \
  $ARGS_PATH/ct_atomic_pst_in/ct_atomic_pst_in/ct_atomic_pst_in_reg_pkg.vhd \
  $ARGS_PATH/HBM_PktController/hbm_pktcontroller/HBM_PktController_hbm_pktcontroller_reg_pkg.vhd \
  $ARGS_PATH/HBM_PktController/hbm_pktcontroller/HBM_PktController_hbm_pktcontroller_reg.vhd \
  $RLIBRARIES_PATH/signalProcessing/HBM_PktController/HBM_PktController.vhd \
]

set_property library HBM_PktController_lib [get_files {\
 *hbm_pktcontroller/HBM_PktController_hbm_pktcontroller_reg_pkg.vhd \
 *hbm_pktcontroller/HBM_PktController_hbm_pktcontroller_reg.vhd \
 *libraries/signalProcessing/HBM_PktController/HBM_PktController.vhd \
 }]
source $RLIBRARIES_PATH/signalProcessing/HBM_PktController/HBM_PktController.tcl
set_property file_type {VHDL 2008} [get_files  $RLIBRARIES_PATH/signalProcessing/HBM_PktController/HBM_PktController.vhd]


#############################################################
# PSR Packetiser
add_files -fileset sources_1 [glob \
 $COMMON_PATH/Packetiser100G/src/vhdl/ethernet_pkg.vhd \
 $COMMON_PATH/Packetiser100G/src/vhdl/cbfpsrheader_pkg.vhd \
 $COMMON_PATH/Packetiser100G/src/vhdl/packet_player.vhd \
 $COMMON_PATH/Packetiser100G/src/vhdl/xpm_fifo_wrapper.vhd \
 $COMMON_PATH/Packetiser100G/src/vhdl/CODIF_header_modifier.vhd \
]
set_property library PSR_Packetiser_lib [get_files {\
 */Packetiser100G/src/vhdl/ethernet_pkg.vhd \
 */Packetiser100G/src/vhdl/cbfpsrheader_pkg.vhd \
 */Packetiser100G/src/vhdl/packet_player.vhd \
 */Packetiser100G/src/vhdl/xpm_fifo_wrapper.vhd \
 */Packetiser100G/src/vhdl/CODIF_header_modifier.vhd \
}]

#############################################################
# S AXI capture
add_files -fileset sources_1 [glob \
 $RLIBRARIES_PATH/signalProcessing/s_axi_packet_capture/vhdl/s_axi_packet_capture.vhd
]
set_property library cmac_s_axi_lib [get_files {\
 *libraries/signalProcessing/s_axi_packet_capture/vhdl/s_axi_packet_capture.vhd
}]
set_property file_type {VHDL 2008} [get_files  $RLIBRARIES_PATH/signalProcessing/s_axi_packet_capture/vhdl/s_axi_packet_capture.vhd]

#############################################################
# Signal_processing_common

add_files -fileset sources_1 [glob \
 $COMMON_PATH/common/src/vhdl/sync.vhd \
 $COMMON_PATH/common/src/vhdl/sync_vector.vhd \
 $COMMON_PATH/common/src/vhdl/memory_dp_wrapper.vhd \
 $COMMON_PATH/common/src/vhdl/args_axi_terminus.vhd \
]
set_property library signal_processing_common [get_files {\
 */common/src/vhdl/sync.vhd \
 */common/src/vhdl/sync_vector.vhd \
 */common/src/vhdl/memory_dp_wrapper.vhd \
 */common/src/vhdl/args_axi_terminus.vhd \
}]

## tcl scripts for ip generation
#source $ARGS_PATH/Packetiser/packetiser/ip_Packetiser_packetiser_param_ram.tcl

#############################################################
# $PERSONALITY Top level
add_files -fileset sources_1 [glob \
 $RLIBRARIES_PATH/signalProcessing/$env(PERSONALITY)_top/src/vhdl/$env(PERSONALITY)_top.vhd \
 $RLIBRARIES_PATH/signalProcessing/$env(PERSONALITY)_top/src/vhdl/$env(PERSONALITY)_top_pkg.vhd \
]
set_property library $env(PERSONALITY)_lib [get_files  {\
 *libraries/signalProcessing/cnic_top/src/vhdl/cnic_top.vhd \
 *libraries/signalProcessing/cnic_top/src/vhdl/cnic_top_pkg.vhd \
}]
# set_property library $PERSONALITY_top_lib [get_files  {\
#  *libraries/signalProcessing/$env(PERSONALITY)_top/src/vhdl/$env(PERSONALITY)_top.vhd \
#  *libraries/signalProcessing/$env(PERSONALITY)_top/src/vhdl/$env(PERSONALITY)_top_pkg.vhd \
# }]

set_property file_type {VHDL 2008} [get_files  *libraries/signalProcessing/$env(PERSONALITY)_top/src/vhdl/$env(PERSONALITY)_top.vhd]


##############################################################
# Set top
add_files -fileset constrs_1 -norecurse $DESIGN_PATH/src/constraints/cnic_${VITIS_TARGET}_constraints.xdc
set_property PROCESSING_ORDER LATE [get_files cnic_${VITIS_TARGET}_constraints.xdc]

set_property -name {xsim.compile.xvlog.more_options} -value {-d SIM_SPEED_UP} -objects [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property top cnic [current_fileset]
update_compile_order -fileset sources_1
#update_compile_order -fileset sim_1


##############################################################
# Add the waveform files to the simulation 
add_files -fileset sim_1 -norecurse $DESIGN_PATH/src/tb/tb_cnic_behav.wcfg
set_property xsim.view $DESIGN_PATH/src/tb/tb_cnic_behav.wcfg [get_filesets sim_1]


##############################################################
# Add simulation set for S-AXI_100G Capture

create_fileset -simset sim_s_axi_cap
set_property SOURCE_SET sources_1 [get_filesets sim_s_axi_cap]
add_files -fileset sim_s_axi_cap [glob \
   $RLIBRARIES_PATH/signalProcessing/s_axi_packet_capture/tb/tb_s_axi.vhd
]
set_property top tb_s_axi [get_filesets sim_s_axi_cap]
set_property top_lib xil_defaultlib [get_filesets sim_s_axi_cap]
update_compile_order -fileset sim_s_axi_cap
