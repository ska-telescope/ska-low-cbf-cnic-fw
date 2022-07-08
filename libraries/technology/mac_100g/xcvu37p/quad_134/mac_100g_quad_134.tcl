set componentName mac_100g_quad_134
create_ip -name cmac_usplus -vendor xilinx.com -library ip -module_name $componentName
set_property -dict [list CONFIG.CMAC_CAUI4_MODE {1} CONFIG.NUM_LANES {4} CONFIG.GT_REF_CLK_FREQ {156.25} CONFIG.GT_DRP_CLK {125} CONFIG.TX_FLOW_CONTROL {0} CONFIG.RX_FLOW_CONTROL {0} CONFIG.RX_PROCESS_LFI {1} CONFIG.INCLUDE_RS_FEC {1} CONFIG.CMAC_CORE_SELECT {CMACE4_X0Y5} CONFIG.GT_GROUP_SELECT {X0Y40~X0Y43} CONFIG.LANE1_GT_LOC {X0Y40} CONFIG.LANE2_GT_LOC {X0Y41} CONFIG.LANE3_GT_LOC {X0Y42} CONFIG.LANE4_GT_LOC {X0Y43} CONFIG.LANE5_GT_LOC {NA} CONFIG.LANE6_GT_LOC {NA} CONFIG.LANE7_GT_LOC {NA} CONFIG.LANE8_GT_LOC {NA} CONFIG.LANE9_GT_LOC {NA} CONFIG.LANE10_GT_LOC {NA} CONFIG.ENABLE_PIPELINE_REG {1} CONFIG.ADD_GT_CNRL_STS_PORTS {1} ] [get_ips $componentName]
source $env(RADIOHDL)/libraries/technology/build_ip.tcl