----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: Oct 2021
-- Design Name: TB_packetformer
-- 
-- 
-- test bench written to be used in Vivado
-- 
--
library IEEE,technology_lib, PSR_Packetiser_lib, signal_processing_common;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use PSR_Packetiser_lib.ethernet_pkg.ALL;
use PSR_Packetiser_lib.CbfPsrHeader_pkg.ALL;
use PSR_Packetiser_lib.Codifheader_pkg.ALL;


entity tb_codif_header is
--  Port ( );
end tb_codif_header;

architecture Behavioral of tb_codif_header is
CONSTANT S_AXI_DATA         : boolean := true;

signal clock_300 : std_logic := '0';    -- 3.33ns
signal clock_400 : std_logic := '0';    -- 2.50ns
signal clock_322 : std_logic := '0';    -- 3.11ns

signal testCount_400        : integer   := 0;
signal testCount_300        : integer   := 0;
signal testCount_322        : integer   := 0;

signal clock_400_rst        : std_logic := '1';
signal clock_300_rst        : std_logic := '1';
signal clock_322_rst        : std_logic := '1';

signal power_up_rst_clock_400   : std_logic_vector(31 downto 0) := c_ones_dword;
signal power_up_rst_clock_300   : std_logic_vector(31 downto 0) := c_ones_dword;
signal power_up_rst_clock_322   : std_logic_vector(31 downto 0) := c_ones_dword;

constant bytes_to_transmit      : integer := 2154;

signal loop_generator           : std_logic_vector(7 downto 0) := x"00";

-- FROM THE HBM_packet_controller 
signal i_bytes_to_transmit      : STD_LOGIC_VECTOR(13 downto 0);     -- 
signal i_data_to_player         : STD_LOGIC_VECTOR(511 downto 0);
signal i_data_to_player_wr      : STD_LOGIC;
        
        -- TO THE Packet_player for CMAC
signal o_bytes_to_transmit      : STD_LOGIC_VECTOR(13 downto 0);     -- 
signal o_data_to_player         : STD_LOGIC_VECTOR(511 downto 0);
signal o_data_to_player_wr      : STD_LOGIC;      

signal streaming_data           : std_logic_vector(511 downto 0);

signal streaming_data_LBUS      : std_logic_vector(511 downto 0);
signal streaming_data_S_AXI     : std_logic_vector(511 downto 0);

signal streaming_data_header    : std_logic_vector(511 downto 0);

signal little_endian_CODIF      : CODIFHeader;
signal little_endian_smallfields : std_logic_vector(15 downto 0);


signal ethernet_info            : ethernet_frame    := default_ethernet_frame;
signal ipv4_info                : IPv4_header       := default_ipv4_header;
signal udp_info                 : UDP_header        := default_UDP_header;
signal CODIF_info               : CODIFHeader       := default_CodifHeader;

begin

clock_300 <= not clock_300 after 3.33 ns;
clock_322 <= not clock_322 after 3.11 ns;
clock_400 <= not clock_400 after 2.50 ns;

i_bytes_to_transmit <= std_logic_vector(to_unsigned(bytes_to_transmit,14));

-------------------------------------------------------------------------------------------------------------
-- powerup resets for SIM
test_runner_proc_clk300: process(clock_300)
begin
    if rising_edge(clock_300) then
        -- power up reset logic
        if power_up_rst_clock_300(31) = '1' then
            power_up_rst_clock_300(31 downto 0) <= power_up_rst_clock_300(30 downto 0) & '0';
            clock_300_rst   <= '1';
            testCount_300   <= 0;
        else
            clock_300_rst   <= '0';
            testCount_300   <= testCount_300 + 1;
        end if;
    end if;
end process;

test_runner_proc_clk400: process(clock_400)
begin
    if rising_edge(clock_400) then
        -- power up reset logic
        if power_up_rst_clock_400(31) = '1' then
            power_up_rst_clock_400(31 downto 0) <= power_up_rst_clock_400(30 downto 0) & '0';
            testCount_400   <= 0;
            clock_400_rst   <= '1';
        else
            testCount_400   <= testCount_400 + 1;
            clock_400_rst   <= '0';
        end if;
    end if;
end process;

-------------------------------------------------------------------------------------------------------------
-- AXI or LBUS data.
    streaming_data_LBUS(127 downto 0)   <=  ethernet_info.dst_mac & 
                                            ethernet_info.src_mac & 
                                            ethernet_info.eth_type & 
                                            ipv4_info.version & 
                                            ipv4_info.header_length & 
                                            ipv4_info.type_of_service; 
    streaming_data_LBUS(255 downto 128) <=  ipv4_info.total_length & 
                                            ipv4_info.id & 
                                            ipv4_info.ip_flags & 
                                            ipv4_info.fragment_off & 
                                            ipv4_info.TTL & 
                                            ipv4_info.protocol & 
                                            ipv4_info.header_chk_sum & 
                                            ipv4_info.src_addr & 
                                            ipv4_info.dst_addr(31 downto 16);
    streaming_data_LBUS(383 downto 256) <=  ipv4_info.dst_addr(15 downto 0) & 
                                            udp_info.src_port & 
                                            udp_info.dst_port & 
                                            udp_info.length & 
                                            udp_info.checksum & 
                                            little_endian_CODIF.data_frame &
                                            little_endian_CODIF.epoch_offset(31 downto 16);
    streaming_data_LBUS(511 downto 384) <=  little_endian_CODIF.epoch_offset(15 downto 0) & 
                                            little_endian_CODIF.reference_epoch & 
                                            little_endian_CODIF.sample_size & 
                                            little_endian_smallfields & 
                                            little_endian_CODIF.reserved_field &
                                            little_endian_CODIF.alignment_period  &
                                            little_endian_CODIF.thread_ID &
                                            little_endian_CODIF.group_ID &
                                            little_endian_CODIF.secondary_ID;


GEN_LBUS_DATA : IF (NOT S_AXI_DATA) GENERATE
                                            
    streaming_data_header   <= streaming_data_LBUS;

END GENERATE;

GEN_S_AXI_DATA : IF (S_AXI_DATA) GENERATE

-- Swap from LBUS to S_AXI 
    QUAD: for n in 0 to 3 generate
        BYTE: for i in 0 to 15 generate
            swap_proc : process(clock_400)
            begin
                if rising_edge(clock_400) then
                    streaming_data_S_AXI(((128*n) + (i*8)+7) downto ((128*n)+(i*8)))   <= streaming_data_LBUS(((128*n) + 127 - (i*8)) downto ((128*n) + 127 - (i*8) - 7));
                end if;
            end process;
        end generate;
    end generate;
    
-- Convert LBUS to S_AXI                                         
    streaming_data_header   <= streaming_data_S_AXI;

END GENERATE;



-------------------------------------------------------------------------------------------------------------
run_proc : process(clock_400)
begin
    if rising_edge(clock_400) then
        if clock_400_rst = '1' then
            loop_generator <= x"00";
        else
            if loop_generator = x"21" then
                loop_generator <= x"05";
            else
                loop_generator  <= std_logic_vector(unsigned(loop_generator) + x"01");
            end if;
        end if;

        -- start at 20 cycles, emulate packet
        if loop_generator = x"08" then
            streaming_data  <= streaming_data_header; 

            i_data_to_player_wr     <= '1';
        
        elsif (loop_generator >= x"09") AND (loop_generator < x"20") then    
            streaming_data          <= c_ones_512;
            i_data_to_player_wr     <= '1';
        else
            streaming_data          <= zero_512;
            i_data_to_player_wr     <= '0';
        end if;



    end if;
end process;



i_data_to_player        <= streaming_data;

DUT : entity PSR_Packetiser_lib.CODIF_header_modifier 
    Generic Map (
        g_CODIF_frame_init      => 799990
    )
    Port Map ( 
        i_clk                   => clock_400,
        i_reset                 => clock_400_rst,
    
        -- FROM THE HBM_packet_controller 
        i_bytes_to_transmit     => i_bytes_to_transmit,
        i_data_to_player        => i_data_to_player,
        i_data_to_player_wr     => i_data_to_player_wr,
        
        -- TO THE Packet_player for CMAC
        o_bytes_to_transmit     => o_bytes_to_transmit,
        o_data_to_player        => o_data_to_player,
        o_data_to_player_wr     => o_data_to_player_wr      
    
    );



little_endian_CODIF.data_frame      <= CODIF_info.data_frame(7 downto 0) & CODIF_info.data_frame(15 downto 8) & CODIF_info.data_frame(23 downto 16) & CODIF_info.data_frame(31 downto 24);
little_endian_CODIF.epoch_offset    <= CODIF_info.epoch_offset(7 downto 0) & CODIF_info.epoch_offset(15 downto 8) & CODIF_info.epoch_offset(23 downto 16) & CODIF_info.epoch_offset(31 downto 24);
--    -- Word 1    
little_endian_CODIF.reference_epoch <= CODIF_info.reference_epoch;
little_endian_CODIF.sample_size     <= CODIF_info.sample_size;

little_endian_smallfields           <=  CODIF_info.small_fields.sample_representation & 
                                        CODIF_info.small_fields.cal_enabled &
                                        CODIF_info.small_fields.complex &
                                        CODIF_info.small_fields.invalid &
                                        CODIF_info.small_fields.Atypical & 
                                        CODIF_info.small_fields.protocol &
                                        CODIF_info.small_fields.version;

little_endian_CODIF.reserved_field      <= CODIF_info.reserved_field(7 downto 0) & CODIF_info.reserved_field(15 downto 8);
little_endian_CODIF.alignment_period    <= CODIF_info.alignment_period(7 downto 0) & CODIF_info.alignment_period(15 downto 8);

--    -- Word 2
little_endian_CODIF.thread_ID           <= CODIF_info.thread_ID(7 downto 0) & CODIF_info.thread_ID(15 downto 8);
little_endian_CODIF.group_ID            <= CODIF_info.group_ID(7 downto 0) & CODIF_info.group_ID(15 downto 8);
little_endian_CODIF.secondary_ID        <= CODIF_info.secondary_ID(7 downto 0) & CODIF_info.secondary_ID(15 downto 8);
little_endian_CODIF.station_ID          <= CODIF_info.station_ID(7 downto 0) & CODIF_info.station_ID(15 downto 8);
little_endian_CODIF.channels            <= CODIF_info.channels(7 downto 0) & CODIF_info.channels(15 downto 8);
little_endian_CODIF.sample_block_length <= CODIF_info.sample_block_length(7 downto 0) & CODIF_info.sample_block_length(15 downto 8);

little_endian_CODIF.data_array_length   <= CODIF_info.data_array_length(7 downto 0) & CODIF_info.data_array_length(15 downto 8) & CODIF_info.data_array_length(23 downto 16) & CODIF_info.data_array_length(31 downto 24);

little_endian_CODIF.sample_periods_per_alignment_period   <= CODIF_info.sample_periods_per_alignment_period(7 downto 0) & CODIF_info.sample_periods_per_alignment_period(15 downto 8) & 
                                                             CODIF_info.sample_periods_per_alignment_period(23 downto 16) & CODIF_info.sample_periods_per_alignment_period(31 downto 24) &
                                                             CODIF_info.sample_periods_per_alignment_period(39 downto 32) & CODIF_info.sample_periods_per_alignment_period(47 downto 40) & 
                                                             CODIF_info.sample_periods_per_alignment_period(55 downto 48) & CODIF_info.sample_periods_per_alignment_period(63 downto 56);
                                                             
little_endian_CODIF.synchronisation_sequence              <= CODIF_info.synchronisation_sequence(7 downto 0) & CODIF_info.synchronisation_sequence(15 downto 8) & 
                                                             CODIF_info.synchronisation_sequence(23 downto 16) & CODIF_info.synchronisation_sequence(31 downto 24);

little_endian_CODIF.metadata_ID                           <= CODIF_info.metadata_ID(7 downto 0) & CODIF_info.metadata_ID(15 downto 8); 

                                                             
little_endian_CODIF.metadata_bits_lower                   <= CODIF_info.metadata_bits_lower(7 downto 0) & CODIF_info.metadata_bits_lower(15 downto 8);

little_endian_CODIF.metadata_bits_mid                     <= CODIF_info.metadata_bits_mid(7 downto 0) & CODIF_info.metadata_bits_mid(15 downto 8) & 
                                                             CODIF_info.metadata_bits_mid(23 downto 16) & CODIF_info.metadata_bits_mid(31 downto 24) &
                                                             CODIF_info.metadata_bits_mid(39 downto 32) & CODIF_info.metadata_bits_mid(47 downto 40) & 
                                                             CODIF_info.metadata_bits_mid(55 downto 48) & CODIF_info.metadata_bits_mid(63 downto 56);
                                                             
little_endian_CODIF.metadata_bits_upper                   <= CODIF_info.metadata_bits_upper(7 downto 0) & CODIF_info.metadata_bits_upper(15 downto 8) & 
                                                             CODIF_info.metadata_bits_upper(23 downto 16) & CODIF_info.metadata_bits_upper(31 downto 24) &
                                                             CODIF_info.metadata_bits_upper(39 downto 32) & CODIF_info.metadata_bits_upper(47 downto 40) & 
                                                             CODIF_info.metadata_bits_upper(55 downto 48) & CODIF_info.metadata_bits_upper(63 downto 56);  

end Behavioral;
