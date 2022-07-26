create_ip -name axi_cdma -vendor xilinx.com -library ip -version 4.1 -module_name axi_cdma_0
set_property -dict [list CONFIG.C_INCLUDE_SF {1} CONFIG.C_INCLUDE_SG {0} CONFIG.C_ADDR_WIDTH {32}] [get_ips axi_cdma_0]
create_ip_run [get_ips axi_cdma_0]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_0
set_property -dict [list CONFIG.C_PROBE0_WIDTH {192} CONFIG.C_DATA_DEPTH {16384}] [get_ips ila_0]
create_ip_run [get_ips ila_0]

# Generate other clocks from the 100MHz input clock - nonscalable
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_gen100MHz
set_property -dict [list CONFIG.Component_Name {clk_gen100MHz} CONFIG.PRIM_SOURCE {Global_buffer} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false} CONFIG.CLKIN1_JITTER_PS {33.330000000000005} CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} CONFIG.MMCM_CLKIN1_PERIOD {3.333} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.CLKOUT1_JITTER {101.475} CONFIG.CLKOUT1_PHASE_ERROR {77.836}] [get_ips clk_gen100MHz]
set_property -dict [list CONFIG.CLKOUT2_USED {true} CONFIG.CLK_OUT1_PORT {clk100_out} CONFIG.CLK_OUT2_PORT {clk450_out} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {450.000} CONFIG.MMCM_CLKFBOUT_MULT_F {4.500} CONFIG.MMCM_CLKOUT0_DIVIDE_F {13.500} CONFIG.MMCM_CLKOUT1_DIVIDE {3} CONFIG.NUM_OUT_CLKS {2} CONFIG.CLKOUT1_JITTER {98.047} CONFIG.CLKOUT1_PHASE_ERROR {73.261} CONFIG.CLKOUT2_JITTER {73.020} CONFIG.CLKOUT2_PHASE_ERROR {73.261}] [get_ips clk_gen100MHz]
set_property -dict [list CONFIG.CLK_OUT2_PORT {clk250_out} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {250.000} CONFIG.MMCM_CLKFBOUT_MULT_F {12.500} CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.500} CONFIG.MMCM_CLKOUT1_DIVIDE {5} CONFIG.CLKOUT1_JITTER {111.970} CONFIG.CLKOUT1_PHASE_ERROR {84.520} CONFIG.CLKOUT2_JITTER {94.797} CONFIG.CLKOUT2_PHASE_ERROR {84.520}] [get_ips clk_gen100MHz]
create_ip_run [get_ips clk_gen100MHz]

# Cannot generate both 400 and 450 MHz clock from the 100MHz input clock - nonscalable
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_gen400MHz
set_property -dict [list CONFIG.Component_Name {gen_clk400} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.CLK_OUT1_PORT {clk400_out} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {400.000} CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false} CONFIG.CLKIN1_JITTER_PS {33.330000000000005} CONFIG.MMCM_CLKFBOUT_MULT_F {4.000} CONFIG.MMCM_CLKIN1_PERIOD {3.333} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.MMCM_CLKOUT0_DIVIDE_F {3.000} CONFIG.CLKOUT1_JITTER {77.334} CONFIG.CLKOUT1_PHASE_ERROR {77.836}] [get_ips clk_gen400MHz]
create_ip_run [get_ips clk_gen400MHz]

# 512 bit wide AXI register slice, 64 bit address
create_ip -name axi_register_slice -vendor xilinx.com -library ip -version 2.1 -module_name axi_reg_slice512_LLFFL
set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512} CONFIG.REG_W {1} CONFIG.Component_Name {axi_reg_slice512_LLFFL}] [get_ips axi_reg_slice512_LLFFL]
set_property -dict [list CONFIG.HAS_LOCK {0} CONFIG.HAS_CACHE {0} CONFIG.HAS_REGION {0} CONFIG.HAS_QOS {0} CONFIG.HAS_PROT {0} CONFIG.REG_AW {1} CONFIG.REG_AR {1}] [get_ips axi_reg_slice512_LLFFL]
create_ip_run [get_ips axi_reg_slice512_LLFFL]

create_ip -name axi_protocol_checker -vendor xilinx.com -library ip -version 2.0 -module_name axi_protocol_checker_512
set_property -dict [list CONFIG.DATA_WIDTH {512} CONFIG.MAX_RD_BURSTS {64} CONFIG.MAX_WR_BURSTS {32} CONFIG.MAX_CONTINUOUS_WTRANSFERS_WAITS {500} CONFIG.MAX_CONTINUOUS_RTRANSFERS_WAITS {500} CONFIG.Component_Name {axi_protocol_checker_512}] [get_ips axi_protocol_checker_512]
create_ip_run [get_ips axi_protocol_checker_512]
