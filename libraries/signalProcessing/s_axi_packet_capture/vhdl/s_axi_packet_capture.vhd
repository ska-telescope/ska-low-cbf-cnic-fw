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
--      Capture to a dual page ram, flip page at the end of a packet, if the packet just received is within 64 bytes of target.
--
--      CDC from 322 to 300
--
--      Write to HBM as a single block.
--      WR signal will be continuously high and fall at end of packet.
--      Byte enables will indicate length.
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE, PSR_Packetiser_lib, common_lib, signal_processing_common;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use PSR_Packetiser_lib.ethernet_pkg.ALL;

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
        o_target_count          : out std_logic_vector(63 downto 0);
        o_nontarget_count       : out std_logic_vector(63 downto 0);

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

signal rx_axis_tdata_int        : std_logic_vector ( 511 downto 0 );
signal rx_axis_tkeep_int        : std_logic_vector ( 63 downto 0 );
signal rx_axis_tlast_int        : std_logic;
signal rx_axis_tuser_int        : std_logic_vector ( 79 downto 0 );
signal rx_axis_tvalid_int       : std_logic;

signal rx_axis_tdata_int_d1     : std_logic_vector ( 511 downto 0 );
signal rx_axis_tkeep_int_d1     : std_logic_vector ( 63 downto 0 );
signal rx_axis_tlast_int_d1     : std_logic;
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

begin

------------------------------------------------------------------------------
-- assume always ready if CMAC is locked.
o_rx_axis_tready <= rx_axis_tready_int;

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
        rx_axis_tlast_int_d1    <= rx_axis_tlast_int;
        rx_axis_tuser_int_d1    <= rx_axis_tuser_int;
        rx_axis_tvalid_int_d1   <= rx_axis_tvalid_int;
        
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
            
            if rx_axis_tlast_int_d1 = '1' AND calib_done = '1' then
                if final_byte = rx_axis_tkeep_int_d1 AND current_inc_close_to_target = '1' then
                    wr_page <= not wr_page;
                end if;
            end if;
        end if;
    end if;
end process;


------------------------------------------------------------------------------

write_rx_data_proc : process(i_clk_100GE)
begin
    if rising_edge(i_clk_100GE) then
        -- for back to back packets
        if rx_axis_tlast_int_d1 = '1' then
            wr_addr <= (others => '0');
        elsif rx_axis_tvalid_int_d1 = '1' then
            wr_addr <= std_logic_vector(unsigned(wr_addr) + 1);
--        else
--            wr_addr <= (others => '0');
        end if;
    end if;
end process;


rx_buffer_ram_din       <= rx_axis_tdata_int_d1;
rx_buffer_ram_din_wr    <= rx_axis_tvalid_int_d1;
rx_buffer_ram_addr_in   <= wr_page & wr_addr;

-- assuming dual pages, can expand to 4 with more memory if we go for smaller packets.
-- while one page is available to write, the other is being drained to the HBM WR FIFO.
-- only page flip if the byte count is within 64 of the desired.
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


--cmac_rx_reset_capture
------------------------------------------------------------------------------

config_proc : process(i_clk_300)
begin
    if rising_edge(i_clk_300) then
        if i_clk_300_rst = '1' then
            rd_addr                 <= x"00";
            hbm_streaming_sm        <= IDLE;
            data_to_hbm_wr_int      <= '0';
            rd_page_active          <= '0';
            rd_page_cache           <= rd_page(0);
            hold                    <= '0';
        else
            
            rd_page_cache           <= rd_page(0);
            words_to_send_to_hbm    <= i_rx_packet_size(13 downto 6);
            
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
                    rd_addr <= std_logic_vector(unsigned(rd_addr) + 1);
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

o_data_to_hbm           <= rx_buffer_ram_dout;
o_data_to_hbm_wr        <= data_to_hbm_wr_int;


------------------------------------------------------------------------------

        
debug_packet_capture_in : IF g_DEBUG_ILA GENERATE
    cmac_in_ila : ila_0
    port map (
        clk                     => i_clk_100GE, 
        probe0(127 downto 0)    => rx_buffer_ram_din(127 downto 0),
        probe0(136 downto 128)  => rx_buffer_ram_addr_in,
        probe0(137)             => rx_buffer_ram_din_wr, 
        
        probe0(138)             => rx_axis_tlast_int_d1,
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
