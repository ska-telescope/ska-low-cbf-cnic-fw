----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: 07/13/2022 
-- Module Name: s_axi_packet_capture - Behavioral
--
--
-- Description: 
--      The intent of this block is to capture Streaming packets from the CMAC on 322 MHz clock domain. 
--      Check if the received packet is the desired length.
--      Capture to a dual page ram, flip page at the end of a packet, if the packet just received matches the expected byte length.
--
--      CDC from 322 to 300
--
--      Write to HBM as a single block.
--      WR signal will be continuously high and fall at end of packet.
--      It is expected the HBM manager logic will write in block of 64 bytes. 
--      i_rx_packet_size provides the specific length of the expected packet and this comes from the configuration software.
--      The HBM manager will implement a ceil modulo64 of the i_rx_packet_size.
-- 
-- 
-- Behaviour of S_AXI from CMAC.
--      Due to the gearboxing in the CMAC, a packet sent at line speed will present on the S_AXI interface with tvalid toggling.
--      tlast indicates the packet has finished and you can reset logic around this if needed.
--      CMAC interface clocks in at ~322 MHz and with a width of 64 bytes has a data rate of ~164.8 Gbps, which explains the toggling.
-- 
--      Data on the bus is in the following form for an Ethernet Frame ...
--      dst_mac  <= CMAC_rx_axis_tdata(7 downto 0) & CMAC_rx_axis_tdata(15 downto 8) & CMAC_rx_axis_tdata(23 downto 16) & CMAC_rx_axis_tdata(31 downto 24) & CMAC_rx_axis_tdata(39 downto 32) & CMAC_rx_axis_tdata(47 downto 40);
--      src_mac  <= CMAC_rx_axis_tdata(55 downto 48) & CMAC_rx_axis_tdata(63 downto 56) & CMAC_rx_axis_tdata(71 downto 64) & CMAC_rx_axis_tdata(79 downto 72) & CMAC_rx_axis_tdata(87 downto 80) & CMAC_rx_axis_tdata(95 downto 88);
--      eth_type <= CMAC_rx_axis_tdata(103 downto 96) & CMAC_rx_axis_tdata(111 downto 104);
--
--      
--
----------------------------------------------------------------------------------


library IEEE, PSR_Packetiser_lib, common_lib, signal_processing_common;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use PSR_Packetiser_lib.ethernet_pkg.ALL;
USE common_lib.common_pkg.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity s_axi_packet_capture is
    Generic (
        g_DEBUG_ILA             : IN BOOLEAN := TRUE
    );
    Port ( 
        --------------------------------------------------------
        -- 100G 
        i_clk_100GE             : in std_logic;
        i_eth100G_locked        : in std_logic; -- pseudo reset
        
        i_clk_300               : in std_logic;
        i_clk_300_rst           : in std_logic;
        
        
        i_rx_packet_size        : in std_logic_vector(13 downto 0);     -- Max size is 9000.
        i_rx_reset_capture      : in std_logic;
        i_reset_counter         : in std_logic;
        o_target_count          : out std_logic_vector(31 downto 0);
        o_nontarget_count       : out std_logic_vector(31 downto 0);
        o_LFAA_spead_count      : out std_logic_vector(31 downto 0);
        o_PSR_PST_count         : out std_logic_vector(31 downto 0);
        o_CODIF_2154_count      : out std_logic_vector(31 downto 0);

        -- 100G RX S_AXI interface ~322 MHz
        i_rx_axis_tdata         : in std_logic_vector ( 511 downto 0 );
        i_rx_axis_tkeep         : in std_logic_vector ( 63 downto 0 );
        i_rx_axis_tlast         : in std_logic;
        o_rx_axis_tready        : out std_logic;
        i_rx_axis_tuser         : in std_logic_vector ( 79 downto 0 );
        i_rx_axis_tvalid        : in std_logic;
        
        -- Data to HBM writer - 300 MHz
        o_data_to_hbm           : out std_logic_vector(511 downto 0);
        o_data_to_hbm_wr        : out std_logic
    
    );
end s_axi_packet_capture;

architecture RTL of s_axi_packet_capture is

COMPONENT ila_0
    PORT (
        clk     : IN STD_LOGIC;
        probe0  : IN STD_LOGIC_VECTOR(191 DOWNTO 0)
    );       
END COMPONENT;

constant CODIF_2154_length      : std_logic_vector (13 downto 0) := 14D"2154";
constant PST_PSR_length         : std_logic_vector (13 downto 0) := 14D"6330";
constant SPEAD_LFAA_length      : std_logic_vector (13 downto 0) := 14D"8292";

signal rx_axis_tdata_int        : std_logic_vector ( 511 downto 0 );
signal rx_axis_tkeep_int        : std_logic_vector ( 63 downto 0 );
signal rx_axis_tlast_int        : std_logic;
signal rx_axis_tuser_int        : std_logic_vector ( 79 downto 0 );
signal rx_axis_tvalid_int       : std_logic;

signal rx_axis_tdata_int_d1     : std_logic_vector ( 511 downto 0 );
signal rx_axis_tkeep_int_d1     : std_logic_vector ( 63 downto 0 );
signal rx_axis_tlast_int_d1     : std_logic_vector ( 1 downto 0 );
signal rx_axis_tuser_int_d1     : std_logic_vector ( 79 downto 0 );
signal rx_axis_tvalid_int_d1    : std_logic;

signal rx_axis_tready_int       : std_logic;

signal inc_packet_byte_count    : std_logic_vector (13 downto 0) := "00" & x"040"; 
signal packet_byte_count        : std_logic_vector (13 downto 0);

signal final_byte_vector        : std_logic_vector (63 downto 0);   
signal final_byte               : std_logic_vector (63 downto 0);   
signal expected_tx_last_byte    : std_logic_vector (5 downto 0);

signal rx_buffer_ram_din        : std_logic_vector(511 downto 0);
signal rx_buffer_ram_addr_in    : std_logic_vector(8 downto 0);
signal rx_buffer_ram_din_wr     : std_logic;
signal rx_buffer_ram_dout       : std_logic_vector(511 downto 0);
signal rx_buffer_ram_addr_out   : std_logic_vector(8 downto 0);

signal words_to_send_to_hbm     : std_logic_vector(7 downto 0);

signal wr_page, rd_page         : std_logic_vector(0 downto 0) := "0";
signal wr_page_d                : std_logic_vector(0 downto 0) := "0";

signal rd_page_cache            : std_logic;
signal rd_page_active           : std_logic;

signal wr_addr                  : std_logic_vector(7 downto 0);
signal rd_addr                  : std_logic_vector(7 downto 0);

signal data_to_hbm_wr_int       : std_logic;

signal rx_packet_size           : std_logic_vector(13 downto 0);

signal current_inc_close_to_target  : std_logic;  
signal hold                         : std_logic;
signal calib_done                   : std_logic;
signal no_remainder,whole_interval  : std_logic;

signal cmac_rx_reset_capture        : std_logic;
signal cmac_rx_packet_size          : std_logic_vector(13 downto 0);

type hbm_streaming_statemachine is (IDLE, PREP, DATA, FINISH);
signal hbm_streaming_sm : hbm_streaming_statemachine;

type packet_check_statemachine is (IDLE, PREP, DATA, FINISH);
signal packet_check_sm : packet_check_statemachine;

signal cmac_reset                   : std_logic;
signal cmac_reset_combined          : std_logic;

signal ila_data_in_r                : std_logic_vector(127 downto 0);
signal ila_data_out_r               : std_logic_vector(127 downto 0);

signal ptp_seconds                  : std_logic_vector(47 downto 0);
signal ptp_sub_sec                  : std_logic_vector(31 downto 0);

signal capture_timestamp            : std_logic;
signal timestamp                    : std_logic_vector(511 downto 0);

------------------------------------------------------------------------------
-- packet stats

type detected_stats_statemachine is (IDLE, START, CALC, FINISH);
signal detected_check_sm : detected_stats_statemachine;

signal b0, b1, b2, b3                                   : integer range 0 to 9000 := 0 ;
signal b0_cached, b1_cached, b2_cached, b3_cached       : integer range 0 to 9000 := 0 ;        

signal stat_byte_count                                  : integer range 0 to 9000 := 0 ;
signal stat_byte_count_cache                            : integer range 0 to 9000 := 0 ;
signal stat_byte_count_working                          : integer range 0 to 9000 := 0 ;

signal b_quad                                           : std_logic_vector(3 downto 0);
signal stat_packet_length_final                         : std_logic_vector(13 downto 0);

signal stat_done                                        : std_logic;
signal expected_length_detect                           : std_logic;
signal unexpected_length_detect                         : std_logic;
signal CODIF_2154_length_detect                         : std_logic;
signal PST_PSR_length_detect                            : std_logic;
signal SPEAD_LFAA_length_detect                         : std_logic;

constant STAT_REGISTERS                                 : integer := 5;

signal stats_count                                      : t_slv_32_arr(0 to (STAT_REGISTERS-1));
signal stats_increment                                  : t_slv_3_arr(0 to (STAT_REGISTERS-1));
signal stats_to_host_data_out                           : t_slv_32_arr(0 to (STAT_REGISTERS-1));

------------------------------------------------------------------------------


begin

------------------------------------------------------------------------------
-- assume always ready if CMAC is locked.
o_rx_axis_tready        <= rx_axis_tready_int;

o_data_to_hbm           <= rx_buffer_ram_dout;
o_data_to_hbm_wr        <= data_to_hbm_wr_int;

-- register AXI bus
s_axi_proc : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
    
        rx_axis_tready_int      <= i_eth100G_locked;
        
        rx_axis_tdata_int       <= i_rx_axis_tdata;
        rx_axis_tkeep_int       <= i_rx_axis_tkeep;
        rx_axis_tlast_int       <= i_rx_axis_tlast;
        rx_axis_tuser_int       <= i_rx_axis_tuser;
        rx_axis_tvalid_int      <= i_rx_axis_tvalid;
        
        rx_axis_tdata_int_d1    <= rx_axis_tdata_int;
        rx_axis_tkeep_int_d1    <= rx_axis_tkeep_int;
        rx_axis_tlast_int_d1(0) <= rx_axis_tlast_int;
        rx_axis_tuser_int_d1    <= rx_axis_tuser_int;
        rx_axis_tvalid_int_d1   <= rx_axis_tvalid_int;
        
        -- lengthen last signal to insert the timestamp immediately after packet end.
        -- the second bit is only relevant for end of packet due the cyclic nature of 64/66 writing from CMAC.

        rx_axis_tlast_int_d1(1) <= rx_axis_tlast_int_d1(0);

    end if;
end process;

------------------------------------------------------------------------------
calibrate_byte_enables : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        if cmac_rx_reset_capture = '1' then
            final_byte_vector       <= c_ones_64;
            expected_tx_last_byte   <= cmac_rx_packet_size(5 downto 0);
            calib_done              <= '0';
            no_remainder            <= '1';
        else
            if expected_tx_last_byte /= "000000" then
                expected_tx_last_byte   <= std_logic_vector(unsigned(expected_tx_last_byte) + 1);
                final_byte_vector       <= '0' & final_byte_vector(63 downto 1);
                calib_done              <= '0';
                no_remainder            <= '0';
            else
                calib_done              <= '1';
            end if;
            final_byte <= final_byte_vector;
        end if;
    end if;
end process;
    

byte_check_proc : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        if cmac_rx_reset_capture = '1' then
            --wr_page(0)                  <= '0';
            rx_packet_size              <= cmac_rx_packet_size;
            inc_packet_byte_count       <= "00" & x"040"; 
        else
            -- count whole 64 bytes
            if rx_axis_tlast_int = '1' then
                inc_packet_byte_count   <= "00" & x"040"; 
            elsif rx_axis_tvalid_int = '1' then
                inc_packet_byte_count   <= std_logic_vector(unsigned(inc_packet_byte_count) + 64);
            end if;
        
            if rx_packet_size(13 downto 7) = inc_packet_byte_count(13 downto 7) then
                current_inc_close_to_target <= '1';
            else
                current_inc_close_to_target <= '0';
            end if;
            
            if rx_axis_tlast_int_d1(0) = '1' AND calib_done = '1' then
                if final_byte = rx_axis_tkeep_int_d1 AND current_inc_close_to_target = '1' then
                    wr_page <= not wr_page;
                end if;
            end if;
            
            wr_page_d   <= wr_page;
        end if;
    end if;
end process;


------------------------------------------------------------------------------

write_rx_data_proc : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        if cmac_rx_reset_capture = '1' then
            wr_addr             <= (others => '0');
            capture_timestamp   <= '1';
            timestamp           <= zero_512;
        else
            -- timestamp is provided with the first write, otherwise bus provides zero.
            -- re-enable the capture of timestamp after last write from packet indicated.
            if rx_axis_tlast_int_d1(0) then
                capture_timestamp       <= '1';
            elsif rx_axis_tvalid_int_d1 = '1' and capture_timestamp = '1' then
                -- byte swap as per how it will be read from HBM.
                --timestamp(79 downto 0)  <= rx_axis_tuser_int_d1;
                timestamp(79 downto 40) <= rx_axis_tuser_int_d1(7 downto 0) & rx_axis_tuser_int_d1(15 downto 8) & rx_axis_tuser_int_d1(23 downto 16) & rx_axis_tuser_int_d1(31 downto 24) & rx_axis_tuser_int_d1(39 downto 32);
                timestamp(39 downto 0)  <= rx_axis_tuser_int_d1(47 downto 40) & rx_axis_tuser_int_d1(55 downto 48) & rx_axis_tuser_int_d1(63 downto 56) & rx_axis_tuser_int_d1(71 downto 64) & rx_axis_tuser_int_d1(79 downto 72);
                capture_timestamp       <= '0';
            end if;
            
            -- for back to back packets
            if rx_axis_tlast_int_d1(1) = '1' then
                wr_addr <= (others => '0');
            elsif rx_axis_tvalid_int_d1 = '1' then
                wr_addr <= std_logic_vector(unsigned(wr_addr) + 1);
            end if;
        end if;
    end if;
end process;


rx_buffer_ram_din       <= rx_axis_tdata_int_d1 when rx_axis_tlast_int_d1(1) = '0' else
                            timestamp;
                            
rx_buffer_ram_din_wr    <= rx_axis_tvalid_int_d1 OR rx_axis_tlast_int_d1(1);
rx_buffer_ram_addr_in   <= wr_page_d & wr_addr;

-- assuming dual pages, can expand to 4 with more memory if we go for smaller packets.
-- while one page is available to write, the other is being drained to the HBM WR FIFO.
-- only page flip if the byte count is equal to target.
rx_buffer_ram : entity signal_processing_common.memory_dp_wrapper 
    GENERIC MAP (
        g_NO_OF_ADDR_BITS   => 9,
        g_D_Q_WIDTH         => 512
    )
    PORT MAP ( 
        clk_a               => i_clk_100GE,
        clk_b               => i_clk_300,
    
        data_in             => rx_buffer_ram_din,
        addr_in             => rx_buffer_ram_addr_in,
        data_in_wr          => rx_buffer_ram_din_wr,
        
        data_out            => rx_buffer_ram_dout,
        addr_out            => rx_buffer_ram_addr_out
    
    );

rx_buffer_ram_addr_out      <= rd_page_active & rd_addr;
------------------------------------------------------------------------------

packet_ready_cdc : entity signal_processing_common.sync 
    generic map (
        DEST_SYNC_FF    => 2,
        WIDTH           => 2
    )
    port map ( 
        Clock_a     => i_clk_100GE,
        Clock_b     => i_clk_300,
        data_in(0)  => wr_page(0),
        data_in(1)  => no_remainder,
        
        data_out(0) => rd_page(0),
        data_out(1) => whole_interval
    );

packet_config_cdc : entity signal_processing_common.sync_vector
    generic map (
        WIDTH => 15
    )
    Port Map ( 
        clock_a_rst             => i_clk_300_rst,
        Clock_a                 => i_clk_300,
        data_in(0)              => i_rx_reset_capture,
        data_in(14 downto 1)    => i_rx_packet_size,
        
        
        Clock_b                 => i_clk_100GE,
        data_out(0)             => cmac_rx_reset_capture,
        data_out(14 downto 1)   => cmac_rx_packet_size
    );  

cmac_reset          <= NOT i_eth100G_locked;

cmac_reset_combined <= cmac_rx_reset_capture OR cmac_reset;


------------------------------------------------------------------------------
-- stream out data to HBM SM

config_proc : process(i_clk_300)
begin
    if rising_edge(i_clk_300) then
        -- ARGS axi Reset
        if i_clk_300_rst = '1' then
            rd_addr                 <= x"00";
            hbm_streaming_sm        <= IDLE;
            data_to_hbm_wr_int      <= '0';
            rd_page_active          <= '0';
            rd_page_cache           <= rd_page(0);
            hold                    <= '0';
        else
            
            -- add 64 bytes to the byte count to include the time stamp.
            if i_rx_reset_capture = '1' then
                words_to_send_to_hbm    <= std_logic_vector(unsigned(i_rx_packet_size(13 downto 6)) + x"01");
            end if;
            
            rd_page_cache           <= rd_page(0);
            --words_to_send_to_hbm    <= i_rx_packet_size(13 downto 6);
            
            case hbm_streaming_sm is
                when IDLE => 
                    hold                <= '0';
                    rd_addr             <= x"00";
                    data_to_hbm_wr_int  <= '0';
                    if rd_page_cache /= rd_page(0) then
                        hbm_streaming_sm    <= PREP;
                        rd_page_active      <= rd_page_cache;
                    end if;            
                
                when PREP =>
                    rd_addr                 <= std_logic_vector(unsigned(rd_addr) + 1);
                    if rd_addr = x"02" then
                        hbm_streaming_sm    <= DATA;
                        data_to_hbm_wr_int  <= '1';
                    end if;
                
                when DATA =>
                    rd_addr                 <= std_logic_vector(unsigned(rd_addr) + 1);
                    
                    if rd_addr = words_to_send_to_hbm then
                        hbm_streaming_sm    <= FINISH;
                        hold                <= whole_interval;
                    end if;
                
                when FINISH =>
                    hold <= '1';
                    if hold = '1' then
                        hbm_streaming_sm        <= IDLE;
                    end if;
                
                when OTHERS =>
                    hbm_streaming_sm        <= IDLE;
                 
            end case;
        end if;
    end if;
end process;

------------------------------------------------------------------------------

b0 <= byte_en_to_integer_count(rx_axis_tkeep_int_d1(15 downto 0));
b1 <= byte_en_to_integer_count(rx_axis_tkeep_int_d1(31 downto 16));
b2 <= byte_en_to_integer_count(rx_axis_tkeep_int_d1(47 downto 32));
b3 <= byte_en_to_integer_count(rx_axis_tkeep_int_d1(63 downto 48));
        
inc_packet_calc : process (i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        if cmac_reset_combined = '1' then
            stat_byte_count     <= 0;
            detected_check_sm   <= IDLE;
            stat_done           <= '0';
        else
        
            if rx_axis_tlast_int_d1(0) = '1' then
                stat_byte_count     <= 0;
            elsif rx_axis_tvalid_int_d1 = '1' then
                stat_byte_count     <= stat_byte_count + 64;
            
            end if;
    
            case detected_check_sm is
                when IDLE =>
                    if rx_axis_tlast_int_d1(0) = '1' then
                        b0_cached               <= b0;
                        b1_cached               <= b1;
                        b2_cached               <= b2;
                        b3_cached               <= b3;
                        b_quad                  <= rx_axis_tkeep_int_d1(63) & rx_axis_tkeep_int_d1(47) & rx_axis_tkeep_int_d1(31) & rx_axis_tkeep_int_d1(15);
                        
                        stat_byte_count_cache   <= stat_byte_count;
                        
                        detected_check_sm       <= START;
                        
                        stat_byte_count_working <= 0;
                    end if;
                    stat_done                   <= '0';
                
                when START =>
                    if b_quad = "1111" then
                        stat_byte_count_working <= 64;
                    elsif b_quad = "0111" then
                        stat_byte_count_working <= b3_cached + 48;
                    elsif b_quad = "0011" then
                        stat_byte_count_working <= b2_cached + 32;
                    elsif b_quad = "0001" then
                        stat_byte_count_working <= b1_cached + 16;
                    elsif b_quad = "0000" then
                        stat_byte_count_working <= b0_cached;
                    end if;
                    
                    detected_check_sm       <= CALC;
                    
                when CALC =>
                    stat_byte_count_working <= stat_byte_count_cache + stat_byte_count_working;
                
                    detected_check_sm       <= FINISH;
                
                when FINISH =>
                    stat_packet_length_final    <= std_logic_vector(to_unsigned(stat_byte_count_working,14));
                    stat_done                   <= '1';
                    detected_check_sm           <= IDLE;
                
                when OTHERS =>
                    detected_check_sm   <= IDLE;
            end case;    
            
            if stat_done = '1' then
                if stat_packet_length_final = cmac_rx_packet_size then
                    expected_length_detect      <= '1';
                else
                    unexpected_length_detect    <= '1';
                end if;
            
                if stat_packet_length_final = CODIF_2154_length then
                    CODIF_2154_length_detect    <= '1';
                end if;
                
                if stat_packet_length_final = PST_PSR_length then
                    PST_PSR_length_detect       <= '1';
                end if;
                
                if stat_packet_length_final = SPEAD_LFAA_length then
                    SPEAD_LFAA_length_detect    <= '1';
                end if;
            else
                expected_length_detect          <= '0';
                unexpected_length_detect        <= '0';
                CODIF_2154_length_detect        <= '0';
                PST_PSR_length_detect           <= '0';
                SPEAD_LFAA_length_detect        <= '0';
            end if;
        end if;
    end if;
end process;

stats_increment(0) <= "00" & expected_length_detect;
stats_increment(1) <= "00" & unexpected_length_detect;
stats_increment(2) <= "00" & CODIF_2154_length_detect;
stats_increment(3) <= "00" & PST_PSR_length_detect;
stats_increment(4) <= "00" & SPEAD_LFAA_length_detect;


stats_accumulators: FOR i IN 0 TO (STAT_REGISTERS-1) GENERATE
    u_cnt_acc: ENTITY common_lib.common_accumulate
        GENERIC MAP (
            g_representation  => "UNSIGNED")
        PORT MAP (
            rst      => cmac_reset_combined,
            clk      => i_clk_100GE,
            clken    => '1',
            sload    => '0',
            in_val   => '1',
            in_dat   => stats_increment(i),
            out_dat  => stats_count(i)
        );
END GENERATE;

sync_stats_to_Host: FOR i IN 0 TO (STAT_REGISTERS-1) GENERATE

    STATS_DATA : entity signal_processing_common.sync_vector
        generic map (
            WIDTH => 32
        )
        Port Map ( 
            clock_a_rst => cmac_reset_combined,
            Clock_a     => i_clk_100GE,
            data_in     => stats_count(i),
            
            Clock_b     => i_clk_300,
            data_out    => stats_to_host_data_out(i)
        );  

END GENERATE;

o_target_count          <= stats_to_host_data_out(0);
o_nontarget_count       <= stats_to_host_data_out(1);
o_CODIF_2154_count      <= stats_to_host_data_out(2);
o_PSR_PST_count         <= stats_to_host_data_out(3);
o_LFAA_spead_count      <= stats_to_host_data_out(4);

------------------------------------------------------------------------------

        
debug_packet_capture_in : IF g_DEBUG_ILA GENERATE

debug_ila_cmac_proc : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        
--        ila_data_in_r <= rx_axis_tdata_int_d1(127 downto 0);
        
        ptp_seconds <= rx_axis_tuser_int_d1(79 downto 32);
        ptp_sub_sec <= rx_axis_tuser_int_d1(31 downto 0);

    end if;
end process;


    cmac_in_ila : ila_0
    port map (
        clk                     => i_clk_100GE, 
        probe0(47 downto 0)     => rx_axis_tdata_int_d1(47 downto 0),
--        probe0(127 downto 48)   => rx_axis_tuser_int_d1,
        probe0(79 downto 48)    => ptp_sub_sec,
        probe0(127 downto 80)   => ptp_seconds,
        probe0(136 downto 128)  => rx_buffer_ram_addr_in,
        probe0(137)             => rx_buffer_ram_din_wr, 
        
        probe0(138)             => rx_axis_tlast_int_d1(0),
        probe0(139)             => rx_axis_tvalid_int_d1,
        probe0(153 downto 140)  => inc_packet_byte_count,
        probe0(191 downto 154)  => (others => '0')
    );
    

    hbm_out_ila : ila_0
    port map (
        clk                     => i_clk_300, 
        probe0(127 downto 0)    => rx_buffer_ram_dout(127 downto 0),
        probe0(136 downto 128)  => rx_buffer_ram_addr_out,
        probe0(137)             => data_to_hbm_wr_int, 
        probe0(145 downto 138)  => words_to_send_to_hbm,

        probe0(191 downto 146)  => (others => '0')
    );

end generate;

end RTL;
