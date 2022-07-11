----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: Nov 2020
-- Design Name: Atomic COTS
-- Module Name: packetizer100G_Top - RTL
-- Target Devices: Alveo U50 
-- Tool Versions: 2021.1
-- 
-- 
-- This module will take the output product from the signal processing chain.
-- generate a UDP IPv4 packet that will be fed into the 100G Ethernet interface.
--
-- Source data is arriving at 400MHz
-- Emptying into the Ethernet HARD ip at 322 MHz
-- 

--Required to make the full ethernet frame except interpacket gap and final crc
--All this information can be referenced from
--SKA1 CSP Correlator and Beamformer to Pulsar Engine Interface Control Document 
--Xilinx Docs PG203 - Ultrascale+ Devices Integrated 100G Ethernet subsystem


library IEEE, axi4_lib, technology_lib, PSR_Packetiser_lib, signal_processing_common, xil_defaultlib, xpm, common_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use xpm.vcomponents.all;
use PSR_Packetiser_lib.ethernet_pkg.ALL;
use PSR_Packetiser_lib.CbfPsrHeader_pkg.ALL;
use axi4_lib.axi4_stream_pkg.ALL;
use axi4_lib.axi4_lite_pkg.ALL;
use axi4_lib.axi4_full_pkg.ALL;
use common_lib.common_pkg.ALL;

USE technology_lib.tech_mac_100g_pkg.ALL;
USE PSR_Packetiser_lib.Packetiser_packetiser_reg_pkg.ALL;


library UNISIM;
use UNISIM.VComponents.all;

entity psr_packetiser100G_Top is
    Generic (
        CMAC_IS_LBUS            : BOOLEAN := TRUE;
        
        g_PST_beamformer_version: STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0014";
        g_DEBUG_ILA             : BOOLEAN := FALSE;
        ARGS_RAM                : BOOLEAN := FALSE;
        g_TB_RUNNING            : BOOLEAN := FALSE;
        g_PSN_BEAM_REGISTERS    : INTEGER := 16;        -- number of BEAMS EXPECTED TO PASS THROUGH THE PACKETISER.
        RESET_INTERNAL          : BOOLEAN := TRUE;
        
        Number_of_stream        : INTEGER := 3;         -- MAX 3
        
        stream_1_packet_type    : INTEGER := 0;         -- 0 - Pass through, 1 - CODIF, 2 - LFAA, 3 - PST, 4 - PSS
        stream_2_packet_type    : INTEGER := 1;         -- 0 - Pass through, 1 - CODIF, 2 - LFAA, 3 - PST, 4 - PSS
        stream_3_packet_type    : INTEGER := 1          -- 0 - Pass through, 1 - CODIF, 2 - LFAA, 3 - PST, 4 - PSS       
    
    );
    Port ( 
        -- ~322 MHz
        i_cmac_clk                      : in std_logic;
        i_cmac_rst                      : in std_logic; -- we are assuming currently that all Ethernet will be point to point so if the RX is locked we will transmit.
        
        -- ~400 MHz
        i_packetiser_clk                : in std_logic;
        i_packetiser_rst                : in std_logic;
        
        -- LBUS to CMAC
        o_data_to_transmit                  : out t_lbus_sosi;
        i_data_to_transmit_ctl              : in t_lbus_siso;
        
        -- AXI to CMAC interface to be implemented

        
        -- signals from signal processing/HBM/the moon/etc
        packet_stream_ctrl                  : in packetiser_stream_ctrl;
        
        packet_stream_stats                 : out t_packetiser_stats((Number_of_stream-1) downto 0);
                
        packet_stream                       : in t_packetiser_stream_in((Number_of_stream-1) downto 0);
        packet_stream_out                   : out t_packetiser_stream_out((Number_of_stream-1) downto 0);
        
        packet_config                       : in packetiser_config_in;  
        packet_config_out                   : out t_packetiser_config_out((Number_of_stream-1) downto 0)  
        
    
    );
end psr_packetiser100G_Top;

architecture RTL of psr_packetiser100G_Top is

COMPONENT ila_0
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
END COMPONENT;

COMPONENT ila_1
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(575 DOWNTO 0)
    );
END COMPONENT;

signal stream_definition         : t_integer_arr(0 to 2) := (stream_1_packet_type,
                                                            stream_2_packet_type,
                                                            stream_3_packet_type);


signal clock_400_rst            : std_logic := '1';

signal power_up_rst_clock_400   : std_logic_vector(31 downto 0) := c_ones_dword;

signal arb_sel_count            : integer range 0 to (Number_of_stream-1);

signal data_to_player_wr_sel_d  : STD_LOGIC;

signal bytes_to_transmit_sel    : STD_LOGIC_VECTOR(13 downto 0);     -- 
signal data_to_player_sel       : STD_LOGIC_VECTOR(511 downto 0);
signal data_to_player_wr_sel    : STD_LOGIC;
signal data_to_player_rdy_sel   : STD_LOGIC;

signal bytes_to_transmit        : t_slv_14_arr((Number_of_stream-1) downto 0);
signal data_to_player           : t_slv_512_arr((Number_of_stream-1) downto 0);
signal data_to_player_wr        : STD_LOGIC_VECTOR((Number_of_stream-1) downto 0);
signal data_to_player_rdy       : STD_LOGIC_VECTOR((Number_of_stream-1) downto 0);

signal invalid_packet           : STD_LOGIC_VECTOR((Number_of_stream-1) downto 0);

signal stream_enable            : STD_LOGIC_VECTOR((Number_of_stream-1) downto 0);

signal MAC_locked_clk400        : std_logic;

signal packet_former_reset      : std_logic;

signal o_data_to_transmit_int   : t_lbus_sosi;

signal checked_data             : t_packetiser_stream_in((Number_of_stream-1) downto 0);
signal to_checked_data          : t_packetiser_stream_out((Number_of_stream-1) downto 0);

begin


------------------------------------------
-- POWER UP RESETS, might move this to higher level but it is node specific ATM.
reset_proc_clk400: process(i_packetiser_clk)
begin
    if rising_edge(i_packetiser_clk) then
        -- power up reset logic
        if power_up_rst_clock_400(31) = '1' then
            power_up_rst_clock_400(31 downto 0) <= power_up_rst_clock_400(30 downto 0) & '0';
            clock_400_rst   <= '1';
        else
            clock_400_rst   <= '0';
        end if;
    end if;
end process;


-- retime the 100G enable to fold into reset for 400 MHZ CD of the packetiser.
xpm_cdc_pulse_inst : xpm_cdc_single
generic map (
    DEST_SYNC_FF    => 4,   
    INIT_SYNC_FF    => 1,   
    SRC_INPUT_REG   => 1,   
    SIM_ASSERT_CHK  => 0    
)
port map (
    dest_clk        => i_packetiser_clk,   
    dest_out        => MAC_locked_clk400,         
    src_clk         => i_cmac_clk,    
    src_in          => i_cmac_rst
);

packet_former_reset <= clock_400_rst OR (MAC_locked_clk400);

------------------------------------------------------------------------------------
-- GENERATE BASED ON STREAMS, 3 for PST.

packet_gen : for i in 0 to (Number_of_stream-1) GENERATE
------------------------------------------------------------------------------------

    PST_injest : entity PSR_Packetiser_lib.packet_length_check port map( 
            i_clk400                        => i_packetiser_clk,
            i_reset_400                     => packet_former_reset,
            
            o_invalid_packet                => invalid_packet(i),
            i_stream_enable                 => stream_enable(i),
            i_wr_to_cmac                    => data_to_player_wr(i),
            
            o_stats                         => packet_stream_stats(i),
        
            i_packetiser_data_in            => packet_stream(i),
            o_packetiser_data_out           => packet_stream_out(i),
            
            o_packetiser_data_to_former     => checked_data(i),
            i_packetiser_data_to_former     => to_checked_data(i)
            
        );
    
    
    ------------------------------------------------------------------------------------
    
    PST_packetiser : entity PSR_Packetiser_lib.packet_former generic map(
            g_INSTANCE                  => i,
            g_DEBUG_ILA                 =>  FALSE,
            g_TEST_PACKET_GEN           =>  TRUE,
            
            g_LE_DATA_SWAPPING          =>  FALSE,
            
            g_PST_beamformer_version    => g_PST_beamformer_version,
            
            g_PSN_BEAM_REGISTERS        =>  16,
            METADATA_HEADER_BYTES       =>  96,
            WEIGHT_CHAN_SAMPLE_BYTES    =>  6192      -- 6192 for LOW PST, 4626 for LOW PSS
        
        )
        Port map ( 
            i_clk400                => i_packetiser_clk,
            i_reset_400             => packet_former_reset,
            
            ---------------------------
            -- Stream interface
            i_packetiser_data_in    => checked_data(i),
            o_packetiser_data_out   => to_checked_data(i),
        
            i_packetiser_reg_in     => packet_config,
            o_packetiser_reg_out    => packet_config_out(i),
            
            i_packetiser_ctrl       => packet_stream_ctrl,
    
    
            -- Aligned packet for transmitting
            o_bytes_to_transmit     => bytes_to_transmit(i), 
            o_data_to_player        => data_to_player(i),
            o_data_to_player_wr     => data_to_player_wr(i),
            i_data_to_player_rdy    => data_to_player_rdy(i),
        
            -- debug
            o_stream_enable         => stream_enable(i)
        
        );

data_to_player_rdy(i)   <=  '1' when data_to_player_rdy_sel = '1' AND arb_sel_count = i else
                            '0';


END GENERATE;
---------------------------------------------------------------------------------------------------------------------------------------
-- Simple round robin access.
-- Assume that PST is providing data at a constant, repeatable rate and pattern from each of the 3 pipelines.
-- it will be as simple as move from one pipe to the next intially.


packetiser_arb_proc : process (i_packetiser_clk)
begin
    if rising_edge(i_packetiser_clk) then
        if packet_former_reset = '1' then
            arb_sel_count           <= 0;
            data_to_player_wr_sel   <= '0';
        else
            data_to_player_wr_sel_d <= data_to_player_wr_sel;
            
            if (data_to_player_wr_sel_d = '1' and data_to_player_wr_sel = '0') OR (invalid_packet(arb_sel_count) = '1') then
                if arb_sel_count = (Number_of_stream-1) then
                    arb_sel_count <= 0;
                else
                    arb_sel_count <= arb_sel_count + 1;
                end if;
            end if;
            
            
            bytes_to_transmit_sel   <= bytes_to_transmit(arb_sel_count);
            data_to_player_sel      <= data_to_player(arb_sel_count);
            data_to_player_wr_sel   <= data_to_player_wr(arb_sel_count);
            --data_to_player_rdy_sel  <= data_to_player_rdy(arb_sel_count);

        end if;
    end if;
end process;

---------------------------------------------------------------------------------------------------------------------------------------


playout : entity PSR_Packetiser_lib.packet_player 
    generic map(
        LBUS_TO_CMAC_INUSE      => TRUE,      -- FUTURE WORK to IMPLEMENT AXI
        PLAYER_CDC_FIFO_DEPTH   => 256        -- FIFO is 512 Wide, 9KB packets = 73728 bits, 512 * 256 = 131072, 256 depth allows ~1.88 9K packets, we are target packets sizes smaller than this.
    )
    port map ( 
        i_clk400                => i_packetiser_clk,
        i_reset_400             => packet_former_reset,
    
        i_cmac_clk              => i_cmac_clk,
        i_cmac_clk_rst          => i_cmac_rst,
        
        i_bytes_to_transmit     => bytes_to_transmit_sel,
        i_data_to_player        => data_to_player_sel,
        i_data_to_player_wr     => data_to_player_wr_sel,
        o_data_to_player_rdy    => data_to_player_rdy_sel,
        
        o_cmac_ready            => open,
    
        -- LBUS to CMAC
        o_data_to_transmit      => o_data_to_transmit_int,
        i_data_to_transmit_ctl  => i_data_to_transmit_ctl
    );
	
	o_data_to_transmit         <= o_data_to_transmit_int;
---------------------------------------------------------------------------------------------------------------------------------------
-- ILA for debugging
packetiser_top_debug : IF g_DEBUG_ILA GENERATE

    packetiser_ila : ila_0
    port map (
        clk                     => i_packetiser_clk, 
        probe0(127 downto 0)    => data_to_player(0)(127 downto 0), 
        probe0(128)             => data_to_player_wr(0), 
        probe0(142 downto 129)  => bytes_to_transmit(0),
        probe0(143)             => data_to_player_rdy(0), 
        probe0(191 downto 144)  => (others => '0')
    );
    
    CMAC_ila : ila_0
    port map (
        clk                     => i_cmac_clk, 
        probe0(0)               => i_data_to_transmit_ctl.ready,
        probe0(1)               => i_data_to_transmit_ctl.overflow,
        probe0(2)               => i_data_to_transmit_ctl.underflow,
        probe0(3)               => '0',
        probe0(7 downto 4)      => o_data_to_transmit_int.sop,
        probe0(11 downto 8)     => o_data_to_transmit_int.eop,
        probe0(15 downto 12)    => o_data_to_transmit_int.empty(0),
        probe0(19 downto 16)    => o_data_to_transmit_int.empty(1),
        probe0(23 downto 20)    => o_data_to_transmit_int.empty(2),
        probe0(27 downto 24)    => o_data_to_transmit_int.empty(3),
        probe0(28)              => '0', 
        probe0(29)              => o_data_to_transmit_int.valid(0),
        probe0(30)              => o_data_to_transmit_int.valid(1),
        probe0(31)              => o_data_to_transmit_int.valid(2),
        probe0(32)              => o_data_to_transmit_int.valid(3),
        probe0(33)              => '0',
        probe0(161 downto 34)   => o_data_to_transmit_int.data(127 downto 0),                 
        probe0(191 downto 162)  => (others => '0')
    );
end generate;
    
end RTL;
