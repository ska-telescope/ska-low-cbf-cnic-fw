----------------------------------------------------------------------------------
-- Company: CSIRO  
-- Engineer: Giles Babich
-- 
-- Create Date: 11.01.2022
-- Module Name: 100G_wrap_timeslave - rtl
-- Project Name: 
-- Target Devices: +US 
-- Tool Versions: 2021.2
-- Description: 
-- 
-- 
-- DATA format for Streaming AXI byte layout of an Ethernet Frame.
--  dst_mac  <= CMAC_rx_axis_tdata(7 downto 0) & CMAC_rx_axis_tdata(15 downto 8) & CMAC_rx_axis_tdata(23 downto 16) & CMAC_rx_axis_tdata(31 downto 24) & CMAC_rx_axis_tdata(39 downto 32) & CMAC_rx_axis_tdata(47 downto 40);
--  src_mac  <= CMAC_rx_axis_tdata(55 downto 48) & CMAC_rx_axis_tdata(63 downto 56) & CMAC_rx_axis_tdata(71 downto 64) & CMAC_rx_axis_tdata(79 downto 72) & CMAC_rx_axis_tdata(87 downto 80) & CMAC_rx_axis_tdata(95 downto 88);
--  eth_type <= CMAC_rx_axis_tdata(103 downto 96) & CMAC_rx_axis_tdata(111 downto 104);
--  ptp_type <= CMAC_rx_axis_tdata(119 downto 112);
--  ETC ...
-- 
--    This wrapper generates the appropriate CMAC and GT arrangement in a Timeslave block design based upon generics.
--    U50 and U55C share CMAC and GT silicon locations.
--    
--    The ts_wrapper is based on the example design that is provided by that IP repo. Heavily modified for use ALVEO kernel.
--    The wrapper contains the Timeslave IP, CMAC Xilinx IP and AXI clock domain crossing to run the uBlaze in the IP at a slower rate than ARGs.
--    
--    Outside of this block there are various statistics counters that take the indicators from the CMAC block to generate counters.
--    These are provided to ARGs.
--    
--    Timeslave IP is controlled by the AXI vectors; 
--        i_Timeslave_Full_axi_mosi       : in  t_axi4_full_mosi;
--        o_Timeslave_Full_axi_miso       : out t_axi4_full_miso
--    the documentation for the various sub timeslave modules available through this address space is in the IP repo.
--    A more detailed document is also available. 
--       
----------------------------------------------------------------------------------


library IEEE, axi4_lib, technology_lib, common_lib, signal_processing_common, Timeslave_CMAC_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE axi4_lib.axi4_stream_pkg.ALL;
USE technology_lib.tech_mac_100g_pkg.ALL;
USE common_lib.common_pkg.ALL;
use IEEE.NUMERIC_STD.ALL;

use axi4_lib.axi4_lite_pkg.ALL;
USE axi4_lib.axi4_full_pkg.ALL;
USE Timeslave_CMAC_lib.CMAC_cmac_reg_pkg.ALL;


entity CMAC_100G_wrap_w_timeslave is
    generic (
        DEBUG_ILA               : BOOLEAN := FALSE;
        U55_TOP_QSFP            : BOOLEAN := FALSE;         --
        U55_BOTTOM_QSFP         : BOOLEAN := FALSE          -- THIS CONFIG IS VALID FOR U50 as well.
    
    );
    Port(
        gt_rxp_in               : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        gt_rxn_in               : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        gt_txp_out              : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gt_txn_out              : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        gt_refclk_p             : IN STD_LOGIC;
        gt_refclk_n             : IN STD_LOGIC;
        sys_reset               : IN STD_LOGIC;   -- sys_reset, clocked by dclk.
        i_dclk_100              : IN STD_LOGIC;                     -- stable clock for the core; 300Mhz from kernel -> PLL -> 100 Mhz

        -- loopback for the GTYs
        -- "000" = normal operation, "001" = near-end PCS loopback, "010" = near-end PMA loopback
        -- "100" = far-end PMA loopback, "110" = far-end PCS loopback.
        -- See GTY user guid (Xilinx doc UG578) for details.
--        loopback                : IN STD_LOGIC_VECTOR(2 DOWNTO 0);  
--        tx_enable               : IN STD_LOGIC;
--        rx_enable               : IN STD_LOGIC;
        
        i_fec_enable            : IN STD_LOGIC;

        tx_clk_out              : OUT STD_LOGIC;                   -- Should be driven by one of the tx_clk_outs

        -- User Interface Signals
        rx_locked               : OUT STD_LOGIC;

        user_rx_reset           : OUT STD_LOGIC;                    -- NOT USED 
        user_tx_reset           : OUT STD_LOGIC;                    -- NOT USED

        -- Statistics Interface
        rx_total_packets        : out std_logic_vector(31 downto 0);
        rx_bad_fcs              : out std_logic_vector(31 downto 0);
        rx_bad_code             : out std_logic_vector(31 downto 0);
        tx_total_packets        : out std_logic_vector(31 downto 0);

        -----------------------------------------------------------------------
        -- streaming AXI to CMAC
        -- TX
        i_tx_axis_tdata         : IN STD_LOGIC_VECTOR(511 downto 0);
        i_tx_axis_tkeep         : IN STD_LOGIC_VECTOR(63 downto 0);
        i_tx_axis_tvalid        : IN STD_LOGIC;
        i_tx_axis_tlast         : IN STD_LOGIC;
        i_tx_axis_tuser         : IN STD_LOGIC;
        o_tx_axis_tready        : OUT STD_LOGIC;
        
        -- RX
        o_rx_axis_tdata         : out STD_LOGIC_VECTOR ( 511 downto 0 );
        o_rx_axis_tkeep         : out STD_LOGIC_VECTOR ( 63 downto 0 );
        o_rx_axis_tlast         : out STD_LOGIC;
        i_rx_axis_tready        : in STD_LOGIC;
        o_rx_axis_tuser         : out STD_LOGIC_VECTOR ( 79 downto 0 );
        o_rx_axis_tvalid        : out STD_LOGIC;
        
        -----------------------------------------------------------------------
        
        -- PTP Data
        PTP_time_CMAC_clk       : out std_logic_vector(79 downto 0);
        PTP_pps_CMAC_clk        : out std_logic;
        
        PTP_time_ARGs_clk       : out std_logic_vector(79 downto 0);
        PTP_pps_ARGs_clk        : out std_logic;
        
        -- ARGS DRP interface
        i_ARGs_clk                      : in std_logic;
        i_ARGs_rst                      : in std_logic;
        i_CMAC_Lite_axi_mosi            : in t_axi4_lite_mosi; 
        o_CMAC_Lite_axi_miso            : out t_axi4_lite_miso;
        
        i_Timeslave_Full_axi_mosi       : in  t_axi4_full_mosi;
        o_Timeslave_Full_axi_miso       : out t_axi4_full_miso
        
    );
end CMAC_100G_wrap_w_timeslave;

architecture rtl of CMAC_100G_wrap_w_timeslave is

component ts_wrapper 
    port (
        CMAC_Clk : out STD_LOGIC;
        CMAC_Master_reset : in STD_LOGIC;
        CMAC_ctl_rx_enable : in STD_LOGIC;
        CMAC_ctl_tx_enable : in STD_LOGIC;
        CMAC_ctl_tx_lfi : in STD_LOGIC;
        CMAC_ctl_tx_rfi : in STD_LOGIC;
        CMAC_rx_axis_tdata : out STD_LOGIC_VECTOR ( 511 downto 0 );
        CMAC_rx_axis_tkeep : out STD_LOGIC_VECTOR ( 63 downto 0 );
        CMAC_rx_axis_tlast : out STD_LOGIC;
        CMAC_rx_axis_tuser : out STD_LOGIC;
        CMAC_rx_axis_tvalid : out STD_LOGIC;
        CMAC_rx_local_fault : out STD_LOGIC;
        CMAC_rx_locked : out STD_LOGIC;
        CMAC_rx_ptp_stamp : out STD_LOGIC_VECTOR ( 79 downto 0 );
        CMAC_tx_ptp_stamp : out STD_LOGIC_VECTOR ( 79 downto 0 );
        CMAC_usr_tx_reset : out STD_LOGIC;
        RX_100G_m_axis_tdata : out STD_LOGIC_VECTOR ( 511 downto 0 );
        RX_100G_m_axis_tkeep : out STD_LOGIC_VECTOR ( 63 downto 0 );
        RX_100G_m_axis_tlast : out STD_LOGIC;
        RX_100G_m_axis_tready : in STD_LOGIC;
        RX_100G_m_axis_tuser : out STD_LOGIC_VECTOR ( 79 downto 0 );
        RX_100G_m_axis_tvalid : out STD_LOGIC;
        TX_100G_s_axis_tdata : in STD_LOGIC_VECTOR ( 511 downto 0 );
        TX_100G_s_axis_tkeep : in STD_LOGIC_VECTOR ( 63 downto 0 );
        TX_100G_s_axis_tlast : in STD_LOGIC;
        TX_100G_s_axis_tready : out STD_LOGIC;
        TX_100G_s_axis_tuser : in STD_LOGIC;
        TX_100G_s_axis_tvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_aclk : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_araddr : in STD_LOGIC_VECTOR ( 17 downto 0 );
        Timeslave_ctrl_AXI_S_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_aresetn : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_arid : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_arlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
        Timeslave_ctrl_AXI_S_arlock : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_arready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_arregion : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_arvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_awaddr : in STD_LOGIC_VECTOR ( 17 downto 0 );
        Timeslave_ctrl_AXI_S_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awid : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_awlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
        Timeslave_ctrl_AXI_S_awlock : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_awregion : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_awvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_bid : out STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_bready : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_bvalid : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
        Timeslave_ctrl_AXI_S_rid : out STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_rlast : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_rready : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_rvalid : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
        Timeslave_ctrl_AXI_S_wlast : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_wready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_wvalid : in STD_LOGIC;
        Timeslave_ctrl_slw_clk : in STD_LOGIC;
        Timeslave_ctrl_slw_clk_aresetn : in STD_LOGIC;
        clk_100MHz : in STD_LOGIC;
        clk_100_reset : in STD_LOGIC;
        clk_b : in STD_LOGIC;
        gt_grx_n : in STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_grx_p : in STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_gtx_n : out STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_gtx_p : out STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_loopback_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
        gt_ref_clk_n : in STD_LOGIC;
        gt_ref_clk_p : in STD_LOGIC;
        now : out STD_LOGIC_VECTOR ( 79 downto 0 );
        now_clk_b : out STD_LOGIC_VECTOR ( 79 downto 0 );
        pps : out STD_LOGIC;
        pps_clk_b : out STD_LOGIC;
        stat_rx_bad_code : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_bad_fcs : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_bad_preamble : out STD_LOGIC;
        stat_rx_bad_sfd : out STD_LOGIC;
        stat_rx_broadcast : out STD_LOGIC;
        stat_rx_fragment : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_multicast : out STD_LOGIC;
        stat_rx_oversize : out STD_LOGIC;
        stat_rx_packet_1024_1518_bytes : out STD_LOGIC;
        stat_rx_packet_128_255_bytes : out STD_LOGIC;
        stat_rx_packet_1519_1522_bytes : out STD_LOGIC;
        stat_rx_packet_1523_1548_bytes : out STD_LOGIC;
        stat_rx_packet_1549_2047_bytes : out STD_LOGIC;
        stat_rx_packet_2048_4095_bytes : out STD_LOGIC;
        stat_rx_packet_256_511_bytes : out STD_LOGIC;
        stat_rx_packet_4096_8191_bytes : out STD_LOGIC;
        stat_rx_packet_512_1023_bytes : out STD_LOGIC;
        stat_rx_packet_64_bytes : out STD_LOGIC;
        stat_rx_packet_65_127_bytes : out STD_LOGIC;
        stat_rx_packet_8192_9215_bytes : out STD_LOGIC;
        stat_rx_packet_bad_fcs : out STD_LOGIC;
        stat_rx_packet_large : out STD_LOGIC;
        stat_rx_packet_small : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_stomped_fcs : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_toolong : out STD_LOGIC;
        stat_rx_total_good_packets : out STD_LOGIC;
        stat_rx_total_packets : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_undersize : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_unicast : out STD_LOGIC;
        stat_tx_total_good_packets : out STD_LOGIC;
        stat_tx_total_packets : out STD_LOGIC
    );
end component;

component ts_b_wrapper
    port (
        CMAC_Clk : out STD_LOGIC;
        CMAC_Master_reset : in STD_LOGIC;
        CMAC_ctl_rx_enable : in STD_LOGIC;
        CMAC_ctl_tx_enable : in STD_LOGIC;
        CMAC_ctl_tx_lfi : in STD_LOGIC;
        CMAC_ctl_tx_rfi : in STD_LOGIC;
        CMAC_rx_axis_tdata : out STD_LOGIC_VECTOR ( 511 downto 0 );
        CMAC_rx_axis_tkeep : out STD_LOGIC_VECTOR ( 63 downto 0 );
        CMAC_rx_axis_tlast : out STD_LOGIC;
        CMAC_rx_axis_tuser : out STD_LOGIC;
        CMAC_rx_axis_tvalid : out STD_LOGIC;
        CMAC_rx_local_fault : out STD_LOGIC;
        CMAC_rx_locked : out STD_LOGIC;
        CMAC_rx_ptp_stamp : out STD_LOGIC_VECTOR ( 79 downto 0 );
        CMAC_tx_ptp_stamp : out STD_LOGIC_VECTOR ( 79 downto 0 );
        CMAC_usr_tx_reset : out STD_LOGIC;
        RX_100G_m_axis_tdata : out STD_LOGIC_VECTOR ( 511 downto 0 );
        RX_100G_m_axis_tkeep : out STD_LOGIC_VECTOR ( 63 downto 0 );
        RX_100G_m_axis_tlast : out STD_LOGIC;
        RX_100G_m_axis_tready : in STD_LOGIC;
        RX_100G_m_axis_tuser : out STD_LOGIC_VECTOR ( 79 downto 0 );
        RX_100G_m_axis_tvalid : out STD_LOGIC;
        TX_100G_s_axis_tdata : in STD_LOGIC_VECTOR ( 511 downto 0 );
        TX_100G_s_axis_tkeep : in STD_LOGIC_VECTOR ( 63 downto 0 );
        TX_100G_s_axis_tlast : in STD_LOGIC;
        TX_100G_s_axis_tready : out STD_LOGIC;
        TX_100G_s_axis_tuser : in STD_LOGIC;
        TX_100G_s_axis_tvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_aclk : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_araddr : in STD_LOGIC_VECTOR ( 17 downto 0 );
        Timeslave_ctrl_AXI_S_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_aresetn : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_arid : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_arlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
        Timeslave_ctrl_AXI_S_arlock : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_arready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_arregion : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_arvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_awaddr : in STD_LOGIC_VECTOR ( 17 downto 0 );
        Timeslave_ctrl_AXI_S_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awid : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_awlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
        Timeslave_ctrl_AXI_S_awlock : in STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_awregion : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
        Timeslave_ctrl_AXI_S_awvalid : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_bid : out STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_bready : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_bvalid : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
        Timeslave_ctrl_AXI_S_rid : out STD_LOGIC_VECTOR ( 0 to 0 );
        Timeslave_ctrl_AXI_S_rlast : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_rready : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
        Timeslave_ctrl_AXI_S_rvalid : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
        Timeslave_ctrl_AXI_S_wlast : in STD_LOGIC;
        Timeslave_ctrl_AXI_S_wready : out STD_LOGIC;
        Timeslave_ctrl_AXI_S_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Timeslave_ctrl_AXI_S_wvalid : in STD_LOGIC;
        Timeslave_ctrl_slw_clk : in STD_LOGIC;
        Timeslave_ctrl_slw_clk_aresetn : in STD_LOGIC;
        clk_100MHz : in STD_LOGIC;
        clk_100_reset : in STD_LOGIC;
        clk_b : in STD_LOGIC;
        gt_grx_n : in STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_grx_p : in STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_gtx_n : out STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_gtx_p : out STD_LOGIC_VECTOR ( 3 downto 0 );
        gt_loopback_in : in STD_LOGIC_VECTOR ( 11 downto 0 );
        gt_ref_clk_n : in STD_LOGIC;
        gt_ref_clk_p : in STD_LOGIC;
        now : out STD_LOGIC_VECTOR ( 79 downto 0 );
        now_clk_b : out STD_LOGIC_VECTOR ( 79 downto 0 );
        pps : out STD_LOGIC;
        pps_clk_b : out STD_LOGIC;
        stat_rx_bad_code : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_bad_fcs : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_bad_preamble : out STD_LOGIC;
        stat_rx_bad_sfd : out STD_LOGIC;
        stat_rx_broadcast : out STD_LOGIC;
        stat_rx_fragment : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_multicast : out STD_LOGIC;
        stat_rx_oversize : out STD_LOGIC;
        stat_rx_packet_1024_1518_bytes : out STD_LOGIC;
        stat_rx_packet_128_255_bytes : out STD_LOGIC;
        stat_rx_packet_1519_1522_bytes : out STD_LOGIC;
        stat_rx_packet_1523_1548_bytes : out STD_LOGIC;
        stat_rx_packet_1549_2047_bytes : out STD_LOGIC;
        stat_rx_packet_2048_4095_bytes : out STD_LOGIC;
        stat_rx_packet_256_511_bytes : out STD_LOGIC;
        stat_rx_packet_4096_8191_bytes : out STD_LOGIC;
        stat_rx_packet_512_1023_bytes : out STD_LOGIC;
        stat_rx_packet_64_bytes : out STD_LOGIC;
        stat_rx_packet_65_127_bytes : out STD_LOGIC;
        stat_rx_packet_8192_9215_bytes : out STD_LOGIC;
        stat_rx_packet_bad_fcs : out STD_LOGIC;
        stat_rx_packet_large : out STD_LOGIC;
        stat_rx_packet_small : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_stomped_fcs : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_toolong : out STD_LOGIC;
        stat_rx_total_good_packets : out STD_LOGIC;
        stat_rx_total_packets : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_undersize : out STD_LOGIC_VECTOR ( 2 downto 0 );
        stat_rx_unicast : out STD_LOGIC;
        stat_tx_total_good_packets : out STD_LOGIC;
        stat_tx_total_packets : out STD_LOGIC
    );
end component;  

COMPONENT ila_0
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
END COMPONENT;

signal stat_rx_total_bytes              : std_logic_vector(6 downto 0);  -- unused at present.
signal stat_rx_total_packets            : std_logic_vector(2 downto 0);    -- Total RX packets
signal stat_rx_total_good_packets		: std_logic;    
signal stat_rx_packet_bad_fcs           : std_logic;                       -- Bad checksums
signal stat_rx_packet_64_bytes		    : std_logic;
signal stat_rx_packet_65_127_bytes	    : std_logic;
signal stat_rx_packet_128_255_bytes	    : std_logic;
signal stat_rx_packet_256_511_bytes	    : std_logic;
signal stat_rx_packet_512_1023_bytes	: std_logic;
signal stat_rx_packet_1024_1518_bytes	: std_logic;
signal stat_rx_packet_1519_1522_bytes	: std_logic;
signal stat_rx_packet_1523_1548_bytes	: std_logic;
signal stat_rx_packet_1549_2047_bytes	: std_logic;
signal stat_rx_packet_2048_4095_bytes	: std_logic;
signal stat_rx_packet_4096_8191_bytes	: std_logic;
signal stat_rx_packet_8192_9215_bytes	: std_logic;
signal stat_rx_packet_small             : std_logic_vector(2 downto 0);
signal stat_rx_packet_large             : std_logic;
signal stat_rx_unicast                  : std_logic;
signal stat_rx_multicast				: std_logic;
signal stat_rx_broadcast				: std_logic;
signal stat_rx_oversize				    : std_logic;
signal stat_rx_toolong                  : std_logic;    
signal stat_rx_undersize				: std_logic_vector(2 downto 0);
signal stat_rx_fragment				    : std_logic_vector(2 downto 0);
signal stat_rx_bad_code                 : std_logic_vector(2 downto 0);    -- Bit errors on the line
signal stat_rx_bad_sfd                  : std_logic;
signal stat_rx_bad_preamble             : std_logic;  
signal stat_rx_stomped_fcs              : STD_LOGIC_VECTOR ( 2 downto 0 );
signal stat_rx_bad_fcs                  : STD_LOGIC_VECTOR ( 2 downto 0 );
signal stat_tx_total_good_packets       : STD_LOGIC;
signal stat_tx_total_packets            : STD_LOGIC;  

constant STAT_REGISTERS                 : integer := 31;

constant POST_STAT_REGISTERS            : integer := 31;

signal stats_count                      : t_slv_32_arr(0 to (STAT_REGISTERS-1));
signal stats_increment                  : t_slv_3_arr(0 to (STAT_REGISTERS-1));

signal stats_to_host_data_out           : t_slv_32_arr(0 to (STAT_REGISTERS-1));

signal stat_tx_total_bytes              : std_logic_vector(5 downto 0);
signal stat_tx_increment                : t_slv_1_arr(0 to 0);
signal stat_tx_count                    : t_slv_32_arr(0 to 0);

signal cmac_stats_rw_registers          : t_cmac_stats_interface_rw;
signal cmac_stats_ro_registers          : t_cmac_stats_interface_ro;

signal CMAC_Clk : STD_LOGIC;

signal CMAC_ctl_rx_enable   : STD_LOGIC;
signal CMAC_ctl_tx_enable   : STD_LOGIC;
signal CMAC_ctl_tx_lfi      : STD_LOGIC;
signal CMAC_ctl_tx_rfi      : STD_LOGIC;
signal CMAC_rx_locked       : STD_LOGIC;
signal CMAC_usr_tx_reset    : STD_LOGIC;
signal CMAC_rx_local_fault  : std_logic;

signal cmac_stats_reset             : std_logic_vector(7 downto 0);
signal tx_rx_counter_reset          : std_logic := '0';
signal stat_reset                   : std_logic;

signal CMAC_ARGS_rx_locked       : STD_LOGIC;

signal CMAC_rx_axis_tdata   : STD_LOGIC_VECTOR ( 511 downto 0 );
signal CMAC_rx_axis_tkeep   : STD_LOGIC_VECTOR ( 63 downto 0 );
signal CMAC_rx_axis_tlast   : STD_LOGIC;
signal CMAC_rx_axis_tuser   : STD_LOGIC;
signal CMAC_rx_axis_tvalid  : STD_LOGIC;

signal CMAC_rx_ptp_stamp        : std_logic_vector(79 downto 0);
signal CMAC_tx_ptp_stamp        : std_logic_vector(79 downto 0);

signal PTP_time_CMAC_clk_int    : std_logic_vector(79 downto 0);
signal PTP_pps_CMAC_clk_int     : std_logic;

signal ARGs_rstn                : std_logic;

signal clk100_resetn            : std_logic;

signal sys_reset_internal       : std_logic;
signal CMAC_ARGS_reset          : std_logic;

constant TS_registers                   : integer := 3;

signal TS_registers_in                  : t_slv_32_arr(0 to (TS_registers-1));
signal TS_registers_out                 : t_slv_32_arr(0 to (TS_registers-1));

begin

-----------------------------------------
-- mappings
tx_clk_out              <= CMAC_Clk;
rx_locked               <= CMAC_rx_locked;

PTP_time_CMAC_clk       <= PTP_time_CMAC_clk_int;
PTP_pps_CMAC_clk        <= PTP_pps_CMAC_clk_int;


ARGs_rstn               <= NOT i_ARGs_rst;

------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timeslave output CDC.
-- Do CDC with this arrangement instead of the time from TS core with the ARGs clock due to the timing constraint requirements.

TS_registers_in(0)  <= PTP_time_CMAC_clk_int(31 downto 0);
TS_registers_in(1)  <= PTP_time_CMAC_clk_int(63 downto 32);
TS_registers_in(2)  <= x"0000" & PTP_time_CMAC_clk_int(79 downto 64);

CDC_time_from_timeslave : FOR i IN 0 TO (TS_registers - 1) GENERATE
        stats_crossing : entity signal_processing_common.sync_vector
            generic map (
                WIDTH => 32
            )
            Port Map ( 
                clock_a_rst => tx_rx_counter_reset,
                Clock_a     => CMAC_Clk,
                data_in     => TS_registers_in(i),
                
                Clock_b     => i_ARGs_clk,
                data_out    => TS_registers_out(i)
            );  

    END GENERATE;

PTP_time_ARGs_clk(31 downto 0)  <= TS_registers_out(0);
PTP_time_ARGs_clk(63 downto 32) <= TS_registers_out(1);
PTP_time_ARGs_clk(79 downto 64) <= TS_registers_out(2)(15 downto 0);

timeslave_cdc_PPS : entity signal_processing_common.sync
    Generic Map (
        USE_XPM     => true,
        WIDTH       => 1
    )
    Port Map ( 
        Clock_a                 => CMAC_Clk,     
        data_in(0)              => PTP_pps_CMAC_clk_int,

        Clock_b                 => i_ARGs_clk,
        data_out(0)             => PTP_pps_ARGs_clk
    );


------------------------------------------------------------------------------------------------------------------------------------------------------

sync_packet_registers_sig : entity signal_processing_common.sync
    Generic Map (
        USE_XPM     => true,
        WIDTH       => 1
    )
    Port Map ( 
        Clock_a                 => i_ARGs_clk,
        Clock_b                 => i_dclk_100,
        
        data_in(0)              => ARGs_rstn,

        data_out(0)             => clk100_resetn
    );

------------------------------------------------------------------------------------------------------------------------------------------------------
ARGS_CMAC_lite : entity Timeslave_CMAC_lib.CMAC_cmac_reg 
    
    PORT MAP (
        -- AXI Lite signals, 300 MHz Clock domain
        MM_CLK                          => i_ARGs_clk,
        MM_RST                          => i_ARGs_rst,
        
        SLA_IN                          => i_CMAC_Lite_axi_mosi,
        SLA_OUT                         => o_CMAC_Lite_axi_miso,

        CMAC_STATS_INTERFACE_FIELDS_RW  => cmac_stats_rw_registers,
        
        CMAC_STATS_INTERFACE_FIELDS_RO  => cmac_stats_ro_registers
        
        );
        
------------------------------------------------------------------------------------------------------------------------------------------------------
-- Control Registers
CMAC_locked_cdc : entity signal_processing_common.sync 
    generic map (
        DEST_SYNC_FF    => 2,
        WIDTH           => 1
    )
    port map ( 
        Clock_a     => CMAC_Clk,
        Clock_b     => i_ARGs_clk,
        data_in(0)  => CMAC_rx_locked,
        
        data_out(0) => cmac_stats_ro_registers.cmac_100g_locked
    );

CMAC_RESET_CDC : entity signal_processing_common.sync 
    generic map (
        DEST_SYNC_FF    => 2,
        WIDTH           => 1
    )
    port map ( 
        Clock_a     => i_ARGs_clk,
        Clock_b     => i_dclk_100,
        data_in(0)  => cmac_stats_rw_registers.cmac_reset,
        
        data_out(0) => CMAC_ARGS_reset
    );
    
sys_reset_internal  <= sys_reset OR CMAC_ARGS_reset;    
------------------------------------------------------------------------------------------------------------------------------------------------------

TOP_100G : IF U55_TOP_QSFP GENERATE
    ptp_BD : ts_wrapper port map (
        clk_100MHz              => i_dclk_100,
        clk_100_reset           => sys_reset_internal,
        
        CMAC_Clk                => CMAC_Clk,
        
        -- Control signals
        CMAC_ctl_rx_enable      => CMAC_ctl_rx_enable,
        CMAC_ctl_tx_enable      => CMAC_ctl_tx_enable,
        CMAC_ctl_tx_lfi         => CMAC_ctl_tx_lfi,
        CMAC_ctl_tx_rfi         => CMAC_ctl_tx_rfi,
        CMAC_rx_locked          => CMAC_rx_locked,
        CMAC_usr_tx_reset       => CMAC_usr_tx_reset,
        CMAC_rx_local_fault     => CMAC_rx_local_fault,
        
        -- Stats
        stat_rx_bad_code                => stat_rx_bad_code,
        stat_rx_bad_fcs                 => stat_rx_bad_fcs,
        stat_rx_bad_preamble            => stat_rx_bad_preamble,
        stat_rx_bad_sfd                 => stat_rx_bad_sfd,
        stat_rx_broadcast               => stat_rx_broadcast,
        stat_rx_fragment                => stat_rx_fragment,
        stat_rx_multicast               => stat_rx_multicast,
        stat_rx_oversize                => stat_rx_oversize,
        stat_rx_packet_1024_1518_bytes  => stat_rx_packet_1024_1518_bytes,
        stat_rx_packet_128_255_bytes    => stat_rx_packet_128_255_bytes,
        stat_rx_packet_1519_1522_bytes  => stat_rx_packet_1519_1522_bytes,
        stat_rx_packet_1523_1548_bytes  => stat_rx_packet_1523_1548_bytes,
        stat_rx_packet_1549_2047_bytes  => stat_rx_packet_1549_2047_bytes,
        stat_rx_packet_2048_4095_bytes  => stat_rx_packet_2048_4095_bytes,
        stat_rx_packet_256_511_bytes    => stat_rx_packet_256_511_bytes,
        stat_rx_packet_4096_8191_bytes  => stat_rx_packet_4096_8191_bytes,
        stat_rx_packet_512_1023_bytes   => stat_rx_packet_512_1023_bytes,
        stat_rx_packet_64_bytes         => stat_rx_packet_64_bytes,
        stat_rx_packet_65_127_bytes     => stat_rx_packet_65_127_bytes,
        stat_rx_packet_8192_9215_bytes  => stat_rx_packet_8192_9215_bytes,
        stat_rx_packet_bad_fcs          => stat_rx_packet_bad_fcs,
        stat_rx_packet_large            => stat_rx_packet_large,
        stat_rx_packet_small            => stat_rx_packet_small,
        stat_rx_stomped_fcs             => stat_rx_stomped_fcs,
        stat_rx_toolong                 => stat_rx_toolong,
        stat_rx_total_good_packets      => stat_rx_total_good_packets,
        stat_rx_total_packets           => stat_rx_total_packets,
        stat_rx_undersize               => stat_rx_undersize,
        stat_rx_unicast                 => stat_rx_unicast,
        stat_tx_total_good_packets      => stat_tx_total_good_packets,
        stat_tx_total_packets           => stat_tx_total_packets,
        
        -- Datapath - CMAC out pre TIMESLAVE
        CMAC_rx_axis_tdata      => CMAC_rx_axis_tdata,
        CMAC_rx_axis_tkeep      => CMAC_rx_axis_tkeep,
        CMAC_rx_axis_tlast      => CMAC_rx_axis_tlast,
        CMAC_rx_axis_tuser      => CMAC_rx_axis_tuser,
        CMAC_rx_axis_tvalid     => CMAC_rx_axis_tvalid,
        
        -- Datapath POST TIMESLAVE, IN and OUT.
        RX_100G_m_axis_tdata    => o_rx_axis_tdata,
        RX_100G_m_axis_tkeep    => o_rx_axis_tkeep,
        RX_100G_m_axis_tlast    => o_rx_axis_tlast,
        RX_100G_m_axis_tready   => i_rx_axis_tready,
        RX_100G_m_axis_tuser    => o_rx_axis_tuser,
        RX_100G_m_axis_tvalid   => o_rx_axis_tvalid,
       
        TX_100G_s_axis_tdata    => i_tx_axis_tdata,
        TX_100G_s_axis_tkeep    => i_tx_axis_tkeep,
        TX_100G_s_axis_tlast    => i_tx_axis_tlast,
        TX_100G_s_axis_tuser    => i_tx_axis_tuser,
        TX_100G_s_axis_tvalid   => i_tx_axis_tvalid,
        
        TX_100G_s_axis_tready   => o_tx_axis_tready,
                
        -- To be deleted.
        CMAC_rx_ptp_stamp       => CMAC_rx_ptp_stamp,
        CMAC_tx_ptp_stamp       => CMAC_tx_ptp_stamp,
        
        CMAC_Master_reset       => sys_reset_internal,
        
        gt_loopback_in          => x"000",
    
        now                     => PTP_time_CMAC_clk_int,
        pps                     => PTP_pps_CMAC_clk_int,
        
        clk_b                   => '0',
        now_clk_b               => open,
        pps_clk_b               => open,        
    
        -- MAPPING TO GT PINS
        gt_grx_n                => gt_rxn_in,
        gt_grx_p                => gt_rxp_in,
        gt_gtx_n                => gt_txn_out,
        gt_gtx_p                => gt_txp_out,
        gt_ref_clk_n            => gt_refclk_n,
        gt_ref_clk_p            => gt_refclk_p,
        
        Timeslave_ctrl_slw_clk         => i_dclk_100,
        Timeslave_ctrl_slw_clk_aresetn => clk100_resetn,
        
        Timeslave_ctrl_AXI_S_aclk      => i_ARGs_clk,
        Timeslave_ctrl_AXI_S_aresetn   => ARGs_rstn,
        Timeslave_ctrl_AXI_S_awaddr    => i_Timeslave_Full_axi_mosi.awaddr(17 downto 0),
        Timeslave_ctrl_AXI_S_awlen     => i_Timeslave_Full_axi_mosi.awlen,
        Timeslave_ctrl_AXI_S_awsize    => i_Timeslave_Full_axi_mosi.awsize,
        Timeslave_ctrl_AXI_S_awburst   => i_Timeslave_Full_axi_mosi.awburst,
        Timeslave_ctrl_AXI_S_awlock(0) => i_Timeslave_Full_axi_mosi.awlock ,
        Timeslave_ctrl_AXI_S_awcache   => i_Timeslave_Full_axi_mosi.awcache,
        Timeslave_ctrl_AXI_S_awprot    => i_Timeslave_Full_axi_mosi.awprot,
        Timeslave_ctrl_AXI_S_awvalid   => i_Timeslave_Full_axi_mosi.awvalid,
        Timeslave_ctrl_AXI_S_awready   => o_Timeslave_Full_axi_miso.awready,
        Timeslave_ctrl_AXI_S_wdata     => i_Timeslave_Full_axi_mosi.wdata(31 downto 0),
        Timeslave_ctrl_AXI_S_wstrb     => i_Timeslave_Full_axi_mosi.wstrb(3 downto 0),
        Timeslave_ctrl_AXI_S_wlast     => i_Timeslave_Full_axi_mosi.wlast,
        Timeslave_ctrl_AXI_S_wvalid    => i_Timeslave_Full_axi_mosi.wvalid,
        Timeslave_ctrl_AXI_S_wready    => o_Timeslave_Full_axi_miso.wready,
        Timeslave_ctrl_AXI_S_bresp     => o_Timeslave_Full_axi_miso.bresp,
        Timeslave_ctrl_AXI_S_bvalid    => o_Timeslave_Full_axi_miso.bvalid,
        Timeslave_ctrl_AXI_S_bready    => i_Timeslave_Full_axi_mosi.bready ,
        Timeslave_ctrl_AXI_S_araddr    => i_Timeslave_Full_axi_mosi.araddr(17 downto 0),
        Timeslave_ctrl_AXI_S_arlen     => i_Timeslave_Full_axi_mosi.arlen,
        Timeslave_ctrl_AXI_S_arsize    => i_Timeslave_Full_axi_mosi.arsize,
        Timeslave_ctrl_AXI_S_arburst   => i_Timeslave_Full_axi_mosi.arburst,
        Timeslave_ctrl_AXI_S_arlock(0) => i_Timeslave_Full_axi_mosi.arlock ,
        Timeslave_ctrl_AXI_S_arcache   => i_Timeslave_Full_axi_mosi.arcache,
        Timeslave_ctrl_AXI_S_arprot    => i_Timeslave_Full_axi_mosi.arprot,
        Timeslave_ctrl_AXI_S_arvalid   => i_Timeslave_Full_axi_mosi.arvalid,
        Timeslave_ctrl_AXI_S_arready   => o_Timeslave_Full_axi_miso.arready,
        Timeslave_ctrl_AXI_S_rdata     => o_Timeslave_Full_axi_miso.rdata(31 downto 0),
        Timeslave_ctrl_AXI_S_rresp     => o_Timeslave_Full_axi_miso.rresp,
        Timeslave_ctrl_AXI_S_rlast     => o_Timeslave_Full_axi_miso.rlast,
        Timeslave_ctrl_AXI_S_rvalid    => o_Timeslave_Full_axi_miso.rvalid,
        Timeslave_ctrl_AXI_S_rready    => i_Timeslave_Full_axi_mosi.rready,
        
        Timeslave_ctrl_AXI_S_arqos      => i_Timeslave_Full_axi_mosi.arqos,
        Timeslave_ctrl_AXI_S_arregion   => i_Timeslave_Full_axi_mosi.arregion,
        Timeslave_ctrl_AXI_S_arid(0)    => i_Timeslave_Full_axi_mosi.arid(0),
        Timeslave_ctrl_AXI_S_awid(0)    => i_Timeslave_Full_axi_mosi.awid(0),
        Timeslave_ctrl_AXI_S_awqos      => i_Timeslave_Full_axi_mosi.awqos,
        Timeslave_ctrl_AXI_S_awregion   => i_Timeslave_Full_axi_mosi.awregion
        
        -- AXIS CONTROL FOR TIMESLAVE
        );
END GENERATE;


BOTTOM_100G : IF U55_BOTTOM_QSFP GENERATE
    ptp_BD : ts_b_wrapper port map (
        clk_100MHz              => i_dclk_100,
        clk_100_reset           => sys_reset_internal,
        
        CMAC_Clk                => CMAC_Clk,
        
        -- Control signals
        CMAC_ctl_rx_enable      => CMAC_ctl_rx_enable,
        CMAC_ctl_tx_enable      => CMAC_ctl_tx_enable,
        CMAC_ctl_tx_lfi         => CMAC_ctl_tx_lfi,
        CMAC_ctl_tx_rfi         => CMAC_ctl_tx_rfi,
        CMAC_rx_locked          => CMAC_rx_locked,
        CMAC_usr_tx_reset       => CMAC_usr_tx_reset,
        CMAC_rx_local_fault     => CMAC_rx_local_fault,
        
        -- Stats
        stat_rx_bad_code                => stat_rx_bad_code,
        stat_rx_bad_fcs                 => stat_rx_bad_fcs,
        stat_rx_bad_preamble            => stat_rx_bad_preamble,
        stat_rx_bad_sfd                 => stat_rx_bad_sfd,
        stat_rx_broadcast               => stat_rx_broadcast,
        stat_rx_fragment                => stat_rx_fragment,
        stat_rx_multicast               => stat_rx_multicast,
        stat_rx_oversize                => stat_rx_oversize,
        stat_rx_packet_1024_1518_bytes  => stat_rx_packet_1024_1518_bytes,
        stat_rx_packet_128_255_bytes    => stat_rx_packet_128_255_bytes,
        stat_rx_packet_1519_1522_bytes  => stat_rx_packet_1519_1522_bytes,
        stat_rx_packet_1523_1548_bytes  => stat_rx_packet_1523_1548_bytes,
        stat_rx_packet_1549_2047_bytes  => stat_rx_packet_1549_2047_bytes,
        stat_rx_packet_2048_4095_bytes  => stat_rx_packet_2048_4095_bytes,
        stat_rx_packet_256_511_bytes    => stat_rx_packet_256_511_bytes,
        stat_rx_packet_4096_8191_bytes  => stat_rx_packet_4096_8191_bytes,
        stat_rx_packet_512_1023_bytes   => stat_rx_packet_512_1023_bytes,
        stat_rx_packet_64_bytes         => stat_rx_packet_64_bytes,
        stat_rx_packet_65_127_bytes     => stat_rx_packet_65_127_bytes,
        stat_rx_packet_8192_9215_bytes  => stat_rx_packet_8192_9215_bytes,
        stat_rx_packet_bad_fcs          => stat_rx_packet_bad_fcs,
        stat_rx_packet_large            => stat_rx_packet_large,
        stat_rx_packet_small            => stat_rx_packet_small,
        stat_rx_stomped_fcs             => stat_rx_stomped_fcs,
        stat_rx_toolong                 => stat_rx_toolong,
        stat_rx_total_good_packets      => stat_rx_total_good_packets,
        stat_rx_total_packets           => stat_rx_total_packets,
        stat_rx_undersize               => stat_rx_undersize,
        stat_rx_unicast                 => stat_rx_unicast,
        stat_tx_total_good_packets      => stat_tx_total_good_packets,
        stat_tx_total_packets           => stat_tx_total_packets,
        
        -- Datapath - CMAC out pre TIMESLAVE
        CMAC_rx_axis_tdata      => CMAC_rx_axis_tdata,
        CMAC_rx_axis_tkeep      => CMAC_rx_axis_tkeep,
        CMAC_rx_axis_tlast      => CMAC_rx_axis_tlast,
        CMAC_rx_axis_tuser      => CMAC_rx_axis_tuser,
        CMAC_rx_axis_tvalid     => CMAC_rx_axis_tvalid,
        
        -- Datapath POST TIMESLAVE, IN and OUT.
        RX_100G_m_axis_tdata    => o_rx_axis_tdata,
        RX_100G_m_axis_tkeep    => o_rx_axis_tkeep,
        RX_100G_m_axis_tlast    => o_rx_axis_tlast,
        RX_100G_m_axis_tready   => i_rx_axis_tready,
        RX_100G_m_axis_tuser    => o_rx_axis_tuser,
        RX_100G_m_axis_tvalid   => o_rx_axis_tvalid,
                
        TX_100G_s_axis_tdata    => i_tx_axis_tdata,
        TX_100G_s_axis_tkeep    => i_tx_axis_tkeep,
        TX_100G_s_axis_tlast    => i_tx_axis_tlast,
        TX_100G_s_axis_tuser    => i_tx_axis_tuser,
        TX_100G_s_axis_tvalid   => i_tx_axis_tvalid,
        
        TX_100G_s_axis_tready   => o_tx_axis_tready,
        
        -- To be deleted.
        CMAC_rx_ptp_stamp       => CMAC_rx_ptp_stamp,
        CMAC_tx_ptp_stamp       => CMAC_tx_ptp_stamp,
        
        CMAC_Master_reset       => sys_reset_internal,
        
        gt_loopback_in          => x"000",
    
        now                     => PTP_time_CMAC_clk_int,
        pps                     => PTP_pps_CMAC_clk_int,
        
        clk_b                   => '0',
        now_clk_b               => open,
        pps_clk_b               => open,
    
        -- MAPPING TO GT PINS
        gt_grx_n                => gt_rxn_in,
        gt_grx_p                => gt_rxp_in,
        gt_gtx_n                => gt_txn_out,
        gt_gtx_p                => gt_txp_out,
        gt_ref_clk_n            => gt_refclk_n,
        gt_ref_clk_p            => gt_refclk_p,
        
        Timeslave_ctrl_slw_clk         => i_dclk_100,
        Timeslave_ctrl_slw_clk_aresetn => clk100_resetn,
        
        Timeslave_ctrl_AXI_S_aclk      => i_ARGs_clk,
        Timeslave_ctrl_AXI_S_aresetn   => ARGs_rstn,
        Timeslave_ctrl_AXI_S_awaddr    => i_Timeslave_Full_axi_mosi.awaddr(17 downto 0),
        Timeslave_ctrl_AXI_S_awlen     => i_Timeslave_Full_axi_mosi.awlen,
        Timeslave_ctrl_AXI_S_awsize    => i_Timeslave_Full_axi_mosi.awsize,
        Timeslave_ctrl_AXI_S_awburst   => i_Timeslave_Full_axi_mosi.awburst,
        Timeslave_ctrl_AXI_S_awlock(0) => i_Timeslave_Full_axi_mosi.awlock ,
        Timeslave_ctrl_AXI_S_awcache   => i_Timeslave_Full_axi_mosi.awcache,
        Timeslave_ctrl_AXI_S_awprot    => i_Timeslave_Full_axi_mosi.awprot,
        Timeslave_ctrl_AXI_S_awvalid   => i_Timeslave_Full_axi_mosi.awvalid,
        Timeslave_ctrl_AXI_S_awready   => o_Timeslave_Full_axi_miso.awready,
        Timeslave_ctrl_AXI_S_wdata     => i_Timeslave_Full_axi_mosi.wdata(31 downto 0),
        Timeslave_ctrl_AXI_S_wstrb     => i_Timeslave_Full_axi_mosi.wstrb(3 downto 0),
        Timeslave_ctrl_AXI_S_wlast     => i_Timeslave_Full_axi_mosi.wlast,
        Timeslave_ctrl_AXI_S_wvalid    => i_Timeslave_Full_axi_mosi.wvalid,
        Timeslave_ctrl_AXI_S_wready    => o_Timeslave_Full_axi_miso.wready,
        Timeslave_ctrl_AXI_S_bresp     => o_Timeslave_Full_axi_miso.bresp,
        Timeslave_ctrl_AXI_S_bvalid    => o_Timeslave_Full_axi_miso.bvalid,
        Timeslave_ctrl_AXI_S_bready    => i_Timeslave_Full_axi_mosi.bready ,
        Timeslave_ctrl_AXI_S_araddr    => i_Timeslave_Full_axi_mosi.araddr(17 downto 0),
        Timeslave_ctrl_AXI_S_arlen     => i_Timeslave_Full_axi_mosi.arlen,
        Timeslave_ctrl_AXI_S_arsize    => i_Timeslave_Full_axi_mosi.arsize,
        Timeslave_ctrl_AXI_S_arburst   => i_Timeslave_Full_axi_mosi.arburst,
        Timeslave_ctrl_AXI_S_arlock(0) => i_Timeslave_Full_axi_mosi.arlock ,
        Timeslave_ctrl_AXI_S_arcache   => i_Timeslave_Full_axi_mosi.arcache,
        Timeslave_ctrl_AXI_S_arprot    => i_Timeslave_Full_axi_mosi.arprot,
        Timeslave_ctrl_AXI_S_arvalid   => i_Timeslave_Full_axi_mosi.arvalid,
        Timeslave_ctrl_AXI_S_arready   => o_Timeslave_Full_axi_miso.arready,
        Timeslave_ctrl_AXI_S_rdata     => o_Timeslave_Full_axi_miso.rdata(31 downto 0),
        Timeslave_ctrl_AXI_S_rresp     => o_Timeslave_Full_axi_miso.rresp,
        Timeslave_ctrl_AXI_S_rlast     => o_Timeslave_Full_axi_miso.rlast,
        Timeslave_ctrl_AXI_S_rvalid    => o_Timeslave_Full_axi_miso.rvalid,
        Timeslave_ctrl_AXI_S_rready    => i_Timeslave_Full_axi_mosi.rready,
        
        Timeslave_ctrl_AXI_S_arqos      => i_Timeslave_Full_axi_mosi.arqos,
        Timeslave_ctrl_AXI_S_arregion   => i_Timeslave_Full_axi_mosi.arregion,
        Timeslave_ctrl_AXI_S_arid(0)    => i_Timeslave_Full_axi_mosi.arid(0),
        Timeslave_ctrl_AXI_S_awid(0)    => i_Timeslave_Full_axi_mosi.awid(0),
        Timeslave_ctrl_AXI_S_awqos      => i_Timeslave_Full_axi_mosi.awqos,
        Timeslave_ctrl_AXI_S_awregion   => i_Timeslave_Full_axi_mosi.awregion
        
        -- AXIS CONTROL FOR TIMESLAVE
        );
END GENERATE;

------------------------------------------------------------------------------------------------------------------------------------------------------
-- startup 
    tx_startup_fsm: process(CMAC_Clk)
    begin
        if rising_edge(CMAC_Clk) then
            if CMAC_usr_tx_reset = '1' then
                CMAC_ctl_tx_rfi         <= '0';  -- rfi = remote fault indication
                CMAC_ctl_tx_lfi         <= '0';  -- lfi = local fault indication

                CMAC_ctl_tx_enable      <= '0';
            else
                if CMAC_rx_locked = '1' then
                    CMAC_ctl_tx_rfi     <= '0';
                    CMAC_ctl_tx_lfi     <= CMAC_rx_local_fault;

                    CMAC_ctl_tx_enable  <= '1';
                else
                    CMAC_ctl_tx_rfi     <= '1';
                    CMAC_ctl_tx_lfi     <= '1';
 
                    CMAC_ctl_tx_enable  <= '0';
                end if;
            end if;
        end if;
    end process;
    
    CMAC_ctl_rx_enable <= '1';
    
------------------------------------------------------------------------------------------------------------------------------------------------------
-- Statistics


-- These are final tallies to logic mappings.
-- Some duplicates as some go to system ARGs and to CMAC ARGs interface
-- System ARGs
rx_total_packets    <= stats_to_host_data_out(0);
rx_bad_fcs          <= stats_to_host_data_out(2);
rx_bad_code         <= stats_to_host_data_out(24);

tx_total_packets    <= stats_to_host_data_out(27); 

-- CMAC ARGs
cmac_stats_ro_registers.cmac_stat_tx_total_packets			   <= stats_to_host_data_out(27); 
cmac_stats_ro_registers.cmac_stat_rx_total_packets			   <= stats_to_host_data_out(0); 
cmac_stats_ro_registers.cmac_stat_rx_total_good_packets		   <= stats_to_host_data_out(1);
cmac_stats_ro_registers.cmac_stat_rx_packet_bad_fcs			   <= stats_to_host_data_out(2);
cmac_stats_ro_registers.cmac_stat_rx_packet_64_bytes		   <= stats_to_host_data_out(3);
cmac_stats_ro_registers.cmac_stat_rx_packet_65_127_bytes	   <= stats_to_host_data_out(4);
cmac_stats_ro_registers.cmac_stat_rx_packet_128_255_bytes     <= stats_to_host_data_out(5);
cmac_stats_ro_registers.cmac_stat_rx_packet_256_511_bytes     <= stats_to_host_data_out(6);
cmac_stats_ro_registers.cmac_stat_rx_packet_512_1023_bytes    <= stats_to_host_data_out(7);
cmac_stats_ro_registers.cmac_stat_rx_packet_1024_1518_bytes   <= stats_to_host_data_out(8);
cmac_stats_ro_registers.cmac_stat_rx_packet_1519_1522_bytes   <= stats_to_host_data_out(9);
cmac_stats_ro_registers.cmac_stat_rx_packet_1523_1548_bytes   <= stats_to_host_data_out(10);
cmac_stats_ro_registers.cmac_stat_rx_packet_1549_2047_bytes   <= stats_to_host_data_out(11);
cmac_stats_ro_registers.cmac_stat_rx_packet_2048_4095_bytes   <= stats_to_host_data_out(12);
cmac_stats_ro_registers.cmac_stat_rx_packet_4096_8191_bytes   <= stats_to_host_data_out(13);
cmac_stats_ro_registers.cmac_stat_rx_packet_8192_9215_bytes   <= stats_to_host_data_out(14);
cmac_stats_ro_registers.cmac_stat_rx_packet_small             <= stats_to_host_data_out(15);
cmac_stats_ro_registers.cmac_stat_rx_packet_large             <= stats_to_host_data_out(16);
cmac_stats_ro_registers.cmac_stat_rx_unicast                  <= stats_to_host_data_out(17);
cmac_stats_ro_registers.cmac_stat_rx_multicast                <= stats_to_host_data_out(18);
cmac_stats_ro_registers.cmac_stat_rx_broadcast                <= stats_to_host_data_out(19);
cmac_stats_ro_registers.cmac_stat_rx_oversize                 <= stats_to_host_data_out(20);
cmac_stats_ro_registers.cmac_stat_rx_toolong                  <= stats_to_host_data_out(21);
cmac_stats_ro_registers.cmac_stat_rx_undersize                <= stats_to_host_data_out(22);
cmac_stats_ro_registers.cmac_stat_rx_fragment                 <= stats_to_host_data_out(23);

cmac_stats_ro_registers.cmac_stat_rx_bad_code                 <= stats_to_host_data_out(24);
cmac_stats_ro_registers.cmac_stat_rx_bad_sfd                  <= stats_to_host_data_out(25);
cmac_stats_ro_registers.cmac_stat_rx_bad_preamble             <= stats_to_host_data_out(26);

cmac_stats_ro_registers.cmac_stat_rx_bad_fcs                  <= stats_to_host_data_out(28); 
cmac_stats_ro_registers.cmac_stat_rx_stomped_fcs              <= stats_to_host_data_out(29); 
cmac_stats_ro_registers.cmac_stat_tx_total_good_packets       <= stats_to_host_data_out(30);     


---------------------------------------------------------------------------
-- ACCUMs        
stats_accumulators_rx: FOR i IN 0 TO (STAT_REGISTERS-1) GENERATE
    u_cnt_acc: ENTITY common_lib.common_accumulate
        GENERIC MAP (
            g_representation  => "UNSIGNED")
        PORT MAP (
            rst      => tx_rx_counter_reset,
            clk      => CMAC_Clk,
            clken    => '1',
            sload    => '0',
            in_val   => '1',
            in_dat   => stats_increment(i),
            out_dat  => stats_count(i)
        );
END GENERATE;

delay_rx_stat_proc : process(CMAC_Clk)
begin
    if rising_edge(CMAC_Clk) then
        -- reset from host = 1, reset from locked negative logic
        stat_reset <= cmac_stats_reset(0) OR (NOT CMAC_rx_locked); 
        
        tx_rx_counter_reset <= stat_reset;
    end if;
end process;

    
---------------------------------------------------------------------------
-- mappings from logic ouptut of CMAC to Stats accumulation.
stats_increment(0) <= stat_rx_total_packets;
stats_increment(1) <= "00" & stat_rx_total_good_packets;
stats_increment(2) <= "00" & stat_rx_packet_bad_fcs;
stats_increment(3) <= "00" & stat_rx_packet_64_bytes;
stats_increment(4) <= "00" & stat_rx_packet_65_127_bytes;
stats_increment(5) <= "00" & stat_rx_packet_128_255_bytes;
stats_increment(6) <= "00" & stat_rx_packet_256_511_bytes;
stats_increment(7) <= "00" & stat_rx_packet_512_1023_bytes;
stats_increment(8) <= "00" & stat_rx_packet_1024_1518_bytes;
stats_increment(9) <= "00" & stat_rx_packet_1519_1522_bytes;
stats_increment(10) <= "00" & stat_rx_packet_1523_1548_bytes;
stats_increment(11) <= "00" & stat_rx_packet_1549_2047_bytes;
stats_increment(12) <= "00" & stat_rx_packet_2048_4095_bytes;
stats_increment(13) <= "00" & stat_rx_packet_4096_8191_bytes;
stats_increment(14) <= "00" & stat_rx_packet_8192_9215_bytes;
stats_increment(15) <= stat_rx_packet_small;
stats_increment(16) <= "00" & stat_rx_packet_large;
stats_increment(17) <= "00" & stat_rx_unicast;
stats_increment(18) <= "00" & stat_rx_multicast;
stats_increment(19) <= "00" & stat_rx_broadcast;
stats_increment(20) <= "00" & stat_rx_oversize;
stats_increment(21) <= "00" & stat_rx_toolong;  
stats_increment(22) <= stat_rx_undersize;
stats_increment(23) <= stat_rx_fragment;
stats_increment(24) <= stat_rx_bad_code;

stats_increment(25) <= "00" & stat_rx_bad_sfd;
stats_increment(26) <= "00" & stat_rx_bad_preamble;  
stats_increment(27) <= "00" & stat_tx_total_packets;

stats_increment(28) <= stat_rx_bad_fcs;
stats_increment(29) <= stat_rx_stomped_fcs;
stats_increment(30) <= "00" & stat_tx_total_good_packets;



---------------------------------------------------------------------------
-- CDC ARGS to logic
sync_stats_to_Host: FOR i IN 0 TO (STAT_REGISTERS-1) GENERATE

    STATS_DATA : entity signal_processing_common.sync_vector
        generic map (
            WIDTH => 32
        )
        Port Map ( 
            clock_a_rst => tx_rx_counter_reset,
            Clock_a     => CMAC_Clk,
            data_in     => stats_count(i),
            
            Clock_b     => i_ARGs_clk,
            data_out    => stats_to_host_data_out(i)
        );  

END GENERATE;

---------------------------------------------------------------------------
-- reset stats
sync_cmac_stat_reset : entity signal_processing_common.sync_vector
    generic map (
        WIDTH => 8
    )
    Port Map ( 
        clock_a_rst => i_ARGs_rst,
        Clock_a     => i_ARGs_clk,
        data_in     => cmac_stats_rw_registers.cmac_stat_reset,
        
        Clock_b     => CMAC_Clk,
        data_out    => cmac_stats_reset
    ); 

---------------------------------------------------------------------------
-- DEBUG ILAs

ILAs : IF DEBUG_ILA GENERATE

timeslave_ila : ila_0
   	port map (
   	    clk                     => CMAC_Clk,
   	    probe0(31 downto 0)     => PTP_time_CMAC_clk_int(31 downto 0),
   	    probe0(32)              => PTP_pps_CMAC_clk_int,
   	    probe0(80 downto 33)    => PTP_time_CMAC_clk_int(79 downto 32),
   	    probe0(81)              => CMAC_ctl_tx_enable,
   	    probe0(82)              => CMAC_ctl_tx_rfi,
   	    probe0(83)              => CMAC_ctl_tx_lfi,
   	    probe0(84)              => CMAC_rx_locked,
   	    probe0(85)              => CMAC_usr_tx_reset,
   	    probe0(191 downto 86)   => (others => '0')
   	);
   	
END GENERATE;
   	
end rtl;
