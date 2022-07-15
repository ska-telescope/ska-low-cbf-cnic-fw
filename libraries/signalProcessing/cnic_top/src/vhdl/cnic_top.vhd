-------------------------------------------------------------------------------
--
-- File Name: cnic_top.vhd
-- Contributing Authors: Jason van Aardt, jason.vanaardt@csiro.au
-- Type: RTL
-- Created: 27 October 2021
--
-- Title: Top Level for the cnic (Traffic Generator)
--
--
--  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
--  See the file LICENSE for more info.
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
        
        i_clk_100GE         : in std_logic;
        i_eth100G_locked    : in std_logic;
        -----------------------------------------------------------------------

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
        
        -- traffic stats
        o_time_between_packets_largest  : OUT STD_LOGIC_VECTOR(15 downto 0);
        o_bytes_transmitted_last_hsec   : OUT STD_LOGIC_VECTOR(31 downto 0);
        
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
        m01_axi_awvalid   : out std_logic;
        m01_axi_awready   : in  std_logic;
        m01_axi_awaddr    : out std_logic_vector(31 downto 0);
        m01_axi_awlen     : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m01_axi_wvalid    : out std_logic;
        m01_axi_wready    : in  std_logic;
        m01_axi_wdata     : out std_logic_vector(511 downto 0);
        m01_axi_wstrb     : out std_logic_vector(63  downto 0);
        m01_axi_wlast     : out std_logic;
        -- ar bus - read address
        m01_axi_arvalid   : out std_logic;
        m01_axi_arready   : in  std_logic;
        m01_axi_araddr    : out std_logic_vector(31 downto 0);
        m01_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid    : in  std_logic;
        m01_axi_rready    : out std_logic;
        m01_axi_rdata     : in  std_logic_vector(511 downto 0);
        m01_axi_rlast     : in  std_logic;
        m01_axi_rresp     : in  std_logic_vector(1 downto 0);

	--------------------------------------------------------------------------
	-- m02
        m02_axi_awvalid   : out std_logic;
        m02_axi_awready   : in  std_logic;
        m02_axi_awaddr    : out std_logic_vector(31 downto 0);
        m02_axi_awlen     : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m02_axi_wvalid    : out std_logic;
        m02_axi_wready    : in  std_logic;
        m02_axi_wdata     : out std_logic_vector(511 downto 0);
        m02_axi_wstrb     : out std_logic_vector(63  downto 0);
        m02_axi_wlast     : out std_logic;
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
        m03_axi_awvalid   : out std_logic;
        m03_axi_awready   : in  std_logic;
        m03_axi_awaddr    : out std_logic_vector(31 downto 0);
        m03_axi_awlen     : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m03_axi_wvalid    : out std_logic;
        m03_axi_wready    : in  std_logic;
        m03_axi_wdata     : out std_logic_vector(511 downto 0);
        m03_axi_wstrb     : out std_logic_vector(63  downto 0);
        m03_axi_wlast     : out std_logic;
        -- ar bus - read address
        m03_axi_arvalid   : out std_logic;
        m03_axi_arready   : in  std_logic;
        m03_axi_araddr    : out std_logic_vector(31 downto 0);
        m03_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m03_axi_rvalid    : in  std_logic;
        m03_axi_rready    : out std_logic;
        m03_axi_rdata     : in  std_logic_vector(511 downto 0);
        m03_axi_rlast     : in  std_logic;
        m03_axi_rresp     : in  std_logic_vector(1 downto 0);

	--------------------------------------------------------------------------
	-- m04
        m04_axi_awvalid   : out std_logic;
        m04_axi_awready   : in  std_logic;
        m04_axi_awaddr    : out std_logic_vector(31 downto 0);
        m04_axi_awlen     : out std_logic_vector(7 downto 0);
        -- w bus - write data
        m04_axi_wvalid    : out std_logic;
        m04_axi_wready    : in  std_logic;
        m04_axi_wdata     : out std_logic_vector(511 downto 0);
        m04_axi_wstrb     : out std_logic_vector(63  downto 0);
        m04_axi_wlast     : out std_logic;
        -- ar bus - read address
        m04_axi_arvalid   : out std_logic;
        m04_axi_arready   : in  std_logic;
        m04_axi_araddr    : out std_logic_vector(31 downto 0);
        m04_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m04_axi_rvalid    : in  std_logic;
        m04_axi_rready    : out std_logic;
        m04_axi_rdata     : in  std_logic_vector(511 downto 0);
        m04_axi_rlast     : in  std_logic;
        m04_axi_rresp     : in  std_logic_vector(1 downto 0)
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

    signal packetiser_data_in_wr : std_logic;
    signal packetiser_data : std_logic_vector(511 downto 0);
    signal swapped_packetiser_data : std_logic_vector(511 downto 0);
    signal packetiser_data_to_player_rdy : std_logic;
    signal packetiser_bytes_to_transmit : std_logic_vector(13 downto 0);
    
    signal header_modifier_data_in_wr           : std_logic;
    signal header_modifier_data                 : std_logic_vector(511 downto 0);
    signal header_modifier_bytes_to_transmit    : std_logic_vector(13 downto 0);
   
    signal beamData : std_logic_vector(63 downto 0);
    signal beamPacketCount : std_logic_vector(36 downto 0);
    signal beamBeam : std_logic_vector(7 downto 0);
    signal beamFreqIndex : std_logic_vector(10 downto 0);
    signal beamValid : std_logic;
    signal cmac_ready : std_logic;
    signal i_reset_packet_player : std_logic;

    
    signal eth100G_reset : std_logic;

    signal dbg_ILA_trigger, bdbg_ILA_triggerDel1, bdbg_ILA_trigger, bdbg_ILA_triggerDel2 : std_logic;
    
    signal rx_packet_size       : std_logic_vector(13 downto 0);     -- Max size is 9000.
    signal rx_reset_capture     : std_logic;
    signal rx_reset_counter     : std_logic;
    signal rx_data_to_HBM       : std_logic_vector(511 downto 0);
    signal rx_data_to_HBM_wr    : std_logic;

begin
    
    rx_s_axi : entity cmac_s_axi_lib.s_axi_packet_capture 
    Port map ( 
        --------------------------------------------------------
        -- 100G 
        i_clk_100GE             => i_clk_100GE,
        i_eth100G_locked        => i_eth100G_locked,
        
        i_clk_300               => i_MACE_clk,
        i_clk_300_rst           => i_MACE_rst,
        
        
        i_rx_packet_size        => rx_packet_size,
        i_rx_reset_capture      => rx_reset_capture,
        i_reset_counter         => rx_reset_counter,
        o_target_count          => open,
        o_nontarget_count       => open,

        -- 100G RX S_AXI interface ~322 MHz
        i_rx_axis_tdata         => i_rx_axis_tdata,
        i_rx_axis_tkeep         => i_rx_axis_tkeep,
        i_rx_axis_tlast         => i_rx_axis_tlast,
        o_rx_axis_tready        => o_rx_axis_tready,
        i_rx_axis_tuser         => i_rx_axis_tuser,
        i_rx_axis_tvalid        => i_rx_axis_tvalid,
        
        -- Data to HBM writer - 300 MHz
        o_data_to_hbm           => rx_data_to_HBM,
        o_data_to_hbm_wr        => rx_data_to_HBM_wr
    );
    
-------------------------------------------------------------------------------------------------------------    
    i_HBM_PktController : entity HBM_PktController_lib.HBM_PktController
    port map (
        -- shared memory interface clock (300 MHz)
        i_shared_clk                    => i_MACE_clk, -- in std_logic;
        i_shared_rst                    => i_MACE_rst, -- in std_logic;

        i_data_from_cmac                => rx_data_to_HBM,
        i_data_valid_from_cmac          => rx_data_to_HBM_wr,

        o_packetiser_data_in_wr         => packetiser_data_in_wr, 
        o_packetiser_data               => packetiser_data, 
        o_packetiser_bytes_to_transmit  => packetiser_bytes_to_transmit, 
        i_packetiser_data_to_player_rdy => packetiser_data_to_player_rdy, 
      

        ------------------------------------------------------------------------------------
        -- config and status registers interface
        -- rx
        i_rx_packet_size                => (others => '0'),
        i_rx_soft_reset                 => '0',
        i_enable_capture                => '0',

        o_1st_4GB_rx_addr               => open,
        o_2nd_4GB_rx_addr               => open,
        o_3rd_4GB_rx_addr               => open,
        o_4th_4GB_rx_addr               => open,

        o_capture_done                  => open,
        o_num_packets_received          => open,

        -- tx
        i_tx_soft_reset                 => '0',
        i_tx_packet_size                => (others => '0'),
        i_start_tx                      => '0',

        o_num_packets_transmitted       => open,

        o_1st_4GB_tx_addr               => open,
        o_2nd_4GB_tx_addr               => open,
        o_3rd_4GB_tx_addr               => open,
        o_4th_4GB_tx_addr               => open,
        -----------------------------------------------------------------	
        -- AXI bus to the shared memory. 
        -- This has the aw, b, ar and r buses (the w bus is on the output of the LFAA decode module)
	-----------------------------------------------------------------
	-- M01
        m01_axi_awvalid                 => m01_axi_awvalid, -- out std_logic;
        m01_axi_awready                 => m01_axi_awready, -- in std_logic;
        m01_axi_awaddr                  => m01_axi_awaddr,  
        m01_axi_awlen                   => m01_axi_awlen,   -- out std_logic_vector(7 downto 0);
        m01_axi_wvalid                  => m01_axi_wvalid,
        m01_axi_wdata                   => m01_axi_wdata,
        m01_axi_wstrb                   => m01_axi_wstrb,
        m01_axi_wlast                   => m01_axi_wlast,
        m01_axi_wready                  => m01_axi_wready,

        -- ar bus - read address
        m01_axi_arvalid                 => m01_axi_arvalid, -- out std_logic;
        m01_axi_arready                 => m01_axi_arready, -- in std_logic;
        m01_axi_araddr                  => m01_axi_araddr,  
        m01_axi_arlen                   => m01_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid                  => m01_axi_rvalid,  -- in std_logic;
        m01_axi_rready                  => m01_axi_rready,  -- out std_logic;
        m01_axi_rdata                   => m01_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m01_axi_rlast                   => m01_axi_rlast,   -- in std_logic;
        m01_axi_rresp                   => m01_axi_rresp,   -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- M02
	m02_axi_awvalid                 => m02_axi_awvalid, -- out std_logic;
        m02_axi_awready                 => m02_axi_awready, -- in std_logic;
        m02_axi_awaddr                  => m02_axi_awaddr,  
        m02_axi_awlen                   => m02_axi_awlen,   -- out std_logic_vector(7 downto 0);
	m02_axi_wvalid                  => m02_axi_wvalid,
        m02_axi_wdata                   => m02_axi_wdata,
        m02_axi_wstrb                   => m02_axi_wstrb,
        m02_axi_wlast                   => m02_axi_wlast,
        m02_axi_wready                  => m02_axi_wready,

        -- ar bus - read address
        m02_axi_arvalid                 => m02_axi_arvalid, -- out std_logic;
        m02_axi_arready                 => m02_axi_arready, -- in std_logic;
        m02_axi_araddr                  => m02_axi_araddr,  
        m02_axi_arlen                   => m02_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m02_axi_rvalid                  => m02_axi_rvalid,  -- in std_logic;
        m02_axi_rready                  => m02_axi_rready,  -- out std_logic;
        m02_axi_rdata                   => m02_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m02_axi_rlast                   => m02_axi_rlast,   -- in std_logic;
        m02_axi_rresp                   => m02_axi_rresp,   -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- m03
	m03_axi_awvalid                 => m03_axi_awvalid, -- out std_logic;
        m03_axi_awready                 => m03_axi_awready, -- in std_logic;
        m03_axi_awaddr                  => m03_axi_awaddr,  
        m03_axi_awlen                   => m03_axi_awlen,   -- out std_logic_vector(7 downto 0);
        m03_axi_wvalid                  => m03_axi_wvalid,
        m03_axi_wdata                   => m03_axi_wdata,
        m03_axi_wstrb                   => m03_axi_wstrb,
        m03_axi_wlast                   => m03_axi_wlast,
        m03_axi_wready                  => m03_axi_wready,

	-- ar bus - read address
        m03_axi_arvalid                 => m03_axi_arvalid, -- out std_logic;
        m03_axi_arready                 => m03_axi_arready, -- in std_logic;
        m03_axi_araddr                  => m03_axi_araddr,  
        m03_axi_arlen                   => m03_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m03_axi_rvalid                  => m03_axi_rvalid,  -- in std_logic;
        m03_axi_rready                  => m03_axi_rready,  -- out std_logic;
        m03_axi_rdata                   => m03_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m03_axi_rlast                   => m03_axi_rlast,   -- in std_logic;
        m03_axi_rresp                   => m03_axi_rresp,    -- in std_logic_vector(1 downto 0);

	-----------------------------------------------------------------
	-- m04
	m04_axi_awvalid                 => m04_axi_awvalid, -- out std_logic;
        m04_axi_awready                 => m04_axi_awready, -- in std_logic;
        m04_axi_awaddr                  => m04_axi_awaddr,  
        m04_axi_awlen                   => m04_axi_awlen,   -- out std_logic_vector(7 downto 0);
        m04_axi_wvalid                  => m04_axi_wvalid,
        m04_axi_wdata                   => m04_axi_wdata,
        m04_axi_wstrb                   => m04_axi_wstrb,
        m04_axi_wlast                   => m04_axi_wlast,
        m04_axi_wready                  => m04_axi_wready,
	
	-- ar bus - read address
        m04_axi_arvalid                 => m04_axi_arvalid, -- out std_logic;
        m04_axi_arready                 => m04_axi_arready, -- in std_logic;
        m04_axi_araddr                  => m04_axi_araddr,  
        m04_axi_arlen                   => m04_axi_arlen,   -- out std_logic_vector(7 downto 0);
        -- r bus - read data
        m04_axi_rvalid                  => m04_axi_rvalid,  -- in std_logic;
        m04_axi_rready                  => m04_axi_rready,  -- out std_logic;
        m04_axi_rdata                   => m04_axi_rdata,   -- in std_logic_vector(511 downto 0);
        m04_axi_rlast                   => m04_axi_rlast,   -- in std_logic;
        m04_axi_rresp                   => m04_axi_rresp    -- in std_logic_vector(1 downto 0);
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
gen_mod : IF g_CODIF_MODIFIER_HEADER_BLOCK GENERATE    
    header_mod : entity PSR_Packetiser_lib.CODIF_header_modifier
    Port Map( 
        i_clk                   => i_MACE_clk,
        i_reset                 => i_reset_packet_player,
    
        -- FROM THE HBM_packet_controller 
        i_bytes_to_transmit     => packetiser_bytes_to_transmit,
        i_data_to_player        => swapped_packetiser_data,
        i_data_to_player_wr     => packetiser_data_in_wr,
        
        -- TO THE Packet_player for CMAC
        o_bytes_to_transmit     => header_modifier_bytes_to_transmit,
        o_data_to_player        => header_modifier_data,
        o_data_to_player_wr     => header_modifier_data_in_wr      
    
    );
    
END GENERATE;

not_gen_mod : IF (NOT g_CODIF_MODIFIER_HEADER_BLOCK) GENERATE

    header_modifier_bytes_to_transmit   <= packetiser_bytes_to_transmit;
    header_modifier_data                <= swapped_packetiser_data;
    header_modifier_data_in_wr          <= packetiser_data_in_wr;
    
END GENERATE;    
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
            
            i_bytes_to_transmit     => header_modifier_bytes_to_transmit,   --packetiser_bytes_to_transmit,    -- 
            i_data_to_player        => header_modifier_data,                --swapped_packetiser_data, 
            i_data_to_player_wr     => header_modifier_data_in_wr,          --packetiser_data_in_wr,
            o_data_to_player_rdy    => packetiser_data_to_player_rdy,
            
            o_cmac_ready            => cmac_ready,
            
            -- traffic stats
            o_time_between_packets_largest  => o_time_between_packets_largest,
            o_bytes_transmitted_last_hsec   => o_bytes_transmitted_last_hsec,
        
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
  

   
  
    
 ---------------------------------------------------------------------------------------------------------------------------------------
-- ILA for debugging

debug_gen : IF g_DEBUG_ILA GENERATE
    cnic_ila : ila_0
    port map (
        clk                     => i_MACE_clk, 
        probe0(127 downto 0)    => packetiser_data(127 downto 0),
        probe0(128)             => packetiser_data_in_wr,
        probe0(129)             => packetiser_data_to_player_rdy, 
        probe0(143 downto 130)  => packetiser_bytes_to_transmit,
        probe0(144)             => cmac_ready, 
        probe0(191 downto 145)  => (others => '0')
    );
    

    
END GENERATE;    

END structure;
