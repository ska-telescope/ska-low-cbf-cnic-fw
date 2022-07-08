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

LIBRARY IEEE, common_lib, axi4_lib, cnic_lib;
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
        g_MODIFIER_HEADER_BLOCK         : BOOLEAN := TRUE;
        g_LBUS_CMAC                     : BOOLEAN := FALSE

    );
    port (
        clk_freerun : in std_logic;
        -----------------------------------------------------------------------
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
        m01_axi_awvalid  : out std_logic;
        m01_axi_awready  : in std_logic;
        m01_axi_awaddr   : out std_logic_vector(32 downto 0);
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
        m01_axi_araddr    : out std_logic_vector(32 downto 0);
        m01_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid    : in std_logic;
        m01_axi_rready    : out std_logic;
        m01_axi_rdata     : in std_logic_vector(511 downto 0);
        m01_axi_rlast     : in std_logic;
        m01_axi_rresp     : in std_logic_vector(1 downto 0)
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
    -- signal dataMismatch_dbg, dataMismatch, datamismatchBFclk : std_logic;
    
begin
    
    i_HBM_PktController : entity HBM_PktController_lib.HBM_PktController
    port map(
        clk_freerun => clk_freerun, 
        -- shared memory interface clock (300 MHz)
        i_shared_clk => i_MACE_clk, -- in std_logic;
        i_shared_rst => i_MACE_rst, -- in std_logic;

        o_reset_packet_player => i_reset_packet_player, 

        --AXI Lite Interface for registers
        i_saxi_mosi => i_HBM_Pktcontroller_Lite_axi_mosi , -- in t_axi4_lite_mosi;
        o_saxi_miso => o_HBM_Pktcontroller_Lite_axi_miso , -- out t_axi4_lite_miso;

        --Register outputs
        o_start_stop_tx => start_stop_tx, -- reset output from a register in the corner turn; used to reset downstream modules.
    
        o_packetiser_data_in_wr => packetiser_data_in_wr, 
        o_packetiser_data => packetiser_data, 
        o_packetiser_bytes_to_transmit => packetiser_bytes_to_transmit, 
        i_packetiser_data_to_player_rdy => packetiser_data_to_player_rdy, 
        
        -------------------------------------------------------------
        i_schedule_action   => i_schedule_action,
        -------------------------------------------------------------
        -- AXI bus to the shared memory. 
        -- This has the aw, b, ar and r buses (the w bus is on the output of the LFAA decode module)
        -- aw bus - write address
        m01_axi_awvalid => m01_axi_awvalid, -- out std_logic;
        m01_axi_awready => m01_axi_awready, -- in std_logic;
        m01_axi_awaddr  => m01_axi_awaddr,  
        m01_axi_awlen   => m01_axi_awlen,   -- out std_logic_vector(7 downto 0);
        -- b bus - write response
        m01_axi_bvalid  => m01_axi_bvalid, -- in std_logic;
        m01_axi_bresp   => m01_axi_bresp,  -- in std_logic_vector(1 downto 0);
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
        m01_axi_rresp   => m01_axi_rresp    -- in std_logic_vector(1 downto 0);
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
gen_mod : IF g_MODIFIER_HEADER_BLOCK GENERATE    
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

not_gen_mod : IF (NOT g_MODIFIER_HEADER_BLOCK) GENERATE

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
