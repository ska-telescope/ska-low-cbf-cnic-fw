-------------------------------------------------------------------------------
--
-- File Name: cnic_top.vhd
-- Contributing Authors: Giles Babich - Giles.babich@csiro.au, Jason van Aardt, jason.vanaardt@csiro.au
-- Type: RTL
-- Created: 27 October 2021
--
-- Title: Top Level for the cnic (Traffic Generator)
--
--
--  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
--  See the file LICENSE for more info.
--
-- Design updated June 2022 by Giles to include
--      * 4 x 4G HBM buffers (4G limit dictated by XRT limitations)
--      * Capture and playback from whole HBM
--      * Timestamping of incoming packets
--      * Filtering of incoming packets based on byte length
--      * TX or RX packets base on software configured byte size, only one siz at a time supported.
--      * control registers renamed and general code tidy up.
--      * PTP scheduler expanded to stop and start for rx and tx independently.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, common_lib, axi4_lib, cmac_s_axi_lib;
library HBM_PktController_lib, cnic_lib, PSR_Packetiser_lib;

use cnic_lib.cnic_top_pkg.all;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_lib.common_pkg.ALL;
USE common_lib.common_mem_pkg.ALL;
USE axi4_lib.axi4_lite_pkg.ALL;
USE axi4_lib.axi4_stream_pkg.ALL;
USE axi4_lib.axi4_full_pkg.ALL;

use PSR_Packetiser_lib.ethernet_pkg.ALL;
use PSR_Packetiser_lib.CbfPsrHeader_pkg.ALL;

USE HBM_PktController_lib.HBM_PktController_hbm_pktcontroller_reg_pkg.ALL;

library technology_lib;
USE technology_lib.tech_mac_100g_pkg.ALL;

library xpm;
use xpm.vcomponents.all;

-------------------------------------------------------------------------------
entity cnic_top is
    generic (
        g_DEBUG_ILA                     : BOOLEAN := FALSE;
        g_CODIF_MODIFIER_HEADER_BLOCK   : BOOLEAN := FALSE;
        g_LBUS_CMAC                     : BOOLEAN := FALSE

    );
    port (
        clk_freerun : in std_logic;
        -----------------------------------------------------------------------
        -- 100G TX
        -- CMAC LBUS
        -- Received data from 100GE
        i_data_rx_sosi      : in t_lbus_sosi;
        -- Data to be transmitted on 100GE
        o_data_tx_sosi      : out t_lbus_sosi;
        i_data_tx_siso      : in t_lbus_siso;
        
        -- streaming AXI to CMAC
        i_clk_100GE         : in std_logic;
        i_eth100G_locked    : in std_logic;
        o_tx_axis_tdata     : OUT STD_LOGIC_VECTOR(511 downto 0);
        o_tx_axis_tkeep     : OUT STD_LOGIC_VECTOR(63 downto 0);
        o_tx_axis_tvalid    : OUT STD_LOGIC;
        o_tx_axis_tlast     : OUT STD_LOGIC;
        o_tx_axis_tuser     : OUT STD_LOGIC;
        i_tx_axis_tready    : in STD_LOGIC;
                
        -------
        -- 100G RX
        -- RX
        i_rx_axis_tdata     : in STD_LOGIC_VECTOR ( 511 downto 0 );
        i_rx_axis_tkeep     : in STD_LOGIC_VECTOR ( 63 downto 0 );
        i_rx_axis_tlast     : in STD_LOGIC;
        o_rx_axis_tready    : out STD_LOGIC;
        i_rx_axis_tuser     : in STD_LOGIC_VECTOR ( 79 downto 0 );
        i_rx_axis_tvalid    : in STD_LOGIC;
        
        -----------------------------------------------------------------------
        -- streaming AXI to CMAC 2nd interface.
        
        i_clk_100GE_b       : in std_logic;
        i_eth100G_locked_b  : in std_logic;
        o_tx_axis_tdata_b   : OUT STD_LOGIC_VECTOR(511 downto 0);
        o_tx_axis_tkeep_b   : OUT STD_LOGIC_VECTOR(63 downto 0);
        o_tx_axis_tvalid_b  : OUT STD_LOGIC;
        o_tx_axis_tlast_b   : OUT STD_LOGIC;
        o_tx_axis_tuser_b   : OUT STD_LOGIC;
        i_tx_axis_tready_b  : in STD_LOGIC;

        -----------------------------------------------------------------------
        -- Debug signal used in the testbench.
        o_validMemRstActive : out std_logic;  -- reset of the valid memory is in progress.
        -----------------------------------------------------------------------
        -- MACE AXI slave interfaces for modules
        -- The 300MHz MACE_clk is also used for some of the signal processing
        i_MACE_clk  : in std_logic;
        i_MACE_rst  : in std_logic;
        
        i_HBM_Pktcontroller_Lite_axi_mosi : in t_axi4_lite_mosi; 
        o_HBM_Pktcontroller_Lite_axi_miso : out t_axi4_lite_miso;
        
        
        -----------------------------------------------------------------------
        i_schedule_action   : in std_logic_vector(7 downto 0);
        -----------------------------------------------------------------------
        -- AXI interfaces to shared memory
        -- Uses the same clock as MACE (300MHz)
        -----------------------------------------------------------------------
        --  Shared memory block for the first corner turn (at the output of the LFAA ingest block)
        -- Corner Turn between LFAA ingest and the filterbanks
        -- AXI4 master interface for accessing HBM for the LFAA ingest corner turn : m01_axi
        -- aw bus = write address

	--------------------------------------------------------------------------
	-- M01
        m01_axi_awvalid  : out std_logic;
        m01_axi_awready  : in std_logic;
        m01_axi_awaddr   : out std_logic_vector(31 downto 0);
        m01_axi_awlen    : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m01_axi_wvalid    : out std_logic;
        m01_axi_wready    : in std_logic;
        m01_axi_wdata     : out std_logic_vector(511 downto 0);
        m01_axi_wlast     : out std_logic;
        -- b bus - write response
        m01_axi_bvalid    : in std_logic;
        m01_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m01_axi_arvalid   : out std_logic;
        m01_axi_arready   : in std_logic;
        m01_axi_araddr    : out std_logic_vector(31 downto 0);
        m01_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid    : in std_logic;
        m01_axi_rready    : out std_logic;
        m01_axi_rdata     : in std_logic_vector(511 downto 0);
        m01_axi_rlast     : in std_logic;
        m01_axi_rresp     : in std_logic_vector(1 downto 0);

	--------------------------------------------------------------------------
	-- m02
        m02_axi_awvalid  : out std_logic;
        m02_axi_awready  : in std_logic;
        m02_axi_awaddr   : out std_logic_vector(31 downto 0);
        m02_axi_awlen    : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m02_axi_wvalid    : out std_logic;
        m02_axi_wready    : in std_logic;
        m02_axi_wdata     : out std_logic_vector(511 downto 0);
        m02_axi_wlast     : out std_logic;
        -- b bus - write response
        m02_axi_bvalid    : in std_logic;
        m02_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m02_axi_arvalid   : out std_logic;
        m02_axi_arready   : in std_logic;
        m02_axi_araddr    : out std_logic_vector(31 downto 0);
        m02_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m02_axi_rvalid    : in std_logic;
        m02_axi_rready    : out std_logic;
        m02_axi_rdata     : in std_logic_vector(511 downto 0);
        m02_axi_rlast     : in std_logic;
        m02_axi_rresp     : in std_logic_vector(1 downto 0);

	--------------------------------------------------------------------------
	-- m03
        m03_axi_awvalid  : out std_logic;
        m03_axi_awready  : in std_logic;
        m03_axi_awaddr   : out std_logic_vector(31 downto 0);
        m03_axi_awlen    : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m03_axi_wvalid    : out std_logic;
        m03_axi_wready    : in std_logic;
        m03_axi_wdata     : out std_logic_vector(511 downto 0);
        m03_axi_wlast     : out std_logic;
        -- b bus - write response
        m03_axi_bvalid    : in std_logic;
        m03_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m03_axi_arvalid   : out std_logic;
        m03_axi_arready   : in std_logic;
        m03_axi_araddr    : out std_logic_vector(31 downto 0);
        m03_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m03_axi_rvalid    : in std_logic;
        m03_axi_rready    : out std_logic;
        m03_axi_rdata     : in std_logic_vector(511 downto 0);
        m03_axi_rlast     : in std_logic;
        m03_axi_rresp     : in std_logic_vector(1 downto 0);

	--------------------------------------------------------------------------
	-- m04
        m04_axi_awvalid  : out std_logic;
        m04_axi_awready  : in std_logic;
        m04_axi_awaddr   : out std_logic_vector(31 downto 0);
        m04_axi_awlen    : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m04_axi_wvalid    : out std_logic;
        m04_axi_wready    : in std_logic;
        m04_axi_wdata     : out std_logic_vector(511 downto 0);
        m04_axi_wlast     : out std_logic;
        -- b bus - write response
        m04_axi_bvalid    : in std_logic;
        m04_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m04_axi_arvalid   : out std_logic;
        m04_axi_arready   : in std_logic;
        m04_axi_araddr    : out std_logic_vector(31 downto 0);
        m04_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m04_axi_rvalid    : in std_logic;
        m04_axi_rready    : out std_logic;
        m04_axi_rdata     : in std_logic_vector(511 downto 0);
        m04_axi_rlast     : in std_logic;
        m04_axi_rresp     : in std_logic_vector(1 downto 0)


    );
END cnic_top;

-------------------------------------------------------------------------------
ARCHITECTURE structure OF cnic_top IS

    COMPONENT ila_0
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
    END COMPONENT;


    ---------------------------------------------------------------------------
    -- SIGNAL DECLARATIONS  --
    --------------------------------------------------------------------------- 
    signal start_stop_tx : std_logic;

    signal packetiser_data_in_wr                : std_logic;
    signal packetiser_data                      : std_logic_vector(511 downto 0);
    signal swapped_packetiser_data              : std_logic_vector(511 downto 0);
    signal packetiser_data_to_player_rdy        : std_logic;
    signal packetiser_bytes_to_transmit         : std_logic_vector(13 downto 0);
    
    signal packetiser_data_to_player_rdy_b      : std_logic;
    signal packetiser_data_to_player_rdy_combo  : std_logic;
       
    signal header_modifier_data_in_wr           : std_logic;
    signal header_modifier_data                 : std_logic_vector(511 downto 0);
    signal header_modifier_bytes_to_transmit    : std_logic_vector(13 downto 0);

    signal to_packetiser_data_in_wr             : std_logic;
    signal to_packetiser_data                   : std_logic_vector(511 downto 0);
    signal to_packetiser_bytes_to_transmit      : std_logic_vector(13 downto 0);
   
    signal beamData : std_logic_vector(63 downto 0);
    signal beamPacketCount : std_logic_vector(36 downto 0);
    signal beamBeam : std_logic_vector(7 downto 0);
    signal beamFreqIndex : std_logic_vector(10 downto 0);
    signal beamValid : std_logic;
    signal cmac_ready : std_logic;
    signal i_reset_packet_player : std_logic;

    
    signal eth100G_reset : std_logic;
    signal eth100G_reset_b : std_logic;

    signal dbg_ILA_trigger, bdbg_ILA_triggerDel1, bdbg_ILA_trigger, bdbg_ILA_triggerDel2 : std_logic;
    
    signal rx_packet_size           : std_logic_vector(13 downto 0);     -- Max size is 9000.
    signal rx_reset_capture         : std_logic;
    signal rx_reset_counter         : std_logic;
    
    -- register interface
    signal config_rw                : t_config_rw;
    signal config_ro                : t_config_ro;
    
    signal data_to_hbm              : std_logic_vector(511 downto 0);
    signal data_to_hbm_wr           : std_logic;
    
    signal rx_packet_size_mod64b    : std_logic_vector(13 downto 0);
    signal packet_size_calc         : std_logic_vector(13 downto 0);
    signal packet_size_calc_b       : std_logic_vector(13 downto 0);
    signal packet_size_ceil         : std_logic_vector(5 downto 0) := "000000";

    signal rx_complete_s_axi        : std_logic;
    signal rx_complete_hbm          : std_logic;
    
begin
-------------------------------------------------------------------------------------------------------------    

config_ro.rx_complete   <= rx_complete_hbm OR rx_complete_s_axi;

-------------------------------------------------------------------------------------------------------------        
    rx_s_axi : entity cmac_s_axi_lib.s_axi_packet_capture 
    Port map ( 
        --------------------------------------------------------
        -- 100G 
        i_clk_100GE             => i_clk_100GE,
        i_eth100G_locked        => i_eth100G_locked,
        
        i_clk_300               => i_MACE_clk,
        i_clk_300_rst           => i_MACE_rst,
        
        
        i_rx_packet_size        => config_rw.rx_packet_size(13 downto 0),
        i_rx_reset_capture      => config_rw.rx_reset_capture,
        i_reset_counter         => config_rw.rx_reset_counter,
        o_target_count          => config_ro.debug_capture_filter_target,
        o_nontarget_count       => config_ro.debug_capture_filter_non_target,

        o_rx_complete           => rx_complete_s_axi,

        i_rx_packets_to_capture => config_rw.rx_packets_to_capture,

        -- 100G RX S_AXI interface ~322 MHz
        i_rx_axis_tdata         => i_rx_axis_tdata,
        i_rx_axis_tkeep         => i_rx_axis_tkeep,
        i_rx_axis_tlast         => i_rx_axis_tlast,
        o_rx_axis_tready        => o_rx_axis_tready,
        i_rx_axis_tuser         => i_rx_axis_tuser,
        i_rx_axis_tvalid        => i_rx_axis_tvalid,
        
        -- Data to HBM writer - 300 MHz
        o_data_to_hbm           => data_to_hbm,
        o_data_to_hbm_wr        => data_to_hbm_wr
    
    );
    
-------------------------------------------------------------------------------------------------------------    
    ARGS_register_HBM_PktController : entity HBM_PktController_lib.HBM_PktController_hbm_pktcontroller_reg
    port map (
        MM_CLK              => i_MACE_clk, 
        MM_RST              => i_MACE_rst, 
        SLA_IN              => i_HBM_Pktcontroller_Lite_axi_mosi,  -- IN    t_axi4_lite_mosi;
        SLA_OUT             => o_HBM_Pktcontroller_Lite_axi_miso,  -- OUT   t_axi4_lite_miso;

        CONFIG_FIELDS_RW    => config_rw, -- OUT t_config_rw;
        CONFIG_FIELDS_RO    => config_ro  
    );


-------------------------------------------------------------------------------------------------------------

config_ro.tx_running   <= config_rw.tx_enable;

HBM_controller_proc : process(i_MACE_clk)
begin
    if rising_edge(i_MACE_clk) then
        if config_rw.rx_reset_capture = '1' then
            packet_size_ceil(0)             <= config_rw.rx_packet_size(5) OR config_rw.rx_packet_size(4) OR config_rw.rx_packet_size(3) OR config_rw.rx_packet_size(2) OR config_rw.rx_packet_size(1) OR config_rw.rx_packet_size(0); 
            packet_size_calc(13 downto 6)   <= std_logic_vector(unsigned(config_rw.rx_packet_size(13 downto 6)) + unsigned(packet_size_ceil));
            packet_size_calc(5 downto 0)    <= "000000";
            
            -- add extra 64 bytes for timestamp/metadata vector.
            packet_size_calc_b(13 downto 6) <= std_logic_vector(unsigned(packet_size_calc(13 downto 6)) + x"01");
            packet_size_calc_b(5 downto 0)  <= packet_size_calc(5 downto 0);  
             
            rx_packet_size_mod64b           <= packet_size_calc_b;        
        end if;
    end if;
end process;

i_HBM_PktController : entity HBM_PktController_lib.HBM_PktController
    port map (
        clk_freerun                     => clk_freerun, 
        -- shared memory interface clock (300 MHz)
        i_shared_clk                    => i_MACE_clk, -- in std_logic;
        i_shared_rst                    => i_MACE_rst, -- in std_logic;

        o_reset_packet_player           => i_reset_packet_player, 

        ------------------------------------------------------------------------------------
        -- Data from CMAC module after CDC in shared memory clock domain
        i_data_from_cmac                => data_to_hbm,
        i_data_valid_from_cmac          => data_to_hbm_wr,

        ------------------------------------------------------------------------------------
        -- config and status registers interface
        -- rx
    	i_rx_packet_size                    => rx_packet_size_mod64b,--config_rw.packet_size(13 downto 0),
        i_rx_soft_reset                     => config_rw.rx_reset_capture,
        i_enable_capture                    => config_rw.rx_enable_capture,
        
        i_lfaa_bank1_addr                   => x"00000000",
        i_lfaa_bank2_addr                   => x"00000000",
        i_lfaa_bank3_addr                   => x"00000000",
        i_lfaa_bank4_addr                   => x"00000000",
        update_start_addr                   => '0',
        i_rx_bank_enable                    => config_rw.rx_bank_enable(3 downto 0),

        o_1st_4GB_rx_addr                   => config_ro.rx_hbm_1_end_addr,
        o_2nd_4GB_rx_addr                   => config_ro.rx_hbm_2_end_addr,
        o_3rd_4GB_rx_addr                   => config_ro.rx_hbm_3_end_addr,
        o_4th_4GB_rx_addr                   => config_ro.rx_hbm_4_end_addr,

        o_capture_done                      => rx_complete_hbm,
        o_num_packets_received              => config_ro.rx_packet_count_lo,

        -- tx
        i_tx_packet_size                    => config_rw.tx_packet_size(13 downto 0),
        i_start_tx                          => config_rw.tx_enable,
        i_reset_tx                          => config_rw.tx_reset,
      
        i_loop_tx                           => config_rw.tx_loop_enable,
        i_expected_number_of_loops          => config_rw.tx_loops,
        
        i_expected_total_number_of_4k_axi   => config_rw.tx_axi_transactions,               -- total number of reads out of HBM
        i_expected_number_beats_per_burst   => config_rw.tx_beats_per_burst(12 downto 0),   -- 1 x tx_beats_per_packet
        i_expected_beats_per_packet         => config_rw.tx_beats_per_packet,               -- number of cycles per packet rd.
        
        i_expected_packets_per_burst        => config_rw.tx_packets_per_burst,              -- hard coded to 1 as we don't burst currently.
	    i_expected_total_number_of_bursts   => config_rw.tx_bursts,                         -- total bursts will be 1 x total number of packets to send.
        
        i_time_between_bursts_ns            => config_rw.tx_burst_gap,                      -- GAP between start of packets
        
        i_readaddr                          => x"00000000", 
        update_readaddr                     => '0',

        o_tx_addr                           => open,
        o_tx_boundary_across_num            => open,
        o_axi_rvalid_but_fifo_full          => open,

        o_tx_complete                       => config_ro.tx_complete,
        o_tx_packets_to_mac(63 downto 32)   => config_ro.tx_packets_to_mac_hi,
        o_tx_packets_to_mac(31 downto 0)    => config_ro.tx_packets_to_mac_lo,
        o_tx_packet_count(63 downto 32)     => config_ro.tx_packet_count_hi,
        o_tx_packet_count(31 downto 0)      => config_ro.tx_packet_count_lo,
        ------------------------------------------------------------------------------------

        o_rd_fsm_debug                      => config_ro.debug_rd_fsm_debug(3 downto 0),
        o_output_fsm_debug                  => config_ro.debug_output_fsm_debug(3 downto 0),
        o_input_fsm_debug                   => config_ro.debug_input_fsm_debug(3 downto 0),
        
    ------------------------------------------------------------------------------------
        -- Data output, to the packetizer
            
        o_packetiser_data_in_wr         => packetiser_data_in_wr, 
        o_packetiser_data               => packetiser_data, 
        o_packetiser_bytes_to_transmit  => packetiser_bytes_to_transmit, 
        i_packetiser_data_to_player_rdy => packetiser_data_to_player_rdy, 
        
        -------------------------------------------------------------
        i_schedule_action   => i_schedule_action,
        -------------------------------------------------------------
        -- AXI bus to the shared memory. 
        -- This has the aw, b, ar and r buses (the w bus is on the output of the LFAA decode module)
        -- aw bus - write address
	-----------------------------------------------------------------
	-- M01
        m01_axi_awvalid => m01_axi_awvalid, -- out std_logic;
        m01_axi_awready => m01_axi_awready, -- in std_logic;
        m01_axi_awaddr  => m01_axi_awaddr,  
        m01_axi_awlen   => m01_axi_awlen,   -- out std_logic_vector(7 downto 0);
        --w bus
        m01_axi_wvalid  => m01_axi_wvalid,
        m01_axi_wdata   => m01_axi_wdata,
        --m01_axi_wstrb   => m01_axi_wstrb,
        m01_axi_wlast   => m01_axi_wlast,
        m01_axi_wready  => m01_axi_wready,
        -- ar bus - read address
        m01_axi_arvalid => m01_axi_arvalid, -- out std_logic;
        m01_axi_arready => m01_axi_arready, -- in std_logic;
        m01_axi_araddr  => m01_axi_araddr,  
        m01_axi_arlen   => m01_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid  => m01_axi_rvalid,  -- in std_logic;
        m01_axi_rready  => m01_axi_rready,  -- out std_logic;
        m01_axi_rdata   => m01_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m01_axi_rlast   => m01_axi_rlast,   -- in std_logic;
        m01_axi_rresp   => m01_axi_rresp,    -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- M02
	    m02_axi_awvalid => m02_axi_awvalid, -- out std_logic;
        m02_axi_awready => m02_axi_awready, -- in std_logic;
        m02_axi_awaddr  => m02_axi_awaddr,  
        m02_axi_awlen   => m02_axi_awlen,   -- out std_logic_vector(7 downto 0);
        --w bus
        m02_axi_wvalid  => m02_axi_wvalid,
        m02_axi_wdata   => m02_axi_wdata,
        --m02_axi_wstrb   => m02_axi_wstrb,
        m02_axi_wlast   => m02_axi_wlast,
        m02_axi_wready  => m02_axi_wready,
        -- ar bus - read address
        m02_axi_arvalid => m02_axi_arvalid, -- out std_logic;
        m02_axi_arready => m02_axi_arready, -- in std_logic;
        m02_axi_araddr  => m02_axi_araddr,  
        m02_axi_arlen   => m02_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m02_axi_rvalid  => m02_axi_rvalid,  -- in std_logic;
        m02_axi_rready  => m02_axi_rready,  -- out std_logic;
        m02_axi_rdata   => m02_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m02_axi_rlast   => m02_axi_rlast,   -- in std_logic;
        m02_axi_rresp   => m02_axi_rresp,    -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- m03
	    m03_axi_awvalid => m03_axi_awvalid, -- out std_logic;
        m03_axi_awready => m03_axi_awready, -- in std_logic;
        m03_axi_awaddr  => m03_axi_awaddr,  
        m03_axi_awlen   => m03_axi_awlen,   -- out std_logic_vector(7 downto 0);
        --w bus
        m03_axi_wvalid  => m03_axi_wvalid,
        m03_axi_wdata   => m03_axi_wdata,
        --m03_axi_wstrb   => m03_axi_wstrb,
        m03_axi_wlast   => m03_axi_wlast,
        m03_axi_wready  => m03_axi_wready,
        -- ar bus - read address
        m03_axi_arvalid => m03_axi_arvalid, -- out std_logic;
        m03_axi_arready => m03_axi_arready, -- in std_logic;
        m03_axi_araddr  => m03_axi_araddr,  
        m03_axi_arlen   => m03_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m03_axi_rvalid  => m03_axi_rvalid,  -- in std_logic;
        m03_axi_rready  => m03_axi_rready,  -- out std_logic;
        m03_axi_rdata   => m03_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m03_axi_rlast   => m03_axi_rlast,   -- in std_logic;
        m03_axi_rresp   => m03_axi_rresp,    -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- m04
	    m04_axi_awvalid => m04_axi_awvalid, -- out std_logic;
        m04_axi_awready => m04_axi_awready, -- in std_logic;
        m04_axi_awaddr  => m04_axi_awaddr,  
        m04_axi_awlen   => m04_axi_awlen,   -- out std_logic_vector(7 downto 0);
        --w bus
        m04_axi_wvalid  => m04_axi_wvalid,
        m04_axi_wdata   => m04_axi_wdata,
        --m04_axi_wstrb   => m04_axi_wstrb,
        m04_axi_wlast   => m04_axi_wlast,
        m04_axi_wready  => m04_axi_wready,
        -- ar bus - read address
        m04_axi_arvalid => m04_axi_arvalid, -- out std_logic;
        m04_axi_arready => m04_axi_arready, -- in std_logic;
        m04_axi_araddr  => m04_axi_araddr,  
        m04_axi_arlen   => m04_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m04_axi_rvalid  => m04_axi_rvalid,  -- in std_logic;
        m04_axi_rready  => m04_axi_rready,  -- out std_logic;
        m04_axi_rdata   => m04_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m04_axi_rlast   => m04_axi_rlast,   -- in std_logic;
        m04_axi_rresp   => m04_axi_rresp    -- in std_logic_vector(1 downto 0);

    );

-----------------------------------------------------------------------------------------
LBUS_VECTOR_GEN : IF g_LBUS_CMAC GENERATE
    -- Swap the packetizer data because of  bizarre CMAC 512 bit vector usage 
    GEN_SWITCHER:
    for n in 0 to 3 generate
    begin
        ROO:
        for i in 0 to 15 generate
            swapped_packetiser_data((128*n + 127 - i*8) downto (128*n + 127 - i*8 -7)) <= packetiser_data((128*n + i*8+7) downto (128*n+i*8));
        end generate ROO;
    end generate GEN_SWITCHER;
    
END GENERATE;

STREAMING_AXI_VECTOR_GEN : IF (NOT g_LBUS_CMAC) GENERATE
-- byte 0 = 7->0, byte 64 = 511 -> 504, no 128 bit swaps like LBUS.
    swapped_packetiser_data <= packetiser_data;


END GENERATE;    

-----------------------------------------------------------------------------------------    
-- Intercept UDP packet and modifier logic
-----------------------------------------------------------------------------------------   

data_mux_to_packetiser_proc : process(i_MACE_clk)
begin
    if rising_edge(i_MACE_clk) then

        if config_rw.tx_header_update(0) = '0' then
            to_packetiser_bytes_to_transmit     <= packetiser_bytes_to_transmit;
            to_packetiser_data                  <= swapped_packetiser_data;
            to_packetiser_data_in_wr            <= packetiser_data_in_wr;
        else
            to_packetiser_bytes_to_transmit     <= header_modifier_bytes_to_transmit;
            to_packetiser_data                  <= header_modifier_data;
            to_packetiser_data_in_wr            <= header_modifier_data_in_wr;
        end if;

    end if;
end process;
    
header_mod : entity PSR_Packetiser_lib.CODIF_header_modifier
    Port Map( 
        i_clk                               => i_MACE_clk,
        i_reset                             => i_reset_packet_player,
        
        ----------------------------
        -- Math offsets for header incremeting
        i_codif_header_packets_per_frame	=> config_rw.tx_codif_header_packets_per_frame,
        i_codif_header_packets_epoch_offset => config_rw.tx_codif_header_packets_epoch_offset,
        i_codif_header_frame_initial_value	=> config_rw.tx_codif_header_frame_initial_value,
        
        -- FROM THE HBM_packet_controller 
        i_bytes_to_transmit                 => packetiser_bytes_to_transmit,
        i_data_to_player                    => swapped_packetiser_data,
        i_data_to_player_wr                 => packetiser_data_in_wr,
        
        -- TO THE Packet_player for CMAC
        o_bytes_to_transmit                 => header_modifier_bytes_to_transmit,
        o_data_to_player                    => header_modifier_data,
        o_data_to_player_wr                 => header_modifier_data_in_wr      
    
    );
    

-----------------------------------------------------------------------------------------    
-- Packetiser
-----------------------------------------------------------------------------------------  

    eth100G_reset <= not(i_eth100G_locked);

    i_packet_player : entity PSR_Packetiser_lib.packet_player 
        Generic Map(
            LBUS_TO_CMAC_INUSE      => g_LBUS_CMAC,      -- FUTURE WORK to IMPLEMENT AXI
            PLAYER_CDC_FIFO_DEPTH   => 512        
            -- FIFO is 512 Wide, 9KB packets = 73728 bits, 512 * 256 = 131072, 256 depth allows ~1.88 9K packets, we are target packets sizes smaller than this.
        )
        Port map ( 
            i_clk400                => i_MACE_clk, 
            i_reset_400             => i_reset_packet_player,
        
            i_cmac_clk              => i_clk_100GE,
            i_cmac_clk_rst          => eth100G_reset,
            
            i_bytes_to_transmit     => to_packetiser_bytes_to_transmit,   --packetiser_bytes_to_transmit,    -- 
            i_data_to_player        => to_packetiser_data,                --swapped_packetiser_data, 
            i_data_to_player_wr     => to_packetiser_data_in_wr,          --packetiser_data_in_wr,
            o_data_to_player_rdy    => packetiser_data_to_player_rdy,
            
            o_cmac_ready            => cmac_ready,
                   
            -- streaming AXI to CMAC
            o_tx_axis_tdata         => o_tx_axis_tdata,
            o_tx_axis_tkeep         => o_tx_axis_tkeep,
            o_tx_axis_tvalid        => o_tx_axis_tvalid,
            o_tx_axis_tlast         => o_tx_axis_tlast,
            o_tx_axis_tuser         => o_tx_axis_tuser,
            i_tx_axis_tready        => i_tx_axis_tready,
        
            -- LBUS to CMAC
            o_data_to_transmit      => o_data_tx_sosi,
            i_data_to_transmit_ctl  => i_data_tx_siso
        );
  
--        i_clk_100GE_b       : in std_logic;
--        i_eth100G_locked_b  : in std_logic;
-- ZERO THIS OUT FOR THE MOMENT, until second interface is connected up.
        o_tx_axis_tdata_b   <= zero_512;
        o_tx_axis_tkeep_b   <= zero_64; 
        o_tx_axis_tvalid_b  <= '0';
        o_tx_axis_tlast_b   <= '0';
        o_tx_axis_tuser_b   <= '0';
--        i_tx_axis_tready_b  : in STD_LOGIC;

--    eth100G_reset_b <= not(i_eth100G_locked_b);
        
--    packet_player_100G_B : entity PSR_Packetiser_lib.packet_player 
--        Generic Map(
--            LBUS_TO_CMAC_INUSE      => g_LBUS_CMAC,      -- FUTURE WORK to IMPLEMENT AXI
--            PLAYER_CDC_FIFO_DEPTH   => 512        
--            -- FIFO is 512 Wide, 9KB packets = 73728 bits, 512 * 256 = 131072, 256 depth allows ~1.88 9K packets, we are target packets sizes smaller than this.
--        )
--        Port map ( 
--            i_clk400                => i_MACE_clk, 
--            i_reset_400             => i_reset_packet_player,
        
--            i_cmac_clk              => i_clk_100GE_b,
--            i_cmac_clk_rst          => eth100G_reset_b,
            
--            i_bytes_to_transmit     => header_modifier_bytes_to_transmit,   --packetiser_bytes_to_transmit,    -- 
--            i_data_to_player        => header_modifier_data,                --swapped_packetiser_data, 
--            i_data_to_player_wr     => header_modifier_data_in_wr,          --packetiser_data_in_wr,
--            o_data_to_player_rdy    => packetiser_data_to_player_rdy_b,
            
--            o_cmac_ready            => open,
                   
--            -- streaming AXI to CMAC
--            o_tx_axis_tdata         => o_tx_axis_tdata_b,
--            o_tx_axis_tkeep         => o_tx_axis_tkeep_b,
--            o_tx_axis_tvalid        => o_tx_axis_tvalid_b,
--            o_tx_axis_tlast         => o_tx_axis_tlast_b,
--            o_tx_axis_tuser         => o_tx_axis_tuser_b,
--            i_tx_axis_tready        => i_tx_axis_tready_b,
        
--            -- LBUS to CMAC
--            o_data_to_transmit      => open,
--            i_data_to_transmit_ctl  => i_data_tx_siso
--        );
  
    
    packetiser_data_to_player_rdy_combo     <= packetiser_data_to_player_rdy_b AND packetiser_data_to_player_rdy;
 ---------------------------------------------------------------------------------------------------------------------------------------
-- ILA for debugging

debug_gen : IF g_DEBUG_ILA GENERATE
    cnic_ila : ila_0
    port map (
        clk                     => i_MACE_clk, 
        probe0(13 downto 0)     => config_rw.rx_packet_size(13 downto 0),
        probe0(14)              => packet_size_ceil(0),
        probe0(28 downto 15)    => packet_size_calc,
        probe0(29)              => '0', 
        probe0(43 downto 30)    => rx_packet_size_mod64b,
        probe0(44)              => config_rw.rx_reset_capture,
        probe0(191 downto 45)   => (others => '0')
    );
    
  
    
END GENERATE;    

END structure;
