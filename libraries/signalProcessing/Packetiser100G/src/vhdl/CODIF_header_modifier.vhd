----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: March 2022
-- Design Name: 
-- Module Name: CODIF_header_modifier
-- Project Name:    AB NIC 
-- 
-- Revision:
-- 0.01 - File Created for LBUS
-- 0.02 - Refactored for S_AXI, LBUS work commented out.

-- Additional Comments: 
-- this block will sit between the HBM_pktcontroller and the packet_player
-- modify the relevant CODIF field
--
-- initially this will increment the data frame field per packet sent.
-- the counter will be reset with assertion of the reset signal.

-- Layout of data on the 512 bit bus, 

-- LBUS format is
--(127 downto 0)
--    ethernet_info.dst_mac & 
--    ethernet_info.src_mac & 
--    ethernet_info.eth_type & 
--    ipv4_info.version & 
--    ipv4_info.header_length & 
--    ipv4_info.type_of_service; 
--(255 downto 128)
--    ipv4_info.total_length & 
--    ipv4_info.id & 
--    ipv4_info.ip_flags & 
--    ipv4_info.fragment_off & 
--    ipv4_info.TTL & 
--    ipv4_info.protocol & 
--    ipv4_info.header_chk_sum & 
--    ipv4_info.src_addr & 
--    ipv4_info.dst_addr(31 downto 16);
--(383 downto 256)
--    ipv4_info.dst_addr(15 downto 0) & 
--    udp_info.src_port & 
--    udp_info.dst_port & 
--    udp_info.length & 
--    udp_info.checksum & 
--    little_endian_CODIF.data_frame &
--    little_endian_CODIF.epoch_offset(31 downto 16);
--(511 downto 384)    
--    little_endian_CODIF.epoch_offset(15 downto 0) & 
--    little_endian_CODIF.reference_epoch & 
--    little_endian_CODIF.sample_size & 
--    little_endian_smallfields & 
--    little_endian_CODIF.reserved_field &
--    little_endian_CODIF.alignment_period  &
--    little_endian_CODIF.thread_ID &
--    little_endian_CODIF.group_ID &
--    little_endian_CODIF.secondary_ID;
--------------------------------------------------------
--(127 downto 0)
--    little_endian_CODIF.station_ID & 
--    little_endian_CODIF.channels & 
--    little_endian_CODIF.sample_block_length & 
--    little_endian_CODIF.data_array_length & 
--    little_endian_CODIF.sample_periods_per_alignment_period(63 downto 16);
--(255 downto 128)
--    little_endian_CODIF.sample_periods_per_alignment_period(15 downto 0) & 
--    little_endian_CODIF.synchronisation_sequence & 
--    little_endian_CODIF.metadata_ID & 
--    little_endian_CODIF.metadata_bits_lower & 
--    little_endian_CODIF.metadata_bits_mid(63 downto 16);
--(383 downto 256)
--    little_endian_CODIF.metadata_bits_mid(15 downto 0) & 
--    little_endian_CODIF.metadata_bits_upper & 
--    zero_word & zero_dword;
--(511 downto 384) <=    zero_qword & zero_qword;



-- S_AXI is
--(127 downto 0)
--    ethernet_info.dst_mac     (47 -> 0)   MSB first by byte. and so on. 
--    ethernet_info.src_mac     (95 -> 48) 
--    ethernet_info.eth_type    (111 -> 96) 
--    ipv4_info.version         (115 -> 112)
--    ipv4_info.header_length   (119 -> 116)
--    ipv4_info.type_of_service (127 -> 120)
--(255 downto 128)
--    ipv4_info.total_length    (143 -> 128)
--    ipv4_info.id              (159 -> 144)
--    ipv4_info.ip_flags        (162 -> 160) 
--    ipv4_info.fragment_off    (175 -> 163)
--    ipv4_info.TTL             (183 -> 176) 
--    ipv4_info.protocol        (191 -> 184)
--    ipv4_info.header_chk_sum  (207 -> 192) 
--    ipv4_info.src_addr        (239 -> 208) 
--    ipv4_info.dst_addr        (255 -> 240)    (31 downto 16)
--(383 downto 256)
--    ipv4_info.dst_addr                (271 -> 256)    (15 downto 0) 
--    udp_info.src_port                 (287 -> 272) 
--    udp_info.dst_port                 (303 -> 288) 
--    udp_info.length                   (319 -> 304) 
--    udp_info.checksum                 (335 -> 320) 
--    little_endian_CODIF.data_frame    (367 -> 336)
--    little_endian_CODIF.epoch_offset  (383 -> 368)    (31 downto 16);
--(511 downto 384)    
--    little_endian_CODIF.epoch_offset      (399 -> 384)    (15 downto 0)  
--    little_endian_CODIF.reference_epoch   (407 -> 400) 
--    little_endian_CODIF.sample_size       (415 -> 408) 
--    little_endian_smallfields             (431 -> 416) 
--    little_endian_CODIF.reserved_field    (447 -> 432)
--    little_endian_CODIF.alignment_period  (463 -> 448)
--    little_endian_CODIF.thread_ID         (480 -> 464)
--    little_endian_CODIF.group_ID          (495 -> 481)
--    little_endian_CODIF.secondary_ID      (511 -> 496)

----------------------------------------------------------------------------------


library IEEE, xpm, common_lib, PSR_Packetiser_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use xpm.vcomponents.all;
USE common_lib.common_pkg.ALL;
--use PSR_Packetiser_lib.codifheader_pkg.all;

library UNISIM;
use UNISIM.VComponents.all;


entity CODIF_header_modifier is
    Generic (
        g_Packets_per_frame_inc : INTEGER                           := 1;          -- number of jimbles * channels param.
        g_EPOCH_OFFSET_INC      : STD_LOGIC_VECTOR(31 downto 0)     := x"0000001B";  -- set to 27 for CODIF.
        g_CODIF_frame_init      : INTEGER                           := 0;
        g_DEBUG_ILA             : BOOLEAN := FALSE
    );
    Port ( 
        i_clk                   : IN STD_LOGIC;     -- clock domain going to the packet player.
        i_reset                 : IN STD_LOGIC;     -- single pulse, will reset values being modified.
    
        -- FROM THE HBM_packet_controller 
        i_bytes_to_transmit     : IN STD_LOGIC_VECTOR(13 downto 0);     -- 
        i_data_to_player        : IN STD_LOGIC_VECTOR(511 downto 0);
        i_data_to_player_wr     : IN STD_LOGIC;
        
        -- TO THE Packet_player for CMAC
        o_bytes_to_transmit     : OUT STD_LOGIC_VECTOR(13 downto 0);     -- 
        o_data_to_player        : OUT STD_LOGIC_VECTOR(511 downto 0);
        o_data_to_player_wr     : OUT STD_LOGIC        
    
    );
end CODIF_header_modifier;

architecture rtl of CODIF_header_modifier is

type setup_statemachine is (IDLE, DATA, RUN);
signal setup_sm : setup_statemachine;

type counter_statemachine is (PREP, IDLE, COUNT_1, COUNT_2);
signal counter_sm : counter_statemachine;

constant C_DELAY_STEPS  : integer := 6; 

signal data_delay_line  : t_slv_512_arr((C_DELAY_STEPS-1) downto 0);
signal wr_delay_line    : std_logic_vector((C_DELAY_STEPS-1) downto 0);

signal CODIF_Data_frame_count           : integer := 0;
signal CODIF_Data_frame_counter         : std_logic_vector(31 downto 0);
signal CODIF_Data_frame_counter_LE      : std_logic_vector(31 downto 0);

signal Epoch_offset_pickup              : std_logic_vector(31 downto 0);
signal Epoch_offset_reorder             : std_logic_vector(31 downto 0);
signal CODIF_epoch_offset_LE            : std_logic_vector(31 downto 0);

signal Thread_count     : integer := 1;

signal output_vector    : std_logic_vector(511 downto 0);

signal first_run        : std_logic := '0';

begin
----------------------------------------------------------------
-- top lvl port mappings
o_bytes_to_transmit     <= i_bytes_to_transmit;

data_delay_line(0)      <= i_data_to_player;
wr_delay_line(0)        <= i_data_to_player_wr;

o_data_to_player        <= output_vector; 
o_data_to_player_wr     <= wr_delay_line(C_DELAY_STEPS-1);

----------------------------------------------------------------
-- delay line.
delay_gen : FOR i in 0 to (C_DELAY_STEPS - 2) GENERATE
    delay_proc : process(i_clk)
    begin
        if rising_edge(i_clk) then
            data_delay_line(i + 1)  <= data_delay_line(i); 
            wr_delay_line(i + 1)    <= wr_delay_line(i);
        end if;
    end process;
    
END GENERATE;

insertion_process : process(i_clk)
begin
    if rising_edge(i_clk) then

        -- look for leading edge and insert data_frame_counter
        if wr_delay_line(C_DELAY_STEPS-1) = '0' AND wr_delay_line(C_DELAY_STEPS-2) = '1' then
            -- data frame counter position from comments at top of file.
            -- LBUS
            --output_vector   <= CODIF_epoch_offset_LE(15 downto 0) & data_delay_line(C_DELAY_STEPS-2)(495 downto 304) & CODIF_Data_frame_counter_LE & CODIF_epoch_offset_LE(31 downto 16) & data_delay_line(C_DELAY_STEPS-2)(255 downto 0);
            
            -- S_AXI
            --    little_endian_CODIF.data_frame    (367 -> 336)
            --    little_endian_CODIF.epoch_offset  (383 -> 368)    (31 downto 16);
            --    little_endian_CODIF.epoch_offset      (399 -> 384)    (15 downto 0)
            output_vector   <= data_delay_line(C_DELAY_STEPS-2)(511 downto 400) & CODIF_epoch_offset_LE & CODIF_Data_frame_counter_LE & data_delay_line(C_DELAY_STEPS-2)(335 downto 0);  
        else
            output_vector   <= data_delay_line(C_DELAY_STEPS-2);
        end if;
        

    end if;
end process;

CODIF_Data_frame_counter        <= std_logic_vector(to_unsigned(CODIF_Data_frame_count,32));

counter_process : process(i_clk)
begin
    if rising_edge(i_clk) then
        if i_reset = '1' then
            Epoch_offset_pickup         <= x"00000000";
            CODIF_Data_frame_counter_LE <= x"00000000";
            CODIF_Data_frame_count      <= g_CODIF_frame_init;
            first_run                   <= '1';
            setup_sm                    <= IDLE;
            Thread_count                <= 1;
            counter_sm                  <= PREP;
        else

            case counter_sm is
                when PREP =>
                    if setup_sm = RUN then
                        -- reverse LE for ease of math.
                        Epoch_offset_reorder    <= Epoch_offset_pickup;
                        counter_sm              <= IDLE;
                    end if;
                    
                when IDLE =>
                    -- at end of packet, update counters for next.
                    if wr_delay_line(1) = '1' AND wr_delay_line(0) = '0' then
                        counter_sm <= COUNT_1;
                    end if;
                    
                when COUNT_1 =>
                    counter_sm <= COUNT_2;
                    -- Do we increment Data_frame_counter
                    if Thread_count = g_Packets_per_frame_inc then --192 then
                        CODIF_Data_frame_count      <= CODIF_Data_frame_count + 1;
                        Thread_count                <= 1;
                    else
                        Thread_count                <= Thread_count + 1;
                    end if;
                
                when COUNT_2 =>
                    if CODIF_Data_frame_count = 800000 then
                        CODIF_Data_frame_count <= 0;
                        Epoch_offset_reorder    <= std_logic_vector(unsigned(Epoch_offset_reorder) + unsigned(g_EPOCH_OFFSET_INC));
                    end if;
                    counter_sm <= IDLE;
                                
                when OTHERS => 
                    counter_sm <= IDLE;
                    
            end case;
            
            -- LBUS
--            CODIF_epoch_offset_LE           <= Epoch_offset_reorder(7 downto 0) & Epoch_offset_reorder(15 downto 8) & Epoch_offset_reorder(23 downto 16) & Epoch_offset_reorder(31 downto 24);
            
            -- LE re-ordering of frame_counter.
--            CODIF_Data_frame_counter_LE     <= CODIF_Data_frame_counter(7 downto 0) & CODIF_Data_frame_counter(15 downto 8) & CODIF_Data_frame_counter(23 downto 16) & CODIF_Data_frame_counter(31 downto 24); 

            -- S_AXI, has a nature LE swap
            CODIF_epoch_offset_LE           <= Epoch_offset_reorder;
            CODIF_Data_frame_counter_LE     <= CODIF_Data_frame_counter;

            -- catch the data we need to increment as a base first pass through.
            -- the data won't be used for some time, just need to catch the first pass.
            -- data coming from HBM is expected to be 192 packets with unique thread ID.
            -- after 192, increment the data_frame_count by 1.
            -- if data_frame_count is 799,999 then wrap back to 0 and increment the epoch_offset by 27 seconds.
            -- we are capturing the epoch_offset during the first pass.
            case setup_sm is
                when IDLE =>
                    if first_run = '1' and wr_delay_line(0) = '1' then
                        first_run   <= '0';
                        setup_sm    <= DATA;
                    end if;
                    
                when DATA =>
                    if wr_delay_line(1) = '1' then
                                                -- epoch_offset position from comments at top of file.
                        -- LBUS                                                
                        --Epoch_offset_pickup     <= data_delay_line(1)(271 downto 256) & data_delay_line(1)(511 downto 496);
                        -- S_AXI
                        --    little_endian_CODIF.epoch_offset  (383 -> 368)    (31 downto 16);
                        --    little_endian_CODIF.epoch_offset      (399 -> 384)    (15 downto 0) 
                        -- It is LE encoded so 1 to 1 no byte swap required. 
                        --Epoch_offset_pickup     <= data_delay_line(1)(375 downto 368) & data_delay_line(1)(383 downto 376) & data_delay_line(1)(391 downto 384) & data_delay_line(1)(399 downto 392);
                        Epoch_offset_pickup     <= data_delay_line(1)(399 downto 368);
                        setup_sm    <= RUN;
                    end if;
                    
                when RUN =>
                    setup_sm        <= RUN;
                
                when OTHERS => 
                    setup_sm        <= IDLE;
                    
            end case;            
        end if;
    end if;
end process;





end rtl;