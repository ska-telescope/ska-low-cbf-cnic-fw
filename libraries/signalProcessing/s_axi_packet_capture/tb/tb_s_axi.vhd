----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: July 2022
-- Design Name: TB_s_axi
-- 
-- 
-- test bench written to be used in Vivado
-- 
--
library IEEE,technology_lib, PSR_Packetiser_lib, signal_processing_common, cmac_s_axi_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use PSR_Packetiser_lib.ethernet_pkg.ALL;
use PSR_Packetiser_lib.CbfPsrHeader_pkg.ALL;


entity tb_s_axi is
--  Port ( );
end tb_s_axi;

architecture Behavioral of tb_s_axi is

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

signal streaming_data           : std_logic_vector(511 downto 0);

signal ethernet_info            : ethernet_frame    := default_ethernet_frame;
signal ipv4_info                : IPv4_header       := default_ipv4_header;
signal udp_info                 : UDP_header        := default_UDP_header;

signal rx_packet_size           : std_logic_vector(13 downto 0);     -- Max size is 9000.
signal rx_reset_capture         : std_logic;
signal rx_reset_counter         : std_logic;

signal i_rx_axis_tdata          : STD_LOGIC_VECTOR ( 511 downto 0 );
signal i_rx_axis_tkeep          : STD_LOGIC_VECTOR ( 63 downto 0 );
signal i_rx_axis_tlast          : STD_LOGIC;
signal o_rx_axis_tready         : STD_LOGIC;
signal i_rx_axis_tuser          : STD_LOGIC_VECTOR ( 79 downto 0 );
signal i_rx_axis_tvalid         : STD_LOGIC;
    
begin

clock_300 <= not clock_300 after 3.33 ns;
clock_322 <= not clock_322 after 3.11 ns;
clock_400 <= not clock_400 after 2.50 ns;

--i_bytes_to_transmit <= std_logic_vector(to_unsigned(bytes_to_transmit,14));

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

test_runner_proc_clk322: process(clock_322)
begin
    if rising_edge(clock_322) then
        -- power up reset logic
        if power_up_rst_clock_322(31) = '1' then
            power_up_rst_clock_322(31 downto 0) <= power_up_rst_clock_322(30 downto 0) & '0';
            testCount_322   <= 0;
            clock_322_rst   <= '1';
        else
            testCount_322   <= testCount_322 + 1;
            clock_322_rst   <= '0';
        end if;
    end if;
end process;


-------------------------------------------------------------------------------------------------------------
run_proc : process(clock_322)
begin
    if rising_edge(clock_322) then
        if clock_322_rst = '1' then
            i_rx_axis_tvalid    <= '0';
            streaming_data      <= zero_512;
            i_rx_axis_tkeep     <= x"0000000000000000";
            i_rx_axis_tvalid    <= '0';
            i_rx_axis_tlast     <= '0';
            rx_reset_capture    <= '1';
        else
            
            
                
            if testCount_322 = 80 then
                streaming_data(127 downto 0)   <=  ethernet_info.dst_mac & 
                                                ethernet_info.src_mac & 
                                                ethernet_info.eth_type & 
                                                ipv4_info.version & 
                                                ipv4_info.header_length & 
                                                ipv4_info.type_of_service; 
                streaming_data(255 downto 128) <=  ipv4_info.total_length & 
                                                ipv4_info.id & 
                                                ipv4_info.ip_flags & 
                                                ipv4_info.fragment_off & 
                                                ipv4_info.TTL & 
                                                ipv4_info.protocol & 
                                                ipv4_info.header_chk_sum & 
                                                ipv4_info.src_addr & 
                                                ipv4_info.dst_addr(31 downto 16);
                streaming_data(383 downto 256) <=  ipv4_info.dst_addr(15 downto 0) & 
                                                udp_info.src_port & 
                                                udp_info.dst_port & 
                                                udp_info.length & 
                                                udp_info.checksum & 
                                                x"AAAA" & 
                                                x"AAAAAAAA";
                streaming_data(511 downto 384) <=  x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
                
            elsif testCount_322 = 81 then
                streaming_data(127 downto 0)    <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(255 downto 128)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(383 downto 256)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(511 downto 384)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
            
            elsif testCount_322 = 82 then
                streaming_data(127 downto 0)    <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(255 downto 128)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(383 downto 256)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(511 downto 384)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
               
            elsif testCount_322 >= 83 AND testCount_322 < 120 then
                streaming_data(127 downto 0)    <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(255 downto 128)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(383 downto 256)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(511 downto 384)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
                
            elsif testCount_322 = 120 then
                streaming_data(127 downto 0)    <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(255 downto 128)  <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(383 downto 256)  <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(511 downto 384)  <= zero_128;
                i_rx_axis_tkeep                 <= x"00000FFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
                i_rx_axis_tlast                 <= '1'; 
            -- PTP injection
            elsif testCount_322 = 121 then
                streaming_data(127 downto 0)   <=  ethernet_info.dst_mac & 
                                                ethernet_info.src_mac & 
                                                ethernet_info.eth_type & 
                                                ipv4_info.version & 
                                                ipv4_info.header_length & 
                                                ipv4_info.type_of_service; 
                streaming_data(255 downto 128) <=  ipv4_info.total_length & 
                                                ipv4_info.id & 
                                                ipv4_info.ip_flags & 
                                                ipv4_info.fragment_off & 
                                                ipv4_info.TTL & 
                                                ipv4_info.protocol & 
                                                ipv4_info.header_chk_sum & 
                                                ipv4_info.src_addr & 
                                                ipv4_info.dst_addr(31 downto 16);
                streaming_data(383 downto 256) <=  ipv4_info.dst_addr(15 downto 0) & 
                                                udp_info.src_port & 
                                                udp_info.dst_port & 
                                                udp_info.length & 
                                                udp_info.checksum & 
                                                x"AAAA" & 
                                                x"AAAAAAAA";
                streaming_data(511 downto 384) <=  x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';  
                i_rx_axis_tlast                 <= '1';
                
            elsif testCount_322 = 300 then
                streaming_data(127 downto 0)   <=  ethernet_info.dst_mac & 
                                                ethernet_info.src_mac & 
                                                ethernet_info.eth_type & 
                                                ipv4_info.version & 
                                                ipv4_info.header_length & 
                                                ipv4_info.type_of_service; 
                streaming_data(255 downto 128) <=  ipv4_info.total_length & 
                                                ipv4_info.id & 
                                                ipv4_info.ip_flags & 
                                                ipv4_info.fragment_off & 
                                                ipv4_info.TTL & 
                                                ipv4_info.protocol & 
                                                ipv4_info.header_chk_sum & 
                                                ipv4_info.src_addr & 
                                                ipv4_info.dst_addr(31 downto 16);
                streaming_data(383 downto 256) <=  ipv4_info.dst_addr(15 downto 0) & 
                                                udp_info.src_port & 
                                                udp_info.dst_port & 
                                                udp_info.length & 
                                                udp_info.checksum & 
                                                x"AAAA" & 
                                                x"AAAAAAAA";
                streaming_data(511 downto 384) <=  x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA" & 
                                                x"AAAAAAAA";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
                
            elsif testCount_322 = 301 then
                streaming_data(127 downto 0)    <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(255 downto 128)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(383 downto 256)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                streaming_data(511 downto 384)  <= x"11111111" & x"22222222" & x"33333333" & x"44444444";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
            
            elsif testCount_322 = 302 then
                streaming_data(127 downto 0)    <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(255 downto 128)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(383 downto 256)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                streaming_data(511 downto 384)  <= x"55555555" & x"66666666" & x"77777777" & x"88888888";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
               
            elsif testCount_322 = 303 then
                streaming_data(127 downto 0)    <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(255 downto 128)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(383 downto 256)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                streaming_data(511 downto 384)  <= x"99999999" & x"AAAAAAAA" & x"BBBBBBBB" & x"CCCCCCCC";
                i_rx_axis_tkeep                 <= x"FFFFFFFFFFFFFFFF";
                i_rx_axis_tvalid                <= '1';
                i_rx_axis_tlast                 <= '1';
                
            elsif testCount_322 = 304 then
                streaming_data(127 downto 0)    <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(255 downto 128)  <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(383 downto 256)  <= x"DDDDDDDD" & x"EEEEEEEE" & x"FFFFFFFF" & x"00000000";
                streaming_data(511 downto 384)  <= zero_128;
                i_rx_axis_tkeep                 <= x"0000000000000000";
                i_rx_axis_tvalid                <= '0';
                i_rx_axis_tlast                 <= '0';                 
            else
                streaming_data                  <= zero_512;
                i_rx_axis_tkeep                 <= x"0000000000000000";
                i_rx_axis_tvalid                <= '0';
                i_rx_axis_tlast                 <= '0';
            end if;

            if testCount_322 = 38 then
                rx_reset_capture    <= '1';
                rx_packet_size      <= "00" & x"A2C";      -- 2604            
            elsif testCount_322 = 175 then
                rx_reset_capture    <= '1';
                rx_packet_size      <= "00" & x"100";      -- 256
            else
                rx_reset_capture    <= '0';
            end if;
        end if;

    end if;
end process;



i_rx_axis_tdata        <= streaming_data;




rx_reset_counter        <= '0';


DUT : entity cmac_s_axi_lib.s_axi_packet_capture 
    Port map ( 
        --------------------------------------------------------
        -- 100G 
        i_clk_100GE             => clock_322,
        i_eth100G_locked        => '1',
        
        i_clk_300               => clock_300,
        i_clk_300_rst           => clock_300_rst,
        
        
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
        o_data_to_hbm           => open,
        o_data_to_hbm_wr        => open
    
    );




end Behavioral;
