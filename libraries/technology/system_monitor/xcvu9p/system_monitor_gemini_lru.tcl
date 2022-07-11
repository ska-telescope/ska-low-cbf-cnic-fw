set componentName system_monitor_gemini_lru
create_ip -name system_management_wiz -vendor xilinx.com -library ip -version 1.3 -module_name $componentName
set_property -dict [list CONFIG.INTERFACE_SELECTION {Enable_AXI} CONFIG.DCLK_FREQUENCY {156.25} CONFIG.ENABLE_RESET {false} CONFIG.ENABLE_VBRAM_ALARM {true} CONFIG.CHANNEL_AVERAGING {16} CONFIG.AVERAGE_ENABLE_VBRAM {true} CONFIG.AVERAGE_ENABLE_TEMPERATURE {true} CONFIG.AVERAGE_ENABLE_VCCINT {true} CONFIG.AVERAGE_ENABLE_VCCAUX {true} CONFIG.ENABLE_TEMP_BUS {true}] [get_ips $componentName]
source $env(RADIOHDL)/libraries/technology/build_ip.tcl