----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.10.2020 21:20:46
-- Design Name: 
-- Module Name: 
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
library axi4_lib;
use std.textio.all;
library cnic_lib, cnic_top_lib, technology_lib;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_textio.all;
USE technology_lib.tech_mac_100g_pkg.ALL;
use IEEE.NUMERIC_STD.ALL;

USE axi4_lib.axi4_lite_pkg.ALL;
use axi4_lib.axi4_full_pkg.all;
use vitisAccelCore_lib.run1_tb_pkg.ALL;

entity tb_cnic_top is
end tb_cnic_top;
USE work.cnic_bus_pkg.ALL;

architecture Behavioral of tb_cnic_top is

    --signal cmd_file_name : string(1 to 25) := "iladataLFAASimCapture.csv"; !! Warning - does not include the "LFAARepeats" field.
    signal cmd_file_name : string(1 to 21) := "Codif_Data.txt";

    COMPONENT axi_datamover_tb
    PORT (
        m_axi_mm2s_aclk : IN STD_LOGIC;
        m_axi_mm2s_aresetn : IN STD_LOGIC;
        mm2s_err : OUT STD_LOGIC;
        m_axis_mm2s_cmdsts_aclk : IN STD_LOGIC;
        m_axis_mm2s_cmdsts_aresetn : IN STD_LOGIC;
        s_axis_mm2s_cmd_tvalid : IN STD_LOGIC;
        s_axis_mm2s_cmd_tready : OUT STD_LOGIC;
        s_axis_mm2s_cmd_tdata : IN STD_LOGIC_VECTOR(71 DOWNTO 0);
        m_axis_mm2s_sts_tvalid : OUT STD_LOGIC;
        m_axis_mm2s_sts_tready : IN STD_LOGIC;
        m_axis_mm2s_sts_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_mm2s_sts_tkeep : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_mm2s_sts_tlast : OUT STD_LOGIC;
        m_axi_mm2s_arid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_araddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_mm2s_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_mm2s_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_mm2s_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_mm2s_arprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_mm2s_arcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_aruser : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_arvalid : OUT STD_LOGIC;
        m_axi_mm2s_arready : IN STD_LOGIC;
        m_axi_mm2s_rdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_mm2s_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_mm2s_rlast : IN STD_LOGIC;
        m_axi_mm2s_rvalid : IN STD_LOGIC;
        m_axi_mm2s_rready : OUT STD_LOGIC;
        m_axis_mm2s_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_mm2s_tkeep : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axis_mm2s_tlast : OUT STD_LOGIC;
        m_axis_mm2s_tvalid : OUT STD_LOGIC;
        m_axis_mm2s_tready : IN STD_LOGIC;
        m_axi_s2mm_aclk : IN STD_LOGIC;
        m_axi_s2mm_aresetn : IN STD_LOGIC;
        s2mm_err : OUT STD_LOGIC;
        m_axis_s2mm_cmdsts_awclk : IN STD_LOGIC;
        m_axis_s2mm_cmdsts_aresetn : IN STD_LOGIC;
        s_axis_s2mm_cmd_tvalid : IN STD_LOGIC;
        s_axis_s2mm_cmd_tready : OUT STD_LOGIC;
        s_axis_s2mm_cmd_tdata : IN STD_LOGIC_VECTOR(71 DOWNTO 0);
        m_axis_s2mm_sts_tvalid : OUT STD_LOGIC;
        m_axis_s2mm_sts_tready : IN STD_LOGIC;
        m_axis_s2mm_sts_tdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_s2mm_sts_tkeep : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_s2mm_sts_tlast : OUT STD_LOGIC;
        m_axi_s2mm_awid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awaddr : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_s2mm_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_s2mm_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_s2mm_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_s2mm_awprot : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_s2mm_awcache : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awuser : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awvalid : OUT STD_LOGIC;
        m_axi_s2mm_awready : IN STD_LOGIC;
        m_axi_s2mm_wdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_s2mm_wstrb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_wlast : OUT STD_LOGIC;
        m_axi_s2mm_wvalid : OUT STD_LOGIC;
        m_axi_s2mm_wready : IN STD_LOGIC;
        m_axi_s2mm_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_s2mm_bvalid : IN STD_LOGIC;
        m_axi_s2mm_bready : OUT STD_LOGIC;
        s_axis_s2mm_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_s2mm_tkeep : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axis_s2mm_tlast : IN STD_LOGIC;
        s_axis_s2mm_tvalid : IN STD_LOGIC;
        s_axis_s2mm_tready : OUT STD_LOGIC);
    END COMPONENT;

    COMPONENT axi_bram_ctrl_1mbyte
    PORT (
        s_axi_aclk : IN STD_LOGIC;
        s_axi_aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awlock : IN STD_LOGIC;
        s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awvalid : IN STD_LOGIC;
        s_axi_awready : OUT STD_LOGIC;
        s_axi_wdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast : IN STD_LOGIC;
        s_axi_wvalid : IN STD_LOGIC;
        s_axi_wready : OUT STD_LOGIC;
        s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid : OUT STD_LOGIC;
        s_axi_bready : IN STD_LOGIC;
        s_axi_araddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arlock : IN STD_LOGIC;
        s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC);
    END COMPONENT;

    COMPONENT axi_bram_ctrl_1Mbyte256bit
    PORT (
        s_axi_aclk : IN STD_LOGIC;
        s_axi_aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awlock : IN STD_LOGIC;
        s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awvalid : IN STD_LOGIC;
        s_axi_awready : OUT STD_LOGIC;
        s_axi_wdata : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
        s_axi_wstrb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_wlast : IN STD_LOGIC;
        s_axi_wvalid : IN STD_LOGIC;
        s_axi_wready : OUT STD_LOGIC;
        s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid : OUT STD_LOGIC;
        s_axi_bready : IN STD_LOGIC;
        s_axi_araddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arlock : IN STD_LOGIC;
        s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC);
    END COMPONENT;


    signal m01_awvalid : std_logic;
    signal m01_awready : std_logic;
    signal m01_awaddr : std_logic_vector(63 downto 0);
    signal m01_awid : std_logic_vector(0 downto 0);
    signal m01_awlen : std_logic_vector(7 downto 0);
    signal m01_awsize : std_logic_vector(2 downto 0);
    signal m01_awburst : std_logic_vector(1 downto 0);
    signal m01_awlock :  std_logic_vector(1 downto 0);
    signal m01_awcache :  std_logic_vector(3 downto 0);
    signal m01_awprot :  std_logic_vector(2 downto 0);
    signal m01_awqos :  std_logic_vector(3 downto 0);
    signal m01_awregion :  std_logic_vector(3 downto 0);
    signal m01_wvalid :  std_logic;
    signal m01_wready :  std_logic;
    signal m01_wdata :  std_logic_vector(511 downto 0);
    signal m01_wstrb :  std_logic_vector(63 downto 0);
    signal m01_wlast :  std_logic;
    signal m01_bvalid : std_logic;
    signal m01_bready :  std_logic;
    signal m01_bresp :  std_logic_vector(1 downto 0);
    signal m01_bid :  std_logic_vector(0 downto 0);
    signal m01_arvalid :  std_logic;
    signal m01_arready :  std_logic;
    signal m01_araddr :  std_logic_vector(63 downto 0);
    signal m01_arid :  std_logic_vector(0 downto 0);
    signal m01_arlen :  std_logic_vector(7 downto 0);
    signal m01_arsize :  std_logic_vector(2 downto 0);
    signal m01_arburst : std_logic_vector(1 downto 0);
    signal m01_arlock :  std_logic_vector(1 downto 0);
    signal m01_arcache :  std_logic_vector(3 downto 0);
    signal m01_arprot :  std_logic_Vector(2 downto 0);
    signal m01_arqos :  std_logic_vector(3 downto 0);
    signal m01_arregion :  std_logic_vector(3 downto 0);
    signal m01_rvalid :  std_logic;
    signal m01_rready :  std_logic;
    signal m01_rdata :  std_logic_vector(511 downto 0);
    signal m01_rlast :  std_logic;
    signal m01_rid :  std_logic_vector(0 downto 0);
    signal m01_rresp :  std_logic_vector(1 downto 0);
    

    signal m02_awvalid : std_logic;
    signal m02_awready : std_logic;
    signal m02_awaddr : std_logic_vector(63 downto 0);
    signal m02_awid : std_logic_vector(0 downto 0);
    signal m02_awlen : std_logic_vector(7 downto 0);
    signal m02_awsize : std_logic_vector(2 downto 0);
    signal m02_awburst : std_logic_vector(1 downto 0);
    signal m02_awlock :  std_logic_vector(1 downto 0);
    signal m02_awcache :  std_logic_vector(3 downto 0);
    signal m02_awprot :  std_logic_vector(2 downto 0);
    signal m02_awqos :  std_logic_vector(3 downto 0);
    signal m02_awregion :  std_logic_vector(3 downto 0);
    signal m02_wvalid :  std_logic;
    signal m02_wready :  std_logic;
    signal m02_wdata :  std_logic_vector(255 downto 0);
    signal m02_wstrb :  std_logic_vector(31 downto 0);
    signal m02_wlast :  std_logic;
    signal m02_bvalid : std_logic;
    signal m02_bready :  std_logic;
    signal m02_bresp :  std_logic_vector(1 downto 0);
    signal m02_bid :  std_logic_vector(0 downto 0);
    signal m02_arvalid :  std_logic;
    signal m02_arready :  std_logic;
    signal m02_araddr :  std_logic_vector(63 downto 0);
    signal m02_arid :  std_logic_vector(0 downto 0);
    signal m02_arlen :  std_logic_vector(7 downto 0);
    signal m02_arsize :  std_logic_vector(2 downto 0);
    signal m02_arburst : std_logic_vector(1 downto 0);
    signal m02_arlock :  std_logic_vector(1 downto 0);
    signal m02_arcache :  std_logic_vector(3 downto 0);
    signal m02_arprot :  std_logic_Vector(2 downto 0);
    signal m02_arqos :  std_logic_vector(3 downto 0);
    signal m02_arregion :  std_logic_vector(3 downto 0);
    signal m02_rvalid :  std_logic;
    signal m02_rready :  std_logic;
    signal m02_rdata :  std_logic_vector(255 downto 0);
    signal m02_rlast :  std_logic;
    signal m02_rid :  std_logic_vector(0 downto 0);
    signal m02_rresp :  std_logic_vector(1 downto 0);

    signal eth100_rx_sosi : t_lbus_sosi;
    signal eth100_tx_sosi : t_lbus_sosi;
    signal eth100_tx_siso : t_lbus_siso;
    signal ap_clk : std_logic := '0';
    signal clk400 : std_logic := '0';
    signal clk450 : std_logic := '0';
    signal eth100G_clk : std_logic := '0';
    
    signal ap_rst : std_logic := '0';
    signal ap_rst_n : std_logic := '1';
    
    signal m01_araddr_20bit : std_logic_vector(19 downto 0);
    signal m01_awaddr_20bit : std_logic_vector(19 downto 0);
    signal m02_araddr_20bit : std_logic_vector(19 downto 0);
    signal m02_awaddr_20bit : std_logic_vector(19 downto 0);

    signal SetupDone : std_logic := '0';
    
    signal mc_master_mosi : t_axi4_full_mosi;
    signal mc_master_miso : t_axi4_full_miso;
    
    signal mc_lite_miso   : t_axi4_lite_miso_arr(0 TO c_nof_lite_slaves-1);
    signal mc_lite_mosi   : t_axi4_lite_mosi_arr(0 TO c_nof_lite_slaves-1);
    signal mc_full_miso   : t_axi4_full_miso_arr(0 TO c_nof_full_slaves-1);
    signal mc_full_mosi   : t_axi4_full_mosi_arr(0 TO c_nof_full_slaves-1);
    
   
    signal BF_axi_mosi : t_axi4_full_mosi;
    signal BF_axi_miso : t_axi4_full_miso;
   
    signal LFAADone : std_logic := '0';
    
    signal mm2s_errm, s2mm_err : std_logic;
    
    signal s_axis_mm2s_cmd_tvalid : STD_LOGIC;
    signal s_axis_mm2s_cmd_tready : STD_LOGIC;
    signal s_axis_mm2s_cmd_tdata  : STD_LOGIC_VECTOR(71 DOWNTO 0);
    signal m_axis_mm2s_sts_tvalid : STD_LOGIC;
    signal m_axis_mm2s_sts_tready : STD_LOGIC;
    signal m_axis_mm2s_sts_tdata  : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal m_axis_mm2s_sts_tkeep  : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal m_axis_mm2s_sts_tlast  : STD_LOGIC;
    
    signal m_axis_mm2s_tdata  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal m_axis_mm2s_tkeep  : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal m_axis_mm2s_tlast  : STD_LOGIC;
    signal m_axis_mm2s_tvalid : STD_LOGIC;
    signal m_axis_mm2s_tready : STD_LOGIC;
    
    signal axis_s2mm_cmd_tvalid : STD_LOGIC;
    signal axis_s2mm_cmd_tready : STD_LOGIC;
    signal axis_s2mm_cmd_tdata : STD_LOGIC_VECTOR(71 DOWNTO 0);
        
    signal axis_s2mm_sts_tvalid : STD_LOGIC;
    signal axis_s2mm_sts_tready : STD_LOGIC;
    signal axis_s2mm_sts_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal axis_s2mm_sts_tkeep : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal axis_s2mm_sts_tlast  : STD_LOGIC;
    
    signal axis_s2mm_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal axis_s2mm_tkeep : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal axis_s2mm_tlast : STD_LOGIC;
    signal axis_s2mm_tvalid : STD_LOGIC;
    signal axis_s2mm_tready : STD_LOGIC;    
    
begin
    
    ap_clk <= not ap_clk after 1.666 ns;    -- 300 MHz 
    clk400 <= not clk400 after 1.250 ns;    -- 400 MHz
    clk450 <= not clk450 after 1.111 ns;    -- 450 MHz
    eth100G_clk <= not eth100G_clk after 1.553 ns; -- 322 MHz
    
    ap_rst_n <= '1';
    eth100_tx_siso.ready <= '1';
    eth100_tx_siso.overflow <= '0';
    eth100_tx_siso.underflow <= '0';
    
    -- write registers
    process(ap_clk)
    begin
        if rising_edge(ap_clk) then
            
            
        end if;
    end process;
    
    process
    begin
        
        ap_rst <= '0';
        for i in 1 to 10 loop
             WAIT UNTIL RISING_EDGE(ap_clk);
        end loop;
        
        ap_rst <= '1';
        WAIT UNTIL RISING_EDGE(ap_clk);
        WAIT UNTIL RISING_EDGE(ap_clk);
        ap_rst <= '0';
        
        for i in 1 to 90 loop
            WAIT UNTIL RISING_EDGE(ap_clk);
        end loop;
        
        -- For some reason the first transaction doesn't work; this is just a dummy transaction
        axi_lite_transaction(ap_clk, mc_lite_miso(c_LFAADecode100g_lite_index), mc_lite_mosi(c_LFAADecode100g_lite_index), 0, true, x"00000001");
        axi_lite_transaction(ap_clk, mc_lite_miso(c_CT_atomic_pst_in_lite_index), mc_lite_mosi(c_CT_atomic_pst_in_lite_index), 0, true, x"00000001");
        
        setupLFAADecode(ap_clk, mc_lite_miso(c_LFAADecode100g_lite_index), mc_lite_mosi(c_LFAADecode100g_lite_index));
        
        -- Wait a while before running the setup for the corner turn, since it needs to have outputs from the LFAA setup ready before it runs.
        -- In particular, the total number of virtual channels must be correct, and this has to go through a clock domain crossing, so it takes a while.  
        for i in 1 to 20 loop
             WAIT UNTIL RISING_EDGE(ap_clk);
        end loop;  
        
        setupPST_CT_IN(ap_clk, mc_lite_miso(c_CT_atomic_pst_in_lite_index), mc_lite_mosi(c_CT_atomic_pst_in_lite_index));
        
        -- Reset to the corner turn also resets the valid memory, which takes 4096 clocks to complete, so wait before sending any data in.
        for i in 1 to 4100 loop
            WAIT UNTIL RISING_EDGE(ap_clk);
        end loop;
        
        SetupDone <= '1';
        wait;
    end process;
    
    u_interconnect: ENTITY work.cnic_bus_top
    PORT MAP (
        CLK            => ap_clk,
        RST            => ap_rst, -- axi_rst,
        SLA_IN         => mc_master_mosi,
        SLA_OUT        => mc_master_miso,
        MSTR_IN_LITE   => mc_lite_miso,
        MSTR_OUT_LITE  => mc_lite_mosi,
        MSTR_IN_FULL   => mc_full_miso,
        MSTR_OUT_FULL  => mc_full_mosi
    );
    
    icnic_top : entity cnic_lib.cnic_top
    generic map (
        -- Number of LFAA blocks per frame for the PSS/PST output.
        -- Each LFAA block is 2048 time samples. e.g. 27 for a 60 ms corner turn.
        -- This value needs to be a multiple of 3 so that there are a whole number of PST outputs per frame.
        -- Maximum value is 30, (limited by the 256MByte buffer size, which has to fit 1024 virtual channels)
        g_LFAA_BLOCKS_PER_FRAME_DIV3 => 1,   -- i.e. 3 LFAA blocks per frame.
        g_PST_BEAMS => 2
    )
    port map (
        -- Received data from 100GE
        i_data_rx_sosi => eth100_rx_sosi, -- in t_lbus_sosi;
        -- Data to be transmitted on 100GE
        o_data_tx_sosi => eth100_tx_sosi, -- out t_lbus_sosi;
        i_data_tx_siso => eth100_tx_siso, -- in t_lbus_siso;
        i_clk_100GE    => eth100G_clk,      -- in std_logic;
        -- Filterbank processing clock, 450 MHz
        i_clk450 => clk450,  -- in std_logic;
        i_clk400 => clk400,  -- in std_logic;
        -----------------------------------------------------------------------
        -- AXI slave interfaces for modules
        i_MACE_clk  => ap_clk, -- in std_logic;
        i_MACE_rst  => ap_rst, -- in std_logic;
        -- DSP top lite slave
        --i_dsptopLite_axi_mosi => mc_lite_mosi(c_dsp_top_lite_index), -- in t_axi4_lite_mosi;
        --o_dsptopLite_axi_miso => mc_lite_miso(c_dsp_top_lite_index), -- out t_axi4_lite_miso;
        -- LFAADecode, lite + full slave
        i_LFAALite_axi_mosi => mc_lite_mosi(c_LFAADecode100g_lite_index), -- in t_axi4_lite_mosi; 
        o_LFAALite_axi_miso => mc_lite_miso(c_LFAADecode100g_lite_index), -- out t_axi4_lite_miso;
        i_LFAAFull_axi_mosi => mc_full_mosi(c_lfaadecode100g_full_index), -- in  t_axi4_full_mosi;
        o_LFAAFull_axi_miso => mc_full_miso(c_lfaadecode100g_full_index), -- out t_axi4_full_miso;
        -- Timing control
        i_timing_axi_mosi => mc_lite_mosi(c_timingcontrola_lite_index), -- in t_axi4_lite_mosi;
        o_timing_axi_miso => mc_lite_miso(c_timingcontrola_lite_index), -- out t_axi4_lite_miso;
        -- Corner Turn between LFAA Ingest and the filterbanks.
        i_LFAA_CT_axi_mosi => mc_lite_mosi(c_CT_atomic_pst_in_lite_index), -- in  t_axi4_lite_mosi;
        o_LFAA_CT_axi_miso => mc_lite_miso(c_CT_atomic_pst_in_lite_index), -- out t_axi4_lite_miso;
        -- Filterbanks
        i_FB_axi_mosi => mc_full_mosi(c_filterbanks_full_index), -- in  t_axi4_lite_mosi;
        o_FB_axi_miso => mc_full_miso(c_filterbanks_full_index), -- out t_axi4_lite_miso;
        -- registers for the beamformer corner turn 
        i_BF_CT_axi_mosi => mc_lite_mosi(c_CT_atomic_pst_out_lite_index), -- in t_axi4_lite_mosi;  --
        o_BF_CT_axi_miso => mc_lite_miso(c_CT_atomic_pst_out_lite_index), -- out t_axi4_lite_miso; --
        -- registers for the beamformer
        i_BF_axi_mosi => mc_full_mosi(c_pstbeamformer_full_index), -- in  t_axi4_full_mosi;
        o_BF_axi_miso => mc_full_miso(c_pstbeamformer_full_index), -- out t_axi4_full_miso;
        -- registers for the packetiser
        i_PSR_packetiser_Lite_axi_mosi => mc_lite_mosi(c_packetiser_lite_index), -- in t_axi4_lite_mosi; 
        o_PSR_packetiser_Lite_axi_miso => mc_lite_miso(c_packetiser_lite_index), -- out t_axi4_lite_miso;
        i_PSR_packetiser_Full_axi_mosi => mc_full_mosi(c_packetiser_full_index), -- in  t_axi4_full_mosi;
        o_PSR_packetiser_Full_axi_miso => mc_full_miso(c_packetiser_full_index), -- out t_axi4_full_miso;
        -----------------------------------------------------------------------
        -- AXI interfaces to shared memory
        --  Shared memory block for the first corner turn (at the output of the LFAA ingest block)
        -- Corner Turn between LFAA ingest and the filterbanks
        -- AXI4 master interface for accessing HBM for the LFAA ingest corner turn : m01_axi
        -- !!! Assumes a 1GByte Address space, so the low 30 bits of the address come from here, while the high 34 bits come from the axi-lite register interface.
        -- aw bus - write addresses.
        m01_axi_awvalid => m01_awvalid,   -- out std_logic;
        m01_axi_awready => m01_awready,   -- in std_logic;
        m01_axi_awaddr  => m01_awaddr(29 downto 0),    -- out std_logic_vector(29 downto 0);
        m01_axi_awlen   => m01_awlen,     -- out std_logic_vector(7 downto 0); Number of beats in each burst is this value + 1.
        -- w bus - write data.
        m01_axi_wvalid   => m01_wvalid,   -- out std_logic;
        m01_axi_wready   => m01_wready,   -- in std_logic;
        m01_axi_wdata    => m01_wdata,    -- out std_logic_vector(511 downto 0);
        m01_axi_wlast    => m01_wlast,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m01_axi_bvalid   => m01_bvalid,   -- in std_logic;
        m01_axi_bresp    => m01_bresp,    -- in std_logic_vector(1 downto 0);
        -- ar - read address
        m01_axi_arvalid  => m01_arvalid,  -- out std_logic;
        m01_axi_arready  => m01_arready,  -- in std_logic;
        m01_axi_araddr   => m01_araddr(29 downto 0),   -- out std_logic_vector(29 downto 0);
        m01_axi_arlen    => m01_arlen,    -- out std_logic_vector(7 downto 0); --  Number of beats in each burst is this value + 1.
        -- r - read data
        m01_axi_rvalid   => m01_rvalid,   -- in std_logic;
        m01_axi_rready   => m01_rready,   -- out std_logic;
        m01_axi_rdata    => m01_rdata,    -- in std_logic_vector(511 downto 0);
        m01_axi_rlast    => m01_rlast,    -- in std_logic;        
        m01_axi_rresp    => m01_rresp,    -- in std_logic_vector(1 downto 0); -- read response; "00" and "01 are ok, "10" and "11" indicate an error.
        
        -- Corner turn between filterbanks and beamformer
        -- !!! Assumes a 1GByte Address space, so the low 30 bits of the address come from here, while the high 34 bits come from the axi-lite register interface.
        -- aw bus - write address.
        m02_axi_awvalid => m02_awvalid,   -- out std_logic;
        m02_axi_awready => m02_awready,   -- in std_logic;
        m02_axi_awaddr  => m02_awaddr(29 downto 0),    -- out std_logic_vector(29 downto 0);
        m02_axi_awlen   => m02_awlen,     -- out std_logic_vector(7 downto 0);
        -- w bus - write data.
        m02_axi_wvalid   => m02_wvalid,   -- out std_logic;
        m02_axi_wready   => m02_wready,   -- in std_logic;
        m02_axi_wdata    => m02_wdata,    -- out std_logic_vector(511 downto 0);
        m02_axi_wlast    => m02_wlast,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m02_axi_bvalid   => m02_bvalid,   -- in std_logic;
        m02_axi_bresp    => m02_bresp,    -- in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m02_axi_arvalid  => m02_arvalid,  -- out std_logic;
        m02_axi_arready  => m02_arready,  -- in std_logic;
        m02_axi_araddr   => m02_araddr(29 downto 0),   -- out std_logic_vector(29 downto 0);
        m02_axi_arlen    => m02_arlen,    -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m02_axi_rvalid   => m02_rvalid,   -- in std_logic;
        m02_axi_rready   => m02_rready,   -- out std_logic;
        m02_axi_rdata    => m02_rdata,    -- in std_logic_vector(511 downto 0);
        m02_axi_rlast    => m02_rlast,    -- in std_logic;
        m02_axi_rresp    => m02_rresp     -- in std_logic_vector(1 downto 0);    
    );

    -- Emulate HBM
    -- 1 Gbyte of memory for the first corner turn.
    -- Translate from 1Gbyte address space to a 1 MByte address space to make the amount of memory manageable for simulation.
    -- 4 buffers of 256 MBytes each                       = 2 bits, (29:28)   => keep all 4 buffers       = 2 bits,  (19:18)
    -- Each buffer is 1024 virtual channels               = 10 bits, (27:18)  => Space for 8 channels     = 3 bits,  (17:15)
    -- Each virtual channel has space for 32 LFAA packets = 5 bits, (17:13)   => space for 4 LFAA packets = 2 bits,  (14:13)
    -- Each LFAA packet is 8192 bytes                     = 13 bits, (12:0)   => keep the same            = 13 bits, (12:0)

    m01_araddr_20bit(19 downto 18) <= m01_araddr(29 downto 28);  -- 4 buffers
    m01_araddr_20bit(17 downto 15) <= m01_araddr(20 downto 18);  -- up to 8 virtual channels 
    m01_araddr_20bit(14 downto 13) <= m01_araddr(14 downto 13);  -- up to 4 packets per buffer per virtual channel
    m01_araddr_20bit(12 downto 0) <= m01_araddr(12 downto 0);    -- 8192 bytes per LFAA packet.
    
    m01_awaddr_20bit(19 downto 18) <= m01_awaddr(29 downto 28);  -- 4 buffers
    m01_awaddr_20bit(17 downto 15) <= m01_awaddr(20 downto 18);  -- up to 8 virtual channels 
    m01_awaddr_20bit(14 downto 13) <= m01_awaddr(14 downto 13);  -- up to 4 packets per buffer per virtual channel
    m01_awaddr_20bit(12 downto 0) <= m01_awaddr(12 downto 0);    -- 8192 bytes per LFAA packet.
    
    m01_arlock <= "00";
    m01_awlock <= "00";
    m01_awid(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m01_awsize  <= "110";  -- size of 6 indicates 64 bytes in each beat (i.e. 512 bit wide bus) -- out std_logic_vector(2 downto 0);
    m01_awburst <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m01_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m01_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m01_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m01_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m01_bready  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m01_wstrb  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m01_arid(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m01_arsize  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m01_arburst <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
    m01_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m01_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m01_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m01_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    
    main_ct_hbm : axi_bram_ctrl_1mbyte
    PORT MAP (
        s_axi_aclk => ap_clk,
        s_axi_aresetn => ap_rst_n,
        s_axi_awaddr => m01_awaddr_20bit,
        s_axi_awlen => m01_awlen,
        s_axi_awsize => m01_awsize,
        s_axi_awburst => m01_awburst,
        s_axi_awlock => '0',
        s_axi_awcache => m01_awcache,
        s_axi_awprot => m01_awprot,
        s_axi_awvalid => m01_awvalid,
        s_axi_awready => m01_awready,
        s_axi_wdata => m01_wdata,
        s_axi_wstrb => m01_wstrb,
        s_axi_wlast => m01_wlast,
        s_axi_wvalid => m01_wvalid,
        s_axi_wready => m01_wready,
        s_axi_bresp => m01_bresp,
        s_axi_bvalid => m01_bvalid,
        s_axi_bready => m01_bready,
        s_axi_araddr => m01_araddr_20bit,
        s_axi_arlen => m01_arlen,
        s_axi_arsize => m01_arsize,
        s_axi_arburst => m01_arburst,
        s_axi_arlock => '0',
        s_axi_arcache => m01_arcache,
        s_axi_arprot => m01_arprot,
        s_axi_arvalid => m01_arvalid,
        s_axi_arready => m01_arready,
        s_axi_rdata => m01_rdata,
        s_axi_rresp => m01_rresp,
        s_axi_rlast => m01_rlast,
        s_axi_rvalid => m01_rvalid,
        s_axi_rready => m01_rready
    );

    -- 1Gbyte of memory for the second corner turn
    -- Need to check this address mapping makes sense after second corner turn is functioning in the firmware.
    m02_araddr_20bit(19 downto 18) <= m02_araddr(29 downto 28);  -- 4 buffers
    m02_araddr_20bit(17 downto 15) <= m02_araddr(20 downto 18);  -- up to 8 virtual channels 
    m02_araddr_20bit(14 downto 0) <= m02_araddr(14 downto 0);  -- 15 bits allocated = 32768 bytes, for packed time samples from the PST filterbank, so T*216 * 4 = 32768 => T = up to 37. This means this will work for a corner turn with 3 LFAA packets.
    
    m02_awaddr_20bit(19 downto 18) <= m02_awaddr(29 downto 28);  -- 4 buffers
    m02_awaddr_20bit(17 downto 15) <= m02_awaddr(20 downto 18);  -- up to 8 virtual channels 
    m02_awaddr_20bit(14 downto 0) <= m02_awaddr(14 downto 0);  -- corresponds to space for up to 32 PST time samples (=output from 3 LFAA packets)  
    
    
    m02_arlock <= "00";
    m02_awlock <= "00";
    m02_awid(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m02_awsize  <= "101";  -- size of 5 indicates 32 bytes in each beat (i.e. 256 bit wide bus) -- out std_logic_vector(2 downto 0);
    m02_awburst <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m02_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m02_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m02_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m02_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m02_bready  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m02_wstrb  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m02_arid(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m02_arsize  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m02_arburst <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
    m02_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m02_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m02_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m02_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    
    second_ct_hbm : axi_bram_ctrl_1Mbyte256bit
    PORT MAP (
        s_axi_aclk => ap_clk,
        s_axi_aresetn => ap_rst_n,
        s_axi_awaddr => m02_awaddr_20bit,
        s_axi_awlen => m02_awlen,
        s_axi_awsize => m02_awsize,
        s_axi_awburst => m02_awburst,
        s_axi_awlock => '0',
        s_axi_awcache => m02_awcache,
        s_axi_awprot => m02_awprot,
        s_axi_awvalid => m02_awvalid,
        s_axi_awready => m02_awready,
        s_axi_wdata => m02_wdata,
        s_axi_wstrb => m02_wstrb,
        s_axi_wlast => m02_wlast,
        s_axi_wvalid => m02_wvalid,
        s_axi_wready => m02_wready,
        s_axi_bresp => m02_bresp,
        s_axi_bvalid => m02_bvalid,
        s_axi_bready => m02_bready,
        s_axi_araddr => m02_araddr_20bit,
        s_axi_arlen => m02_arlen,
        s_axi_arsize => m02_arsize,
        s_axi_arburst => m02_arburst,
        s_axi_arlock => '0',
        s_axi_arcache => m02_arcache,
        s_axi_arprot => m02_arprot,
        s_axi_arvalid => m02_arvalid,
        s_axi_arready => m02_arready,
        s_axi_rdata => m02_rdata,
        s_axi_rresp => m02_rresp,
        s_axi_rlast => m02_rlast,
        s_axi_rvalid => m02_rvalid,
        s_axi_rready => m02_rready
    );

    -------------------------------------------------------------------------------------------
    -- 100 GE data input
    -- eth100_rx_sosi
    -- TYPE t_lbus_sosi IS RECORD  -- Source Out and Sink In
    --   data       : STD_LOGIC_VECTOR(511 DOWNTO 0);                -- Data bus
    --   valid      : STD_LOGIC_VECTOR(3 DOWNTO 0);    -- Data segment enable
    --   eop        : STD_LOGIC_VECTOR(3 DOWNTO 0);    -- End of packet
    --   sop        : STD_LOGIC_VECTOR(3 DOWNTO 0);    -- Start of packet
    --   error      : STD_LOGIC_VECTOR(3 DOWNTO 0);    -- Error flag, indicates data has an error
    --   empty      : t_empty_arr(3 DOWNTO 0);         -- Number of bytes empty in the segment  (four 4bit entries)
    -- END RECORD;
    process
        
        file cmdfile: TEXT;
        variable line_in : Line;
        variable good : boolean;
        variable LFAArepeats : std_logic_vector(15 downto 0);
        variable LFAAData  : std_logic_vector(511 downto 0);
        variable LFAAvalid : std_logic_vector(3 downto 0);
        variable LFAAeop   : std_logic_vector(3 downto 0);
        variable LFAAerror : std_logic_vector(3 downto 0);
        variable LFAAempty0 : std_logic_vector(3 downto 0);
        variable LFAAempty1 : std_logic_vector(3 downto 0);
        variable LFAAempty2 : std_logic_vector(3 downto 0);
        variable LFAAempty3 : std_logic_vector(3 downto 0);
        variable LFAAsop    : std_logic_vector(3 downto 0);
        
    begin
        
        eth100_rx_sosi.data <= (others => '0');  -- 512 bits
        eth100_rx_sosi.valid <= "0000";          -- 4 bits
        eth100_rx_sosi.eop <= "0000";  
        eth100_rx_sosi.sop <= "0000";
        eth100_rx_sosi.error <= "0000";
        eth100_rx_sosi.empty(0) <= "0000";
        eth100_rx_sosi.empty(1) <= "0000";
        eth100_rx_sosi.empty(2) <= "0000";
        eth100_rx_sosi.empty(3) <= "0000";
        
        
        FILE_OPEN(cmdfile,cmd_file_name,READ_MODE);
        wait until SetupDone = '1';
        
        wait until rising_edge(eth100G_clk);
        
        while (not endfile(cmdfile)) loop 
            readline(cmdfile, line_in);
            hread(line_in,LFAArepeats,good);
            hread(line_in,LFAAData,good);
            hread(line_in,LFAAvalid,good);
            hread(line_in,LFAAeop,good);
            hread(line_in,LFAAerror,good);
            hread(line_in,LFAAempty0,good);
            hread(line_in,LFAAempty1,good);
            hread(line_in,LFAAempty2,good);
            hread(line_in,LFAAempty3,good);
            hread(line_in,LFAAsop,good);
            
            eth100_rx_sosi.data <= LFAAData;  -- 512 bits
            eth100_rx_sosi.valid <= LFAAValid;          -- 4 bits
            eth100_rx_sosi.eop <= LFAAeop;
            eth100_rx_sosi.sop <= LFAAsop;
            eth100_rx_sosi.error <= LFAAerror;
            eth100_rx_sosi.empty(0) <= LFAAempty0;
            eth100_rx_sosi.empty(1) <= LFAAempty1;
            eth100_rx_sosi.empty(2) <= LFAAempty2;
            eth100_rx_sosi.empty(3) <= LFAAempty3;
            
            wait until rising_edge(eth100G_clk);
            while LFAArepeats /= "0000000000000000" loop
                LFAArepeats := std_logic_vector(unsigned(LFAArepeats) - 1);
                wait until rising_edge(eth100G_clk);
            end loop;
        end loop;
        
        LFAADone <= '1';
        wait;
    end process;


    -------------------------------------------------------------------------------
    -- AXI full interface to copy data into the beamformer memory
    -- Uses the Xilinx AXI datamover component.
    
    -- Read command from a file to copy data into the beamformers
    --????
    
    
    register_DMi : axi_datamover_tb
    port map (
        m_axi_mm2s_aclk => ap_clk, -- IN STD_LOGIC;
        m_axi_mm2s_aresetn => '1', -- IN STD_LOGIC;
        mm2s_err => mm2s_errm,     -- OUT STD_LOGIC;
        m_axis_mm2s_cmdsts_aclk => ap_clk, -- IN STD_LOGIC;
        m_axis_mm2s_cmdsts_aresetn => '1', -- IN STD_LOGIC;
        s_axis_mm2s_cmd_tvalid => s_axis_mm2s_cmd_tvalid, -- IN STD_LOGIC;
        s_axis_mm2s_cmd_tready => s_axis_mm2s_cmd_tready, -- OUT STD_LOGIC;
        s_axis_mm2s_cmd_tdata  => s_axis_mm2s_cmd_tdata,  -- IN STD_LOGIC_VECTOR(71 DOWNTO 0);
        m_axis_mm2s_sts_tvalid => m_axis_mm2s_sts_tvalid, -- OUT STD_LOGIC;
        m_axis_mm2s_sts_tready => m_axis_mm2s_sts_tready, -- IN STD_LOGIC;
        m_axis_mm2s_sts_tdata  => m_axis_mm2s_sts_tdata,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_mm2s_sts_tkeep  => m_axis_mm2s_sts_tkeep,  -- OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_mm2s_sts_tlast  => m_axis_mm2s_sts_tlast,  -- OUT STD_LOGIC;
        m_axi_mm2s_arid   => BF_axi_mosi.arid(3 downto 0),     -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_araddr => BF_axi_mosi.araddr(31 downto 0),  -- OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_mm2s_arlen  => BF_axi_mosi.arlen(7 downto 0),    -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_mm2s_arsize => BF_axi_mosi.arsize(2 downto 0),   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_mm2s_arburst => BF_axi_mosi.arburst(1 downto 0), -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_mm2s_arprot => BF_axi_mosi.arprot(2 downto 0),   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_mm2s_arcache => BF_axi_mosi.arcache(3 downto 0), -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_aruser  => BF_axi_mosi.aruser(3 downto 0),  --  OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_mm2s_arvalid => BF_axi_mosi.arvalid,             -- OUT STD_LOGIC;
        m_axi_mm2s_arready => BF_axi_miso.arready,             -- IN STD_LOGIC;
        m_axi_mm2s_rdata   => BF_axi_miso.rdata,               -- IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_mm2s_rresp   => BF_axi_miso.rresp,               -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_mm2s_rlast   => BF_axi_miso.rlast,               -- IN STD_LOGIC;
        m_axi_mm2s_rvalid  => BF_axi_miso.rvalid,              -- IN STD_LOGIC;
        m_axi_mm2s_rready  => BF_axi_mosi.rready,              -- OUT STD_LOGIC;
        
        m_axis_mm2s_tdata  => m_axis_mm2s_tdata,   -- OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_mm2s_tkeep  => m_axis_mm2s_tkeep,   -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axis_mm2s_tlast  => m_axis_mm2s_tlast,   -- OUT STD_LOGIC;
        m_axis_mm2s_tvalid => m_axis_mm2s_tvalid,  -- OUT STD_LOGIC;
        m_axis_mm2s_tready => m_axis_mm2s_tready,  -- IN STD_LOGIC;
        m_axi_s2mm_aclk    => ap_clk, -- IN STD_LOGIC;
        m_axi_s2mm_aresetn => '1',    -- IN STD_LOGIC;
        s2mm_err => s2mm_err,         -- OUT STD_LOGIC;
        m_axis_s2mm_cmdsts_awclk => ap_clk, -- IN STD_LOGIC;
        m_axis_s2mm_cmdsts_aresetn => '1', -- IN STD_LOGIC;
        s_axis_s2mm_cmd_tvalid => axis_s2mm_cmd_tvalid, -- IN STD_LOGIC;
        s_axis_s2mm_cmd_tready => axis_s2mm_cmd_tready, -- OUT STD_LOGIC;
        s_axis_s2mm_cmd_tdata  => axis_s2mm_cmd_tdata,  -- IN STD_LOGIC_VECTOR(71 DOWNTO 0);
        
        m_axis_s2mm_sts_tvalid => axis_s2mm_sts_tvalid, -- OUT STD_LOGIC;
        m_axis_s2mm_sts_tready => axis_s2mm_sts_tready, -- IN STD_LOGIC;
        m_axis_s2mm_sts_tdata  => axis_s2mm_sts_tdata,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_s2mm_sts_tkeep  => axis_s2mm_sts_tkeep,  -- OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_s2mm_sts_tlast  => axis_s2mm_sts_tlast,  -- OUT STD_LOGIC;
        
        m_axi_s2mm_awid  => BF_axi_mosi.awid(3 downto 0),     -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awaddr => BF_axi_mosi.awaddr(31 downto 0), -- OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_s2mm_awlen  => BF_axi_mosi.awlen(7 downto 0),   -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_s2mm_awsize => BF_axi_mosi.awsize(2 downto 0),  -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_s2mm_awburst => BF_axi_mosi.awburst(1 downto 0), -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_s2mm_awprot  => BF_axi_mosi.awprot,              -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_s2mm_awcache => BF_axi_mosi.awcache(3 downto 0), -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awuser  => BF_axi_mosi.awuser(3 downto 0),  -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_awvalid => BF_axi_mosi.awvalid,             -- OUT STD_LOGIC;
        m_axi_s2mm_awready => BF_axi_miso.awready,             -- IN STD_LOGIC;
        m_axi_s2mm_wdata   => BF_axi_mosi.wdata(31 downto 0),  -- OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_s2mm_wstrb   => BF_axi_mosi.wstrb(3 downto 0),   -- OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_s2mm_wlast   => BF_axi_mosi.wlast,               -- OUT STD_LOGIC;
        m_axi_s2mm_wvalid  => BF_axi_mosi.wvalid,              -- OUT STD_LOGIC;
        m_axi_s2mm_wready  => BF_axi_miso.wready,              -- IN STD_LOGIC;
        m_axi_s2mm_bresp   => BF_axi_miso.bresp(1 downto 0),   -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_s2mm_bvalid  => BF_axi_miso.bvalid,              -- IN STD_LOGIC;
        m_axi_s2mm_bready  => BF_axi_mosi.bready,              -- OUT STD_LOGIC;
        s_axis_s2mm_tdata  => axis_s2mm_tdata,  -- IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_s2mm_tkeep  => axis_s2mm_tkeep,   -- IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axis_s2mm_tlast  => axis_s2mm_tlast,               -- IN STD_LOGIC;
        s_axis_s2mm_tvalid => axis_s2mm_tvalid,              -- IN STD_LOGIC;
        s_axis_s2mm_tready => axis_s2mm_tready               -- OUT STD_LOGIC
    );


end Behavioral;
