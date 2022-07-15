----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Jonathan Li, jonathan.li@csiro.au
-- 
-- Create Date: 13.07.2022 
-- Module Name: HBM_PktController
-- Description: 
--      Get packets from data block interface and write them to the HBM through AXI  
--      Also read the packets from HBM through AXI, packet size is in bytes and flexible, 
--      can be any value >=64bytes and <=9000bytes, it covers the whole HBM range 
--      which is 16GB
----------------------------------------------------------------------------------
--  
--
--  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
--  See the file LICENSE for more info.
----------------------------------------------------------------------------------

library IEEE, common_lib, xpm;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library cnic_lib;
use cnic_lib.cnic_top_pkg.all;

USE common_lib.common_pkg.ALL;

library xpm;
use xpm.vcomponents.all;

library axi4_lib;
use axi4_lib.axi4_lite_pkg.all;
use axi4_lib.axi4_full_pkg.all;


entity HBM_PktController is
    generic (
        g_DEBUG_ILAs             : BOOLEAN := FALSE
    );
    Port(
        -- shared memory interface clock (300 MHz)
        i_shared_clk             : in std_logic;
        i_shared_rst             : in std_logic;

        ------------------------------------------------------------------------------------
        -- Data from CMAC module after CDC in shared memory clock domain
        i_data_from_cmac         : in  std_logic_vector(511 downto 0);
        i_data_valid_from_cmac   : in  std_logic;

        ------------------------------------------------------------------------------------
        -- config and status registers interface
        -- rx
    	i_rx_packet_size         : in  std_logic_vector(13 downto 0);
        i_soft_reset             : in  std_logic;
        i_enable_capture         : in  std_logic;

        1st_4GB_rx_addr          : out std_logic_vector(31 downto 0);
        2nd_4GB_rx_addr          : out std_logic_vector(31 downto 0);
        3rd_4GB_rx_addr          : out std_logic_vector(31 downto 0);
        4th_4GB_rx_addr          : out std_logic_vector(31 downto 0);

        capture_done             : out std_logic;
        num_packets_received     : out std_logic_vector(31 downto 0);

        -- tx
        i_tx_packet_size         : in  std_logic_vector(13 downto 0);
        i_start_tx               : in  std_logic;

        num_packets_transmitted  : out std_logic_vector(31 downto 0);
        
        1st_4GB_tx_addr          : out std_logic_vector(31 downto 0);
        2nd_4GB_tx_addr          : out std_logic_vector(31 downto 0);
        3rd_4GB_tx_addr          : out std_logic_vector(31 downto 0);
        4th_4GB_tx_addr          : out std_logic_vector(31 downto 0);
        ------------------------------------------------------------------------------------
        -- Data output, to the packetizer
        -- Add the packetizer records here
        o_packetiser_data_in_wr         : out std_logic;
        o_packetiser_data               : out std_logic_vector(511 downto 0);
        o_packetiser_bytes_to_transmit  : out std_logic_vector(13 downto 0);
        i_packetiser_data_to_player_rdy : in  std_logic;

        -----------------------------------------------------------------------
        --first 4GB section of AXI
        --aw bus
        m01_axi_awvalid   : out std_logic;
        m01_axi_awready   : in  std_logic;
        m01_axi_awaddr    : out std_logic_vector(31 downto 0);
        m01_axi_awlen     : out std_logic_vector(7 downto 0);
        --w bus
        m01_axi_wvalid    : out std_logic;
        m01_axi_wdata     : out std_logic_vector(511 downto 0);
        m01_axi_wstrb     : out std_logic_vector(63  downto 0);
        m01_axi_wlast     : out std_logic;
        m01_axi_wready    : in  std_logic;

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

        --second 4GB section of AXI
        --aw bus
        m02_axi_awvalid   : out std_logic;
        m02_axi_awready   : in  std_logic;
        m02_axi_awaddr    : out std_logic_vector(31 downto 0);
        m02_axi_awlen     : out std_logic_vector(7 downto 0);
        --w bus
        m02_axi_wvalid    : out std_logic;
        m02_axi_wdata     : out std_logic_vector(511 downto 0);
        m02_axi_wstrb     : out std_logic_vector(63  downto 0);
        m02_axi_wlast     : out std_logic;
        m02_axi_wready    : in  std_logic;

        -- ar bus - read address
        m02_axi_arvalid   : out std_logic;
        m02_axi_arready   : in  std_logic;
        m02_axi_araddr    : out std_logic_vector(31 downto 0);
        m02_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m02_axi_rvalid    : in  std_logic;
        m02_axi_rready    : out std_logic;
        m02_axi_rdata     : in  std_logic_vector(511 downto 0);
        m02_axi_rlast     : in  std_logic;
        m02_axi_rresp     : in  std_logic_vector(1 downto 0);

        --third 4GB section of AXI
        --aw bus
        m03_axi_awvalid   : out std_logic;
        m03_axi_awready   : in  std_logic;
        m03_axi_awaddr    : out std_logic_vector(31 downto 0);
        m03_axi_awlen     : out std_logic_vector(7 downto 0);
        --w bus
        m03_axi_wvalid    : out std_logic;
        m03_axi_wdata     : out std_logic_vector(511 downto 0);
        m03_axi_wstrb     : out std_logic_vector(63  downto 0);
        m03_axi_wlast     : out std_logic;
        m03_axi_wready    : in  std_logic;

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
 
        --fourth 4GB section of AXI
        --aw bus
        m04_axi_awvalid   : out  std_logic;
        m04_axi_awready   : in   std_logic;
        m04_axi_awaddr    : out  std_logic_vector(31 downto 0);
        m04_axi_awlen     : out  std_logic_vector(7 downto 0);
        --w bus
        m04_axi_wvalid    : out std_logic;
        m04_axi_wdata     : out std_logic_vector(511 downto 0);
        m04_axi_wstrb     : out std_logic_vector(63  downto 0);
        m04_axi_wlast     : out std_logic;
        m04_axi_wready    : in  std_logic;

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
end HBM_PktController;

architecture RTL of HBM_PktController is
    
    COMPONENT ila_0
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
    END COMPONENT;

    signal num_rx_64B_axi_beats,    num_rx_64B_axi_beats_curr_4G,    num_rx_64B_axi_beats_next_4G          : unsigned(7 downto 0);
    signal num_rx_4k_axi_trans,     num_rx_4k_axi_trans_curr_4G,     num_rx_4k_axi_trans_next_4G           : unsigned(1 downto 0);
    signal num_rx_4k_axi_trans_fsm, num_rx_4k_axi_trans_fsm_curr_4G, num_rx_4k_axi_trans_fsm_next_4G       : unsigned(1 downto 0) := 0;

    signal i_data_valid_del, i_valid_rising : std_logic; 
    signal m01_axi_4G_full,  m02_axi_4G_full,  m03_axi_4G_full,  m04_axi_4G_full  : std_logic := '0'; 
    signal LFAAaddr1,        LFAAaddr2,        LFAAaddr3,        LFAAaddr4        : std_logic_vector(32 downto 0) := X"000000000";
    signal LFAAaddr1_shadow, LFAAaddr2_shadow, LFAAaddr3_shadow, LFAAaddr4_shadow : std_logic_vector(32 downto 0) := X"000000000";

    type   input_fsm_type is(idle, generate_aw1_shadow_addr, check_aw1_addr_range, generate_aw1,
                                   generate_aw2_shadow_addr, check_aw2_addr_range, generate_aw2,
				   generate_aw3_shadow_addr, check_aw3_addr_range, generate_aw3,
				   generate_aw4_shadow_addr, check_aw4_addr_range, generate_aw4);
    signal input_fsm : input_fsm_type;				   
    signal direct_aw2, direct_aw3, direct_aw4 : std_logic := '0';
    signal 4k_trans, beats_64B_trans : std_logic := '0';
    signal recv_pkt_counter : unsigned(31 downto 0) := 0;

    signal m01_fifo_rd_en, m02_fifo_rd_en, m03_fifo_rd_en, m04_fifo_rd_en  : std_logic := '0';
    signal fifo_wr_en, fifo_rd_en, fifo_rd_wready, fifo_rst                : std_logic;  
    signal fifo_rd_counter                                                 : unsigned(5 downto 0) := 0;
    signal axi_last, axi_wvalid, axi_wvalid_falling                        : std_logic; 
    signal axi_wvalid_del                                                  : std_logic := '0';  
    signal axi_wdata                                                       : std_logic_vector(511 downto 0);

    --TX signals declaration
    signal num_tx_64B_axi_beats,    num_tx_64B_axi_beats_curr_4G,     num_tx_64B_axi_beats_next_4G          : unsigned(7 downto 0);
    signal num_tx_4k_axi_trans,     num_tx_4k_axi_trans_curr_4G,      num_tx_4k_axi_trans_next_4G           : unsigned(1 downto 0);
    signal num_tx_4k_axi_trans_fsm, num_tx_4k_axi_trans_fsm_curr_4G,  num_tx_4k_axi_trans_fsm_next_4G       : unsigned(1 downto 0) := 0;
    signal num_tx_residual_axi_trans_len, num_tx_residual_axi_trans_len_curr_4G, num_tx_residual_axi_trans_len_next_4G : unsigned(5 downto 0);

    signal m01_axi_4G_empty,     m02_axi_4G_empty,    m03_axi_4G_empty,    m04_axi_4G_empty    : std_logic := '0';
    signal LFAAaddr1_tx,         LFAAaddr2_tx,        LFAAaddr3_tx,        LFAAaddr4_tx        : std_logic_vector(32 downto 0) := X"000000000";
    signal LFAAaddr1_tx_shadow,  LFAAaddr2_tx_shadow, LFAAaddr3_tx_shadow, LFAAaddr4_tx_shadow : std_logic_vector(32 downto 0) := X"000000000";

    type   output_fsm_type is(idle, generate_ar1_shadow_addr, check_ar1_addr_range, generate_aw1, generate_aw1_residual,
                                    generate_ar2_shadow_addr, check_ar2_addr_range, generate_aw2, generate_aw2_residual,
                                    generate_ar3_shadow_addr, check_ar3_addr_range, generate_aw3, generate_aw3_residual,
                                    generate_ar4_shadow_addr, check_ar4_addr_range, generate_aw4, generate_aw4_residual);
    signal output_fsm : output_fsm_type;
    signal direct_ar2, direct_ar3, direct_ar4 : std_logic := '0';
    signal trans_pkt_counter : unsigned(31 downto 0) := 0;

    signal tx_fifo_din, tx_fifo_wr_en, tx_fifo_rd_en, tx_fifo_empty;
begin

    1st_4GB_rx_addr <= LFAAaddr1;
    2nd_4GB_rx_addr <= LFAAaddr2;
    3rd_4GB_rx_addr <= LFAAaddr3;
    4th_4GB_rx_addr <= LFAAaddr4;

    1st_4GB_tx_addr <= LFAAaddr1_tx;
    2nd_4GB_tx_addr <= LFAAaddr2_tx;
    3rd_4GB_tx_addr <= LFAAaddr3_tx;
    4th_4GB_tx_addr <= LFAAaddr4_tx;

    capture_done <= m04_axi_4G_full;
    num_packets_received    <= std_logic_vector(recv_pkt_counter);
    num_packets_transmitted <= std_logic_vector(trans_pkt_counter)
    ---------------------------------------------------------------------------------------------------
    --HBM AXI write transaction part, it is assumed that the recevied packet is always multiple of 64B,
    --i.e no residual AXI trans where less then 64B trans is needed, all the bits of imcoming data is 
    --    valid
    ---------------------------------------------------------------------------------------------------
    num_rx_64B_axi_beats          <= unsigned(i_rx_packet_size(13 downto 6)); -- 64 bytes multiple beat transaction
    num_rx_4k_axi_trans           <= 2 when (unsigned(i_rx_packet_size(13 downto 0)) > 8192) else
	   			     1 when (unsigned(i_rx_packet_size(13 downto 0)) > 4096) else
				     0;

    --first part of split AXI transaction at the 4GB boundary, fit to the current 4GB section 
    num_rx_64B_axi_beats_curr_4G           <= num_rx_bytes_curr_4G(13 downto 6);
    num_rx_4k_axi_trans_curr_4G            <= 2 when num_rx_bytes_curr_4G > 8192 else
                                              1 when num_rx_bytes_curr_4G > 4096 else
                                              0;

    --second part of split AXI transaction at the 4GB boundary, fit to the next 4GB section
    num_rx_64B_axi_beats_next_4G           <= num_rx_bytes_next_4G(13 downto 6);
    num_rx_4k_axi_trans_next_4G            <= 2 when num_rx_bytes_next_4G > 8192 else
                                              1 when num_rx_bytes_next_4G > 4096 else
                                              0;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         i_data_valid_del <= i_data_valid_from_cmac;
      end if;
    end process;      

    i_valid_rising <= i_data_valid_from_cmac and (not i_data_valid_del) when (unsigned(i_rx_packet_size(13 downto 0)) > 64) else
		      i_data_valid_del;

    --//AXI AW part for m01, m02, m03, m04
    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
         input_fsm <= idle;
	 m01_axi_awvalid <= '0';
         m01_axi_awaddr  <= (others => '0');
         m01_axi_awlen   <= (others => '0');
         m02_axi_awvalid <= '0';
         m02_axi_awaddr  <= (others => '0');
         m02_axi_awlen   <= (others => '0');
         m03_axi_awvalid <= '0';
         m03_axi_awaddr  <= (others => '0');
         m03_axi_awlen   <= (others => '0');
         m04_axi_awvalid <= '0';
         m04_axi_awaddr  <= (others => '0');
         m04_axi_awlen   <= (others => '0');
         num_rx_4k_axi_trans_fsm         <= 0;
	 num_rx_4k_axi_trans_fsm_curr_4G <= 0;
	 num_rx_4k_axi_trans_fsm_next_4G <= 0;
	 num_rx_bytes_curr_4G            <= 0;
	 num_rx_bytes_next_4G            <= 0;
	 m01_axi_4G_full <= '0';
         m02_axi_4G_full <= '0';
	 m03_axi_4G_full <= '0';
         m04_axi_4G_full <= '0';	
	 direct_aw2      <= '0';
	 direct_aw3      <= '0';
	 direct_aw4      <= '0';
	 4k_trans        <= '0';
         beats_64B_trans <= '0';
	 LFAAaddr1        <= (others => '0');
	 LFAAaddr2        <= (others => '0');
	 LFAAaddr3        <= (others => '0');
	 LFAAaddr4        <= (others => '0');
	 LFAAaddr1_shadow <= (others => '0');
         LFAAaddr2_shadow <= (others => '0');
         LFAAaddr3_shadow <= (others => '0');
         LFAAaddr4_shadow <= (others => '0');
	 recv_pkt_counter <= 0;
      elsif rising_edge(i_shared_clk) then
         case input_fsm is
           when idle =>
             m01_axi_awvalid <= '0';
             m01_axi_awaddr  <= (others => '0');
             m01_axi_awlen   <= (others => '0');
	     m02_axi_awvalid <= '0';
             m02_axi_awaddr  <= (others => '0');
             m02_axi_awlen   <= (others => '0');
             m03_axi_awvalid <= '0';
             m03_axi_awaddr  <= (others => '0');
             m03_axi_awlen   <= (others => '0');
             m04_axi_awvalid <= '0';
             m04_axi_awaddr  <= (others => '0');
             m04_axi_awlen   <= (others => '0');
             num_rx_4k_axi_trans_fsm <= num_rx_4k_axi_trans;
             if i_valid_rising = '1' and i_enable_capture = '1' and m03_axi_4G_full = '1' then
		if num_rx_bytes_next_4G /= 0 then --if there is split AXI transaction left from third 4GB section, then directly goes to aw4 state to issue AW     
	           direct_aw4    <= '1';
		   input_fsm     <= generate_aw4;
		else
		   input_fsm     <= generate_aw4_shadow_addr;	     
		end if;
             elsif i_valid_rising = '1' and i_enable_capture = '1' and m02_axi_4G_full = '1' then
		if num_rx_bytes_next_4G /= 0 then --if there is split AXI transaction left from second 4GB section, then directly goes to aw3 state to issue AW     
	           direct_aw3    <= '1';
	           input_fsm     <= generate_aw3;
                else		   
 	           input_fsm     <= generate_aw3_shadow_addr;
		end if;
             elsif i_valid_rising = '1' and i_enable_capture = '1' and m01_axi_4G_full = '1' then
		if num_rx_bytes_next_4G /= 0 then --if there is split AXI transaction left from first 4GB section, then directly goes to aw2 state to issue AW
	           direct_aw2    <= '1';
		   input_fsm     <= generate_aw2;
                else		   
		   input_fsm     <= generate_aw2_shadow_addr;
		end if;
	     elsif i_valid_rising = '1' and i_enable_capture = '1';
                input_fsm        <= generate_aw1_shadow_addr;
             end if;
           when generate_aw1_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
		LFAAaddr1_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr1(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
             elsif (num_rx_4k_axi_trans_fsm > 0) then
		LFAAaddr1_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr1(32 downto 12)) + 1);
	     end if;	
	     input_fsm <= check_aw1_addr_range; 
           when check_aw1_addr_range => -- state to calculate how many bytes need to be splitted between current 4GB section and next 4GB section
             if (LFAAaddr1_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
		num_rx_bytes_curr_4G         <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr1(31 downto 0))), 14);
		num_rx_bytes_next_4G         <= unsigned(LFAAaddr1_shadow(13 downto 0));    
	     else
                num_rx_bytes_curr_4G         <= 0;
		num_rx_bytes_next_4G         <= 0;
             end
	     num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
	     num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G;
	     input_fsm                       <= generate_aw1;
           when generate_aw1 =>
             if (LFAAaddr1_shadow(32) /= '1') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then  
                   m01_axi_awvalid           <= '1';
                   m01_axi_awaddr            <= LFAAaddr1(31 downto 6) & "000000";
                   m01_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m01_axi_awready = '1') then
		      4k_trans               <= '0';
		      beats_64B_trans        <= '1';
		      m01_axi_awvalid         <= '0';
                      m01_axi_awaddr          <= (others=>'0');
                      m01_axi_awlen           <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1; 
                      LFAAaddr1(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr1(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
		   recv_pkt_counter           <= recv_pkt_counter + 1;	   
                   input_fsm                  <= idle; --one transaction finished
		elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m01_axi_awvalid            <= '1';
                   m01_axi_awaddr             <= LFAAaddr1(31 downto 12) & "000000000000";
                   m01_axi_awlen              <= "00111111";
                   if (m01_axi_awready = '1') then
		      4k_trans                <= '1';
	              beats_64B_trans         <= '0';
                      m01_axi_awvalid         <= '0';
                      m01_axi_awaddr          <= (others=>'0');
                      m01_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm <= num_rx_4k_axi_trans_fsm - 1;
                      LFAAaddr1(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr1(32 downto 12)) + 1);
                      input_fsm               <= generate_aw1_shadow_addr;
                   end if;
                end if;
             else
               if (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G /= 0) then
                  m01_axi_awvalid             <= '1';
                  m01_axi_awaddr              <= LFAAaddr1(31 downto 6) & "000000";
                  m01_axi_awlen               <= std_logic_vector(num_rx_64B_axi_beats_curr_4G);
                  if (m01_axi_awready = '1') then
	             4k_trans                 <= '0';
                     beats_64B_trans          <= '1';
		     m01_axi_awvalid          <= '0';
                     m01_axi_awaddr           <= (others=>'0');
                     m01_axi_awlen            <= (others=>'0');
                     input_fsm                <= idle;
		     m01_axi_4G_full          <= '1';
		     LFAAaddr1(32 downto 0)   <= X"1FFFFFFFF";
                  end if;
               elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
	             m01_axi_4G_full          <= '1';		  
                     input_fsm                <= idle; --one transaction finished
               elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                  m01_axi_awvalid             <= '1';
                  m01_axi_awaddr              <= LFAAaddr1(31 downto 12) & "000000000000";
                  m01_axi_awlen               <= "00111111";
                  if (m01_axi_awready = '1') then
	             4k_trans                 <= '1';
                     beats_64B_trans          <= '0';
                     m01_axi_awvalid          <= '0';
                     m01_axi_awaddr           <= (others=>'0');
                     m01_axi_awlen            <= (others=>'0');
                     num_rx_4k_axi_trans_fsm_curr_4G  <= num_rx_4k_axi_trans_fsm_curr_4G - 1;
                     LFAAaddr1(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr1(32 downto 12)) + 1);
		     LFAAaddr1_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr1(32 downto 12)) + 1);
                  end if;
               end if;
             end if;
           when generate_aw2_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                LFAAaddr2_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr2(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
             elsif (num_rx_4k_axi_trans_fsm > 0) then
                LFAAaddr2_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
             end if;
             input_fsm <= check_aw2_addr_range;
           when check_aw2_addr_range =>
             if (LFAAaddr2_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr2(31 downto 0))), 14);
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr2_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= 0;
                num_rx_bytes_next_4G         <= 0;		
             end
	     num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
	     num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G
             input_fsm                       <= generate_aw2;
           when generate_aw2 =>
             if (direct_aw2 = '1') then
		if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then     
                   m02_axi_awvalid           <= '1';
		   m02_axi_awaddr            <= LFAAaddr2(31 downto 6) & "000000";
                   m02_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m02_axi_awready = '1') then
		      4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m02_axi_awvalid         <= '0';
                      m02_axi_awaddr          <= (others=>'0');
                      m02_axi_awlen           <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
		      direct_aw2             <= '0';
		      num_rx_bytes_curr_4G   <= (others=>'0');
                      num_rx_bytes_next_4G   <= (others=>'0');
                      LFAAaddr2(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 6)) + resize(num_rx_64B_axi_beats_next_4G,27));
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G = 0) then
		      recv_pkt_counter        <= recv_pkt_counter + 1;	   
	              direct_aw2              <= '0';	  
		      num_rx_bytes_curr_4G    <= (others=>'0');
                      num_rx_bytes_next_4G    <= (others=>'0'); 
                      input_fsm               <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m02_axi_awvalid            <= '1';
                   m02_axi_awaddr             <= LFAAaddr2(31 downto 12) & "000000000000";
                   m02_axi_awlen              <= "00111111";
                   if (m02_axi_awready = '1') then
		      4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m02_axi_awvalid         <= '0';
                      m02_axi_awaddr          <= (others=>'0');
                      m02_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr2(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
                   end if;
                end if; 
             elsif (LFAAaddr2_shadow(32) /= '1') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m02_axi_awvalid           <= '1';
                   m02_axi_awaddr            <= LFAAaddr2(31 downto 6) & "000000";
                   m02_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m02_axi_awready = '1') then
		      4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m01_axi_awvalid         <= '0';
                      m01_axi_awaddr          <= (others=>'0');
                      m01_axi_awlen           <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr2(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                      LFAAaddr2(5  downto 0) <= std_logic_vector(num_rx_residual_axi_trans_len);
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
		      recv_pkt_counter        <= recv_pkt_counter + 1;	   
                      input_fsm               <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m02_axi_awvalid            <= '1';
                   m02_axi_awaddr             <= LFAAaddr2(31 downto 12) & "000000000000";
                   m02_axi_awlen              <= "00111111";
                   if (m01_axi_awready = '1') then
		      4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m01_axi_awvalid         <= '0';
                      m01_axi_awaddr          <= (others=>'0');
                      m01_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm <= num_rx_4k_axi_trans_fsm - 1;
                      LFAAaddr2(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
                      input_fsm               <= generate_aw2_shadow_addr;
                   end if;
                end if;
             else
               if (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G /= 0) then
                  m02_axi_awvalid           <= '1';
                  m02_axi_awaddr            <= LFAAaddr2(31 downto 6) & "000000";
                  m02_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_curr_4G);
                  if (m02_axi_awready = '1') then
		     4k_trans               <= '0';
                     beats_64B_trans        <= '1';
		     m02_axi_awvalid         <= '0';
                     m02_axi_awaddr          <= (others=>'0');
                     m02_axi_awlen           <= (others=>'0');
                     input_fsm              <= idle;
		     m02_axi_4G_full        <= '1';
                     LFAAaddr2(32 downto 0) <= X"1FFFFFFFF";
                  end if;
               elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
	             m02_axi_4G_full        <= '1';		  
                     input_fsm              <= idle; --one transaction finished
               elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                  m02_axi_awvalid            <= '1';
                  m02_axi_awaddr             <= LFAAaddr2(31 downto 12) & "000000000000";
                  m02_axi_awlen              <= "00111111";
                  if (m02_axi_awready = '1') then
		     4k_trans                <= '1';
                     beats_64B_trans         <= '0';
                     m02_axi_awvalid         <= '0';
                     m02_axi_awaddr          <= (others=>'0');
                     m02_axi_awlen           <= (others=>'0');
                     num_rx_4k_axi_trans_fsm_curr_4G  <= num_rx_4k_axi_trans_fsm_curr_4G - 1;
                     LFAAaddr2(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
                     LFAAaddr2_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
                  end if;
               end if;
             end if;
           when generate_aw3_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                LFAAaddr3_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr3(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
             elsif (num_rx_4k_axi_trans_fsm > 0) then
                LFAAaddr3_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
             end if;
             input_fsm <= check_aw3_addr_range;
	   when check_aw3_addr_range =>
             if (LFAAaddr3_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr3(31 downto 0))), 14);
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr3_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= 0;
                num_rx_bytes_next_4G         <= 0;
             end
             num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
             num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G
             input_fsm                       <= generate_aw3;
           when generate_aw3 =>
             if (direct_aw3 = '1') then
                if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then
                   m03_axi_awvalid           <= '1';
                   m03_axi_awaddr            <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m03_axi_awready = '1') then
	              4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m03_axi_awvalid        <= '0';
                      m03_axi_awaddr         <= (others=>'0');
                      m03_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      direct_aw3             <= '0';
                      num_rx_bytes_curr_4G   <= (others=>'0');
                      num_rx_bytes_next_4G   <= (others=>'0');
                      LFAAaddr3(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 6)) + resize(num_rx_64B_axi_beats_next_4G,27));
                      LFAAaddr3(5  downto 0) <= std_logic_vector(num_rx_residual_axi_trans_len_next_4G);
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G = 0) then
                      direct_aw3              <= '0';
                      num_rx_bytes_curr_4G    <= (others=>'0');
                      num_rx_bytes_next_4G    <= (others=>'0');
		      recv_pkt_counter        <= recv_pkt_counter + 1;
                      input_fsm               <= idle; --one transaction finished
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
		      4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr3(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (LFAAaddr3_shadow(32) /= '1') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m03_axi_awvalid           <= '1';
                   m03_axi_awaddr            <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m03_axi_awready = '1') then
	              4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m03_axi_awvalid        <= '0';
                      m03_axi_awaddr         <= (others=>'0');
                      m03_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr3(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                      LFAAaddr3(5  downto 0) <= std_logic_vector(num_rx_residual_axi_trans_len);
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
		   recv_pkt_counter          <= recv_pkt_counter + 1;	   
                   input_fsm                 <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
		      4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm <= num_rx_4k_axi_trans_fsm - 1;
                      LFAAaddr3(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
                      input_fsm               <= generate_aw3_shadow_addr;
                   end if;
                end if;
             else
                if (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G /= 0) then
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_awlen              <= std_logic_vector(num_rx_64B_axi_beats_curr_4G);
                   if (m03_axi_awready = '1') then
		      4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      input_fsm              <= idle;
                      m03_axi_4G_full        <= '1';
                      LFAAaddr3(32 downto 0) <= X"1FFFFFFFF";
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
                      m03_axi_4G_full        <= '1';
                      input_fsm              <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
	              4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_curr_4G  <= num_rx_4k_axi_trans_fsm_curr_4G - 1;
                      LFAAaddr3(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
                      LFAAaddr3_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
                   end if;
                end if;
             end if;
           when generate_aw4_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                LFAAaddr4_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr4(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
             elsif (num_rx_4k_axi_trans_fsm > 0) then
                LFAAaddr4_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 12)) + 1);
             end if;
             input_fsm <= check_aw4_addr_range;
           when check_aw4_addr_range =>
             if (LFAAaddr4_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr4(31 downto 0))), 14);
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr4_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= 0;
                num_rx_bytes_next_4G         <= 0;
             end
             num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
             num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G
             input_fsm <= generate_aw4;
           when generate_aw4 =>
             if (direct_aw4 = '1') then
                if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then
                   m04_axi_awvalid           <= '1';
                   m04_axi_awaddr            <= LFAAaddr4(31 downto 6) & "000000";
                   m04_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m04_axi_awready = '1') then
		      4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m04_axi_awvalid        <= '0';
                      m04_axi_awaddr         <= (others=>'0');
                      m04_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      direct_aw4             <= '0';
                      num_rx_bytes_curr_4G   <= (others=>'0');
                      num_rx_bytes_next_4G   <= (others=>'0');
                      LFAAaddr4(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 6)) + resize(num_rx_64B_axi_beats_next_4G,27));
                      LFAAaddr4(5  downto 0) <= std_logic_vector(num_rx_residual_axi_trans_len_next_4G);
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G = 0) then
                      direct_aw4              <= '0';
		      recv_pkt_counter        <= recv_pkt_counter + 1;
                      num_rx_bytes_curr_4G    <= (others=>'0');
                      num_rx_bytes_next_4G    <= (others=>'0');
                      input_fsm               <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m04_axi_awvalid            <= '1';
                   m04_axi_awaddr             <= LFAAaddr4(31 downto 12) & "000000000000";
                   m04_axi_awlen              <= "00111111";
                   if (m04_axi_awready = '1') then
	              4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m04_axi_awvalid         <= '0';
                      m04_axi_awaddr          <= (others=>'0');
                      m04_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr4(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (LFAAaddr4_shadow(32) /= '1') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m04_axi_awvalid           <= '1';
                   m04_axi_awaddr            <= LFAAaddr4(31 downto 6) & "000000";
                   m04_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m04_axi_awready = '1') then
	              4k_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m04_axi_awvalid        <= '0';
                      m04_axi_awaddr         <= (others=>'0');
                      m04_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr4(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                      LFAAaddr4(5  downto 0) <= std_logic_vector(num_rx_residual_axi_trans_len);
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
                      input_fsm               <= idle; --one transaction finished
		      recv_pkt_counter        <= recv_pkt_counter + 1;
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m04_axi_awvalid            <= '1';
                   m04_axi_awaddr             <= LFAAaddr4(31 downto 12) & "000000000000";
                   m04_axi_awlen              <= "00111111";
                   if (m04_axi_awready = '1') then
		      4k_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m04_axi_awvalid         <= '0';
                      m04_axi_awaddr          <= (others=>'0');
                      m04_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm <= num_rx_4k_axi_trans_fsm - 1;
                      LFAAaddr4(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 12)) + 1);
                      input_fsm               <= generate_aw4_shadow_addr;
                   end if;
                end if;
             else 
                m04_axi_awvalid               <= '0';
                m04_axi_awaddr                <= (others=>'0');
                m04_axi_awlen                 <= (others=>'0');
                m04_axi_4G_full               <= '1';
                input_fsm                     <= idle;
             end if;
         end case;		   
      end if;
    end process;

    --MUX to select between m01 m02 m03 m04 AXI buses    
    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
      	 m01_axi_wvalid <= (others => '0');
         m01_axi_wdata  <= (others => '0');
         m01_axi_wstrb  <= (others => '1');
         m01_axi_wlast  <= '0';
         m02_axi_wvalid <= (others => '0');
         m02_axi_wdata  <= (others => '0');
         m02_axi_wstrb  <= (others => '1');
         m02_axi_wlast  <= '0';
	 m03_axi_wvalid <= (others => '0');
         m03_axi_wdata  <= (others => '0');
         m03_axi_wstrb  <= (others => '1');
         m03_axi_wlast  <= '0';
         m04_axi_wvalid <= (others => '0');
         m04_axi_wdata  <= (others => '0');
         m04_axi_wstrb  <= (others => '1');
         m04_axi_wlast  <= '0';
	 axi_wready     <= '0';   
      elsif rising_edge(i_shared_clk) then
         if (m01_fifo_rd_en = '1') then
            m01_axi_wvalid <= axi_wvalid;
	    m01_axi_wdata  <= axi_wdata;
	    m01_axi_wlast  <= axi_wlast;
	    axi_wready     <= m01_axi_wready; 
         elsif (m02_fifo_rd_en = '1') then
            m02_axi_wvalid <= axi_wvalid;
            m02_axi_wdata  <= axi_wdata;
	    m02_axi_wlast  <= axi_wlast;
            axi_wready     <= m02_axi_wready;
	 elsif (m03_fifo_rd_en = '1') then
            m03_axi_wvalid <= axi_wvalid;
            m03_axi_wdata  <= axi_wdata;
	    m03_axi_wlast  <= axi_wlast;
            axi_wready     <= m03_axi_wready;
         elsif (m04_fifo_rd_en = '1') then
            m04_axi_wvalid <= axi_wvalid;
            m04_axi_wdata  <= axi_wdata;
	    m04_axi_wlast  <= axi_wlast;
            axi_wready     <= m04_axi_wready; 
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
       	 m01_fifo_rd_en  <= '0';     
      elsif rising_edge(i_shared_clk) then
	 if (m01_axi_awvalid = '1' and m01_axi_awready = '1') then
            m01_fifo_rd_en  <= '1';
         elsif axi_wvalid_falling = '1' then
	    m01_fifo_rd_en  <= '0';  	 
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then	    
         m01_fifo_rd_en  <= '0'; 
      elsif rising_edge(i_shared_clk) then
         if (m02_axi_awvalid = '1' and m02_axi_awready = '1') then
            m02_fifo_rd_en  <= '1';
         elsif axi_wvalid_falling = '1' then
            m02_fifo_rd_en  <= '0';
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
         m03_fifo_rd_en  <= '0';	      
      elsif rising_edge(i_shared_clk) then
         if (m03_axi_awvalid = '1' and m03_axi_awready = '1') then
            m03_fifo_rd_en  <= '1';
         elsif axi_wvalid_falling = '1' then
            m03_fifo_rd_en  <= '0';
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
         m04_fifo_rd_en  <= '0';   
      elsif rising_edge(i_shared_clk) then
         if (m04_axi_awvalid = '1' and m04_axi_awready = '1') then
            m04_fifo_rd_en  <= '1';
         elsif axi_wvalid_falling = '1' then --when one packet reading from fifo is finished
            m04_fifo_rd_en  <= '0';
         end if;
      end if;
    end process;

 fifo_wr_en <= i_data_valid_from_cmac and i_enable_capture; 
 fifo_rd_en <= (m01_fifo_rd_en and m01_axi_wready) or (m02_fifo_rd_en and m02_axi_wready) or (m03_fifo_rd_en and m03_axi_wready) or (m04_fifo_rd_en and m04_axi_wready);
 fifo_rd_wready <= m01_axi_wready or m02_axi_wready or m03_axi_wready or m04_axi_wready; 
 fifo_rst       <= i_soft_reset or i_shared_rst; 

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
         fifo_rd_counter <= (others=>'0');
         axi_last        <= '0';
      elsif rising_edge(i_shared_clk) then
	 if (4k_trans               = '1' and fifo_rd_counter = 63) or 
	    (beats_64B_trans        = '1' and (fifo_rd_counter = num_rx_64B_axi_beats-1          or 
	                                       fifo_rd_counter = num_rx_64B_axi_beats_curr_4G-1  or 
					       fifo_rd_counter = num_rx_64B_axi_beats_next_4G-1) or
            fifo_rd_counter <= (others=>'0');
            axi_last        <= '1';			       
	 elsif fifo_rd_en = '1' then 
            fifo_rd_counter <= fifo_rd_counter + 1;
	    axi_last        <= '0';
         elsif fifo_rd_wready = '1' then
	    axi_last        <= '0';
	 end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         axi_wvalid_del <= axi_wvalid;
      end if;
    end process; 

    axi_wvalid_falling <= axi_wvalid_del and (not axi_wvalid) when (unsigned(i_rx_packet_size(13 downto 0)) > 64) else
			  axi_wvalid_del;  

    fifo_wdata_inst : xpm_fifo_sync
    generic map (
        DOUT_RESET_VALUE    => "0",    
        ECC_MODE            => "no_ecc",
        FIFO_MEMORY_TYPE    => "auto", 
        FIFO_READ_LATENCY   => 0,
        FIFO_WRITE_DEPTH    => 64,     
        FULL_RESET_VALUE    => 0,      
        PROG_EMPTY_THRESH   => 10,    
	PROG_FULL_THRESH    => 10,     
        RD_DATA_COUNT_WIDTH => 6,  
        READ_DATA_WIDTH     => 512,      
        READ_MODE           => "fwft",  
        SIM_ASSERT_CHK      => 0,      
        USE_ADV_FEATURES    => "1404", 
        WAKEUP_TIME         => 0,      
        WRITE_DATA_WIDTH    => 512,     
        WR_DATA_COUNT_WIDTH => 6   
    )
    port map (
        almost_empty  => open,  
        almost_full   => open,
        data_valid    => axi_wvalid,   
        dbiterr       => open, 
        dout          => axi_wdata,
        empty         => open,
        full          => open, 
        overflow      => open,
        prog_empty    => open, 
        prog_full     => open,
        rd_data_count => open, 
        rd_rst_busy   => open,
        sbiterr       => open,
        underflow     => open,
        wr_ack        => open,
        wr_data_count => open,
        wr_rst_busy   => open, 
        din           => i_data_from_cmac,
        injectdbiterr => '0',     
        injectsbiterr => '0',      
        rd_en         => fifo_rd_en,  
        rst           => fifo_rst, 
        sleep         => '0', 
        wr_clk        => i_shared_clk,   
        wr_en         => fifo_wr_en 
    );

    ------------------------------------------------------------------------------------------------------
    --HBM AXI read transaction part
    ------------------------------------------------------------------------------------------------------
    o_packetiser_bytes_to_transmit <= i_tx_packet_size(13 downto 0);

    num_tx_64B_axi_beats          <= num_tx_64B_residual_axi_trans(13 downto 6); -- 64 bytes multiple beat transaction
    num_tx_residual_axi_trans_len <= num_tx_64B_residual_axi_trans(5  downto 0); -- residual axi transaction, less than 64 bytes
    num_tx_4k_axi_trans           <= 2 when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                     1 when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                     0;
    num_tx_64B_residual_axi_trans <= resize((unsigned(i_tx_packet_size(13 downto 0)) - 8192),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                     resize((unsigned(i_tx_packet_size(13 downto 0)) - 4096),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                     unsigned(i_tx_packet_size(13 downto 0));

    --number of different types of AXI transactions for the residual bytes of the current 4GB section to fill
    num_tx_64B_axi_beats_curr_4G          <= num_tx_64B_residual_axi_trans_curr_4G(13 downto 6); -- 64 bytes multiple beat transaction
    num_tx_residual_axi_trans_len_curr_4G <= num_tx_64B_residual_axi_trans_curr_4G(5  downto 0); -- residual axi transaction, less than 64 bytes
    num_tx_4k_axi_trans_curr_4G           <= 2 when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                             1 when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                             0;
    num_tx_64B_residual_axi_trans_curr_4G <= resize((unsigned(i_tx_packet_size(13 downto 0)) - 8192),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                             resize((unsigned(i_tx_packet_size(13 downto 0)) - 4096),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                             unsigned(i_tx_packet_size(13 downto 0));
   
    --number of different types of AXI transactions for the residual bytes of the next 4GB section to fill 
    num_tx_64B_axi_beats_next_4G          <= num_tx_64B_residual_axi_trans_next_4G(13 downto 6); -- 64 bytes multiple beat transaction
    num_tx_residual_axi_trans_len_next_4G <= num_tx_64B_residual_axi_trans_next_4G(5  downto 0); -- residual axi transaction, less than 64 bytes
    num_tx_4k_axi_trans_next_4G           <= 2 when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                             1 when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                             0;
    num_tx_64B_residual_axi_trans_next_4G <= resize((unsigned(i_tx_packet_size(13 downto 0)) - 8192),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 8192) else
                                             resize((unsigned(i_tx_packet_size(13 downto 0)) - 4096),14) when (unsigned(i_tx_packet_size(13 downto 0)) > 4096) else
                                             unsigned(i_tx_packet_size(13 downto 0));



    --//AXI AR part for m01, m02, m03, m04
    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
	 m01_axi_arvalid                 <= '0';
         m01_axi_araddr                  <= (others => '0');
         m01_axi_arlen                   <= (others => '0');
         m02_axi_arvalid                 <= '0';
         m02_axi_araddr                  <= (others => '0');
         m02_axi_arlen                   <= (others => '0');
         m03_axi_arvalid                 <= '0';
         m03_axi_araddr                  <= (others => '0');
         m03_axi_arlen                   <= (others => '0');
         m04_axi_arvalid                 <= '0';
         m04_axi_araddr                  <= (others => '0');
         m04_axi_arlen                   <= (others => '0');     
	 num_tx_4k_axi_trans_fsm         <= 0;
         num_tx_4k_axi_trans_fsm_curr_4G <= 0;
         num_tx_4k_axi_trans_fsm_next_4G <= 0;
         num_tx_bytes_curr_4G            <= 0;
         num_tx_bytes_next_4G            <= 0;
         m01_axi_4G_empty                <= '0';
         m02_axi_4G_empty                <= '0';
         m03_axi_4G_empty                <= '0';
         m04_axi_4G_empty                <= '0';
         direct_ar2                      <= '0';
         direct_ar3                      <= '0';
         direct_ar4                      <= '0';
         LFAAaddr1_tx        <= (others => '0');
         LFAAaddr2_tx        <= (others => '0');
         LFAAaddr3_tx        <= (others => '0');
         LFAAaddr4_tx        <= (others => '0');
         LFAAaddr1_tx_shadow <= (others => '0');
         LFAAaddr2_tx_shadow <= (others => '0');
         LFAAaddr3_tx_shadow <= (others => '0');
         LFAAaddr4_tx_shadow <= (others => '0');
         trans_pkt_counter <= 0;     
         output_fsm <= idle;
      elsif rising_edge(i_shared_clk) then
         case input_fsm is
           when idle =>
             m01_axi_arvalid <= '0';
             m01_axi_araddr  <= (others => '0');
             m01_axi_arlen   <= (others => '0');
             m02_axi_arvalid <= '0';
             m02_axi_araddr  <= (others => '0');
             m02_axi_arlen   <= (others => '0');
             m03_axi_arvalid <= '0';
             m03_axi_araddr  <= (others => '0');
             m03_axi_arlen   <= (others => '0');
             m04_axi_arvalid <= '0';
             m04_axi_araddr  <= (others => '0');
             m04_axi_arlen   <= (others => '0');
             num_tx_4k_axi_trans_fsm  <= num_tx_4k_axi_trans;
             if i_start_tx = '1' and m03_axi_4G_empty = '1' then
                if num_tx_bytes_next_4G /= 0 then --if there is split AXI transaction left from third 4GB section, then directly goes to ar4 state to issue AR     
                   direct_ar4     <= '1';
                   output_fsm     <= generate_ar4;
                else
                   output_fsm     <= generate_ar4_shadow_addr;
                end if;
             elsif i_start_tx = '1' and m02_axi_4G_empty = '1' then
                if num_tx_bytes_next_4G /= 0 then --if there is split AXI transaction left from second 4GB section, then directly goes to ar3 state to issue AR     
                   direct_ar3     <= '1';
                   output_fsm     <= generate_ar3;
                else
                   output_fsm     <= generate_ar3_shadow_addr;
                end if;
             elsif i_start_tx = '1' and m01_axi_4G_empty = '1' then
                if num_tx_bytes_next_4G /= 0 then --if there is split AXI transaction left from first 4GB section, then directly goes to ar2 state to issue AR
                   direct_ar2     <= '1';
                   output_fsm     <= generate_ar2;
                else
                   output_fsm     <= generate_ar2_shadow_addr;
                end if;
	     elsif i_start_tx = '1' then
                output_fsm        <= generate_ar1_shadow_addr;
             end if;
           when generate_ar1_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                LFAAaddr1_tx_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                LFAAaddr1_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                LFAAaddr1_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm > 0) then
                LFAAaddr1_tx_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 12)) + 1);
             end if;
             output_fsm <= check_ar1_addr_range;
           when check_ar1_addr_range =>
             if (LFAAaddr1_tx_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_tx_bytes_curr_4G         <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr1_tx(31 downto 0))), 14);
                num_tx_bytes_next_4G         <= unsigned(LFAAaddr1_tx_shadow(13 downto 0));
             else
                num_tx_bytes_curr_4G         <= 0;
                num_tx_bytes_next_4G         <= 0;
             end
             num_tx_4k_axi_trans_fsm_curr_4G <= num_tx_4k_axi_trans_curr_4G;
             num_tx_4k_axi_trans_fsm_next_4G <= num_tx_4k_axi_trans_next_4G;
             output_fsm                      <= generate_ar1;
           when generate_ar1 =>
             if (LFAAaddr1_tx_shadow(32) /= '1') then
                if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                   m01_axi_arvalid           <= '1';
                   m01_axi_araddr            <= LFAAaddr1(31 downto 6) & "000000";
                   m01_axi_arlen             <= std_logic_vector(num_tx_64B_axi_beats);
                   if (m01_axi_arready = '1') then
		      m01_axi_arvalid         <= '0';
                      m01_axi_araddr          <= (others=>'0');
                      m01_axi_arlen           <= (others=>'0');
		      if num_tx_residual_axi_trans_len /= 0 then
                         output_fsm          <= generate_ar1_residual
                      else	   
                         output_fsm          <= idle;
		      end if;
                      trans_pkt_counter      <= trans_pkt_counter + 1;
                      LFAAaddr1_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
		   if num_tx_residual_axi_trans_len /= 0 then 		
		     output_fsm               <= generate_ar1_residual
		   else	   
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
	           end if  
                elsif (num_tx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m01_axi_arvalid            <= '1';
                   m01_axi_araddr             <= LFAAaddr1_tx(31 downto 12) & "000000000000";
                   m01_axi_arlen              <= "00111111";
                   if (m01_axi_arready = '1') then
                      m01_axi_arvalid         <= '0';
                      m01_axi_araddr          <= (others=>'0');
                      m01_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm <= num_tx_4k_axi_trans_fsm - 1;
                      LFAAaddr1_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 12)) + 1);
                      output_fsm              <= generate_ar1_shadow_addr;
                   end if;
                end if;
             else
                if (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G /= 0) then
                   m01_axi_arvalid            <= '1';
                   m01_axi_araddr             <= LFAAaddr1_tx(31 downto 6) & "000000";
                   m01_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_curr_4G); 
                   if (m01_axi_arready = '1') then
		      m01_axi_arvalid         <= '0';
                      m01_axi_araddr          <= (others=>'0');
                      m01_axi_arlen           <= (others=>'0');
		      if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                         output_fsm           <= generate_ar1_residual
                      else
                         output_fsm           <= idle;
		      end if;
                      m01_axi_4G_empty        <= '1';
                      LFAAaddr1_tx(32 downto 0) <= X"1FFFFFFFF";
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G = 0) then
		   if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                      output_fsm               <= generate_ar1_residual
                   else
                      m01_axi_4G_empty         <= '1';
                      output_fsm               <= idle; --one transaction finished
		   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G > 0) then
                   m01_axi_arvalid             <= '1';
                   m01_axi_araddr              <= LFAAaddr1_tx(31 downto 12) & "000000000000";
                   m01_axi_arlen               <= "00111111";
                   if (m01_axi_arready = '1') then
                     m01_axi_arvalid           <= '0';
                     m01_axi_araddr            <= (others=>'0');
                     m01_axi_arlen             <= (others=>'0');
                     num_tx_4k_axi_trans_fsm_curr_4G     <= num_tx_4k_axi_trans_fsm_curr_4G - 1;
                     LFAAaddr1_tx(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 12)) + 1);
                     LFAAaddr1_tx_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 12)) + 1);
                  end if;
               end if;
             end if;
           when generate_ar1_residual => 
		--even if the number of residual bytes is less than 64 bytes, still read in 64 bytes, let packet_player to
		--get rid of unwanted bytes 
		m01_axi_arvalid                <= '1';
	        m01_axi_araddr                 <= LFAAaddr1_tx(31 downto 0);
	        m01_axi_arlen                  <= "00000000";
	        if (m01_axi_arready = '1') then
                   m01_axi_arvalid             <= '0';
                   m01_axi_araddr              <= (others=>'0');
                   m01_axi_arlen               <= (others=>'0');
		   LFAAaddr1_tx(32 downto 0)   <= std_logic_vector(unsigned(LFAAaddr1_tx(32 downto 0)) + num_tx_residual_axi_trans_len_curr_4G);             
                   output_fsm                  <= idle; --one transaction finished
                end if;
           when generate_ar2_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                LFAAaddr2_tx_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                LFAAaddr2_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                LFAAaddr2_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm > 0) then
                LFAAaddr2_tx_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 12)) + 1);
             end if;
             output_fsm <= check_ar2_addr_range;
           when check_ar2_addr_range =>
             if (LFAAaddr2_tx_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_tx_bytes_curr_4G          <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr2_tx(31 downto 0))), 14);
                num_tx_bytes_next_4G          <= unsigned(LFAAaddr2_tx_shadow(13 downto 0));
             else
                num_tx_bytes_curr_4G          <= 0;
                num_tx_bytes_next_4G          <= 0;
             end
             num_tx_4k_axi_trans_fsm_curr_4G  <= num_tx_4k_axi_trans_curr_4G;
             num_tx_4k_axi_trans_fsm_next_4G  <= num_tx_4k_axi_trans_next_4G;
             output_fsm                       <= generate_ar2;
           when generate_ar2 =>
             if (direct_ar2 = '1') then
                if (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G /= 0) then
                   m02_axi_arvalid            <= '1';
                   m02_axi_araddr             <= LFAAaddr2_tx(31 downto 6) & "000000";
                   m02_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_next_4G);
                   if (m02_axi_arready = '1') then
                      m02_axi_arvalid         <= '0';
                      m02_axi_araddr          <= (others=>'0');
                      m02_axi_arlen           <= (others=>'0');
		      if num_tx_residual_axi_trans_len_next_4G /= 0 then
                         output_fsm           <= generate_ar2_residual
                      else
                         output_fsm           <= idle;
	              end if;
                      trans_pkt_counter       <= trans_pkt_counter + 1;
                      direct_ar2              <= '0';
                      num_tx_bytes_curr_4G    <= (others=>'0');
                      num_tx_bytes_next_4G    <= (others=>'0');
                      LFAAaddr2_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 6)) + resize(num_tx_64B_axi_beats_next_4G,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G = 0) then
                   direct_ar2                 <= '0';
                   num_tx_bytes_curr_4G       <= (others=>'0');
                   num_tx_bytes_next_4G       <= (others=>'0');
		   if num_tx_residual_axi_trans_len_next_4G /= 0 then
                     output_fsm               <= generate_ar2_residual
                   else
	             trans_pkt_counter        <= trans_pkt_counter + 1;		   
                     output_fsm               <= idle; --one transaction finished
		   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m02_axi_arvalid            <= '1';
                   m02_axi_araddr             <= LFAAaddr2_tx(31 downto 12) & "000000000000";
                   m02_axi_arlen              <= "00111111";
                   if (m02_axi_awready = '1') then
                      m02_axi_arvalid         <= '0';
                      m02_axi_araddr          <= (others=>'0');
                      m02_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm_next_4G <= num_tx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr2_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (LFAAaddr2_tx_shadow(32) /= '1') then
                if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                   m02_axi_arvalid           <= '1';
                   m02_axi_araddr            <= LFAAaddr2(31 downto 6) & "000000";
                   m02_axi_arlen             <= std_logic_vector(num_tx_64B_axi_beats);
                   if (m02_axi_arready = '1') then
                      m02_axi_arvalid        <= '0';
                      m02_axi_araddr         <= (others=>'0');
                      m02_axi_arlen          <= (others=>'0');
                      if num_tx_residual_axi_trans_len /= 0 then
                         output_fsm          <= generate_ar2_residual;
                      else
                         output_fsm          <= idle;
                      end if;
                      trans_pkt_counter      <= trans_pkt_counter + 1;
                      LFAAaddr2_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                   if num_tx_residual_axi_trans_len /= 0 then
                     output_fsm               <= generate_ar2_residual;
                   else
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
                   end if
                elsif (num_tx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m02_axi_arvalid            <= '1';
                   m02_axi_araddr             <= LFAAaddr2_tx(31 downto 12) & "000000000000";
                   m02_axi_arlen              <= "00111111";
                   if (m02_axi_arready = '1') then
                      m02_axi_arvalid         <= '0';
                      m02_axi_araddr          <= (others=>'0');
                      m02_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm <= num_tx_4k_axi_trans_fsm - 1;
                      LFAAaddr2_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 12)) + 1);
                      output_fsm              <= generate_ar2_shadow_addr;
                   end if;
                end if;
             else
                if (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G /= 0) then
                   m02_axi_arvalid            <= '1';
                   m02_axi_araddr             <= LFAAaddr2_tx(31 downto 6) & "000000";
                   m02_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_curr_4G);
                   if (m02_axi_arready = '1') then
                      m02_axi_arvalid         <= '0';
                      m02_axi_araddr          <= (others=>'0');
                      m02_axi_arlen           <= (others=>'0');
                      if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                         output_fsm           <= generate_ar2_residual
                      else
                         output_fsm           <= idle;
                      end if;
                      m02_axi_4G_empty        <= '1';
                      LFAAaddr2_tx(32 downto 0) <= X"1FFFFFFFF";
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G = 0) then
                   if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                      output_fsm               <= generate_ar2_residual
                   else
                      m02_axi_4G_empty         <= '1';
                      output_fsm               <= idle; --one transaction finished
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G > 0) then
                   m02_axi_arvalid             <= '1';
                   m02_axi_araddr              <= LFAAaddr2_tx(31 downto 12) & "000000000000";
                   m02_axi_arlen               <= "00111111";
                   if (m02_axi_arready = '1') then
                     m02_axi_arvalid           <= '0';
                     m02_axi_araddr            <= (others=>'0');
                     m02_axi_arlen             <= (others=>'0');
                     num_tx_4k_axi_trans_fsm_curr_4G     <= num_tx_4k_axi_trans_fsm_curr_4G - 1;
                     LFAAaddr2_tx(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 12)) + 1);
                     LFAAaddr2_tx_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 12)) + 1);
                   end if;
                end if;
             end if;
           when generate_ar2_residual =>
             --even if the number of residual bytes is less than 64 bytes, still read in 64 bytes, let packet_player to
             --get rid of unwanted bytes 
             m02_axi_arvalid                   <= '1';
             m02_axi_araddr                    <= LFAAaddr2_tx(31 downto 0);
             m02_axi_arlen                     <= "00000000";
             if (m02_axi_arready = '1') then
                m02_axi_arvalid                <= '0';
                m02_axi_araddr                 <= (others=>'0');
                m02_axi_arlen                  <= (others=>'0');
                LFAAaddr2_tx(32 downto 0)      <= std_logic_vector(unsigned(LFAAaddr2_tx(32 downto 0)) + num_tx_residual_axi_trans_len_curr_4G);
                output_fsm                     <= idle; --one transaction finished
             end if;
           when generate_ar3_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                LFAAaddr3_tx_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                LFAAaddr3_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                LFAAaddr3_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm > 0) then
                LFAAaddr3_tx_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 12)) + 1);
             end if;
             output_fsm <= check_ar3_addr_range;
           when check_ar3_addr_range =>
             if (LFAAaddr3_tx_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_tx_bytes_curr_4G          <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr3_tx(31 downto 0))), 14);
                num_tx_bytes_next_4G          <= unsigned(LFAAaddr3_tx_shadow(13 downto 0));
             else
                num_tx_bytes_curr_4G          <= 0;
                num_tx_bytes_next_4G          <= 0;
             end
             num_tx_4k_axi_trans_fsm_curr_4G  <= num_tx_4k_axi_trans_curr_4G;
             num_tx_4k_axi_trans_fsm_next_4G  <= num_tx_4k_axi_trans_next_4G;
             output_fsm                       <= generate_ar3;
           when generate_ar3 =>
             if (direct_ar3 = '1') then
                if (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G /= 0) then
                   m03_axi_arvalid            <= '1';
                   m03_axi_araddr             <= LFAAaddr3_tx(31 downto 6) & "000000";
                   m03_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_next_4G);
                   if (m03_axi_arready = '1') then
                      m03_axi_arvalid         <= '0';
                      m03_axi_araddr          <= (others=>'0');
                      m03_axi_arlen           <= (others=>'0');
                      if num_tx_residual_axi_trans_len_next_4G /= 0 then
                         output_fsm           <= generate_ar3_residual
                      else
                         output_fsm           <= idle;
                      end if;
                      trans_pkt_counter       <= trans_pkt_counter + 1;
                      direct_ar3              <= '0';
                      num_tx_bytes_curr_4G    <= (others=>'0');
                      num_tx_bytes_next_4G    <= (others=>'0');
                      LFAAaddr3_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 6)) + resize(num_tx_64B_axi_beats_next_4G,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G = 0) then
                   direct_ar3                 <= '0';
                   num_tx_bytes_curr_4G       <= (others=>'0');
                   num_tx_bytes_next_4G       <= (others=>'0');
                   if num_tx_residual_axi_trans_len_next_4G /= 0 then
                     output_fsm               <= generate_ar3_residual
                   else
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_arvalid            <= '1';
                   m03_axi_araddr             <= LFAAaddr3_tx(31 downto 12) & "000000000000";
                   m03_axi_arlen              <= "00111111";
                   if (m03_axi_awready = '1') then
                      m03_axi_arvalid         <= '0';
                      m03_axi_araddr          <= (others=>'0');
                      m03_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm_next_4G <= num_tx_4k_axi_trans_fsm_next_4G - 1;
		      LFAAaddr3_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (LFAAaddr3_tx_shadow(32) /= '1') then
                if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                   m03_axi_arvalid           <= '1';
                   m03_axi_araddr            <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_arlen             <= std_logic_vector(num_tx_64B_axi_beats);
                   if (m03_axi_arready = '1') then
                      m03_axi_arvalid        <= '0';
                      m03_axi_araddr         <= (others=>'0');
                      m03_axi_arlen          <= (others=>'0');
                      if num_tx_residual_axi_trans_len /= 0 then
                         output_fsm          <= generate_ar3_residual;
                      else
                         output_fsm          <= idle;
                      end if;
                      trans_pkt_counter      <= trans_pkt_counter + 1;
                      LFAAaddr3_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                   if num_tx_residual_axi_trans_len /= 0 then
                     output_fsm               <= generate_ar3_residual;
                   else
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
                   end if
                elsif (num_tx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_arvalid            <= '1';
                   m03_axi_araddr             <= LFAAaddr3_tx(31 downto 12) & "000000000000";
                   m03_axi_arlen              <= "00111111";
                   if (m03_axi_arready = '1') then
                      m03_axi_arvalid         <= '0';
                      m03_axi_araddr          <= (others=>'0');
                      m03_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm <= num_tx_4k_axi_trans_fsm - 1;
                      LFAAaddr3_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 12)) + 1);
                      output_fsm              <= generate_ar3_shadow_addr;
                   end if;
                end if;
             else
                if (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G /= 0) then
                   m03_axi_arvalid            <= '1';
                   m03_axi_araddr             <= LFAAaddr3_tx(31 downto 6) & "000000";
                   m03_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_curr_4G);
                   if (m03_axi_arready = '1') then
                      m03_axi_arvalid         <= '0';
                      m03_axi_araddr          <= (others=>'0');
                      m03_axi_arlen           <= (others=>'0');
                      if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                         output_fsm           <= generate_ar3_residual
                      else
                         output_fsm           <= idle;
                      end if;
                      m03_axi_4G_empty        <= '1';
                      LFAAaddr3_tx(32 downto 0) <= X"1FFFFFFFF";
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G = 0 and num_tx_64B_axi_beats_curr_4G = 0) then
                   if num_tx_residual_axi_trans_len_curr_4G /= 0 then
                      output_fsm               <= generate_ar3_residual
                   else
                      m03_axi_4G_empty         <= '1';
                      output_fsm               <= idle; --one transaction finished
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_curr_4G > 0) then
                   m03_axi_arvalid             <= '1';
                   m03_axi_araddr              <= LFAAaddr3_tx(31 downto 12) & "000000000000";
                   m03_axi_arlen               <= "00111111";
                   if (m03_axi_arready = '1') then
                      m03_axi_arvalid           <= '0';
                      m03_axi_araddr            <= (others=>'0');
                      m03_axi_arlen             <= (others=>'0');
                      num_tx_4k_axi_trans_fsm_curr_4G     <= num_tx_4k_axi_trans_fsm_curr_4G - 1;
                      LFAAaddr3_tx(32 downto 12)          <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 12)) + 1);
                      LFAAaddr3_tx_shadow(32 downto 12)   <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 12)) + 1);
                   end if;
                end if;
             end if;
           when generate_ar3_residual =>
             --even if the number of residual bytes is less than 64 bytes, still read in 64 bytes, let packet_player to
             --get rid of unwanted bytes 
             m03_axi_arvalid                   <= '1';
             m03_axi_araddr                    <= LFAAaddr3_tx(31 downto 0);
             m03_axi_arlen                     <= "00000000";
             if (m03_axi_arready = '1') then
                m03_axi_arvalid                <= '0';
                m03_axi_araddr                 <= (others=>'0');
                m03_axi_arlen                  <= (others=>'0');
                LFAAaddr3_tx(32 downto 0)      <= std_logic_vector(unsigned(LFAAaddr3_tx(32 downto 0)) + num_tx_residual_axi_trans_len_curr_4G);
                output_fsm                     <= idle; --one transaction finished
             end if;
           when generate_ar4_shadow_addr  => --shadow addr used to detect if a 4GB AXI HBM section is filled
             if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                LFAAaddr4_tx_shadow(32 downto 6)  <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                LFAAaddr4_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                LFAAaddr4_tx_shadow(5  downto 0)  <= std_logic_vector(num_tx_residual_axi_trans_len);
             elsif (num_tx_4k_axi_trans_fsm > 0) then
                LFAAaddr4_tx_shadow(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 12)) + 1);
             end if;
             output_fsm <= check_ar4_addr_range;
           when check_ar4_addr_range =>
             if (LFAAaddr4_tx_shadow(32) = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_tx_bytes_curr_4G          <= resize((unsigned(X"FFFFFFFF") - unsigned(LFAAaddr4_tx(31 downto 0))), 14);
                num_tx_bytes_next_4G          <= unsigned(LFAAaddr4_tx_shadow(13 downto 0));
             else
                num_tx_bytes_curr_4G          <= 0;
                num_tx_bytes_next_4G          <= 0;
             end
             num_tx_4k_axi_trans_fsm_curr_4G  <= num_tx_4k_axi_trans_curr_4G;
             num_tx_4k_axi_trans_fsm_next_4G  <= num_tx_4k_axi_trans_next_4G;
             output_fsm                       <= generate_ar4;
           when generate_ar4 =>
             if (direct_ar4 = '1') then
                if (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G /= 0) then
                   m04_axi_arvalid            <= '1';
                   m04_axi_araddr             <= LFAAaddr4_tx(31 downto 6) & "000000";
                   m04_axi_arlen              <= std_logic_vector(num_tx_64B_axi_beats_next_4G);
                   if (m04_axi_arready = '1') then
                      m04_axi_arvalid         <= '0';
                      m04_axi_araddr          <= (others=>'0');
                      m04_axi_arlen           <= (others=>'0');
                      if num_tx_residual_axi_trans_len_next_4G /= 0 then
                         output_fsm           <= generate_ar4_residual
                      else
                         output_fsm           <= idle;
                      end if;
                      trans_pkt_counter       <= trans_pkt_counter + 1;
                      direct_ar4              <= '0';
                      num_tx_bytes_curr_4G    <= (others=>'0');
                      num_tx_bytes_next_4G    <= (others=>'0');
                      LFAAaddr4_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 6)) + resize(num_tx_64B_axi_beats_next_4G,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G = 0 and num_tx_64B_axi_beats_next_4G = 0) then
                   direct_ar4                 <= '0';
                   num_tx_bytes_curr_4G       <= (others=>'0');
                   num_tx_bytes_next_4G       <= (others=>'0');
                   if num_tx_residual_axi_trans_len_next_4G /= 0 then
                     output_fsm               <= generate_ar4_residual
                   else
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
                   end if;
                elsif (num_tx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m04_axi_arvalid            <= '1';
                   m04_axi_araddr             <= LFAAaddr4_tx(31 downto 12) & "000000000000";
                   m04_axi_arlen              <= "00111111";
                   if (m04_axi_awready = '1') then
                      m04_axi_arvalid         <= '0';
                      m04_axi_araddr          <= (others=>'0');
                      m04_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm_next_4G <= num_tx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr4_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 12)) + 1);
		   end if;
             elsif (LFAAaddr3_tx_shadow(32) /= '1') then
                if (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats /= 0) then
                   m04_axi_arvalid           <= '1';
                   m04_axi_araddr            <= LFAAaddr4(31 downto 6) & "000000";
                   m04_axi_arlen             <= std_logic_vector(num_tx_64B_axi_beats);
                   if (m04_axi_arready = '1') then
                      m04_axi_arvalid        <= '0';
                      m04_axi_araddr         <= (others=>'0');
                      m04_axi_arlen          <= (others=>'0');
                      if num_tx_residual_axi_trans_len /= 0 then
                         output_fsm          <= generate_ar4_residual;
                      else
                         output_fsm          <= idle;
                      end if;
                      trans_pkt_counter      <= trans_pkt_counter + 1;
                      LFAAaddr4_tx(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 6)) + resize(num_tx_64B_axi_beats,27));
                   end if;
                elsif (num_tx_4k_axi_trans_fsm = 0 and num_tx_64B_axi_beats = 0) then
                   if num_tx_residual_axi_trans_len /= 0 then
                     output_fsm               <= generate_ar4_residual;
                   else
                     trans_pkt_counter        <= trans_pkt_counter + 1;
                     output_fsm               <= idle; --one transaction finished
                   end if
                elsif (num_tx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m04_axi_arvalid            <= '1';
                   m04_axi_araddr             <= LFAAaddr4_tx(31 downto 12) & "000000000000";
                   m04_axi_arlen              <= "00111111";
                   if (m04_axi_arready = '1') then
                      m04_axi_arvalid         <= '0';
                      m04_axi_araddr          <= (others=>'0');
                      m04_axi_arlen           <= (others=>'0');
                      num_tx_4k_axi_trans_fsm <= num_tx_4k_axi_trans_fsm - 1;
                      LFAAaddr4_tx(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4_tx(32 downto 12)) + 1);
                      output_fsm              <= generate_ar4_shadow_addr;
                   end if;
                end if;
             else
                m04_axi_arvalid               <= '0';
                m04_axi_araddr                <= (others=>'0');
                m04_axi_arlen                 <= (others=>'0');
                m04_axi_4G_empty              <= '1';
                output_fsm                    <= idle;
             end if;
         end case;
      end if;
    end process;
 
    --------------------------------------------------------------------------------------------
    -- Capture the memory read's of the 512bit data comming back on the AXI bus
    --------------------------------------------------------------------------------------------
    process(i_shared_clk)
    begin
      if (i_soft_reset = '1') then
         tx_fifo_din      <= (others => '0');
         tx_fifo_wr_en    <= '0';	 
      elsif rising_edge(i_shared_clk) then
         if (m01_axi_rvalid = '1') then
            tx_fifo_din   <= m01_axi_rdata;
            tx_fifo_wr_en <= '1';
         elsif (m02_axi_rvalid = '1') then
	    tx_fifo_din   <= m02_axi_rdata;
            tx_fifo_wr_en <= '1';
         elsif (m03_axi_rvalid = '1') then
            tx_fifo_din   <= m03_axi_rdata;
            tx_fifo_wr_en <= '1';
         elsif (m04_axi_rvalid = '1') then
            tx_fifo_din   <= m04_axi_rdata;
            tx_fifo_wr_en <= '1';
         else
            tx_fifo_din   <= (others => '0');		 
            tx_fifo_wr_en <= '0'; 		 
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if i_soft_reset = '1' then
   	 tx_fifo_rd_en  <= '0';     
      elsif rising_edge(i_shared_clk) then
         if output_fsm = generate_ar1 or output_fsm = generate_ar1_residual or 
	    output_fsm = generate_ar2 or output_fsm = generate_ar2_residual or 
	    output_fsm = generate_ar3 or output_fsm = generate_ar3_residual or 
	    output_fsm = generate_ar4 or output_fsm = generate_ar4_residual then
            tx_fifo_rd_en  <= (not tx_fifo_empty);
	 else
            tx_fifo_rd_en  <= '0';
         end if;
      end if;
    end process;      


    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if output_fsm = generate_ar1 or output_fsm = generate_ar1_residual then
            if i_packetiser_data_to_player_rdy = '1' then 
               m01_axi_rready <= '1';
            else
               m01_axi_rready <= '0';
	    end if;
	 end if;
       end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if output_fsm = generate_ar2 or output_fsm = generate_ar2_residual then
            if i_packetiser_data_to_player_rdy = '1' then
               m02_axi_rready <= '1';
            else
               m02_axi_rready <= '0';
            end if;
         end if;
       end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if output_fsm = generate_ar3 or output_fsm = generate_ar3_residual then
            if i_packetiser_data_to_player_rdy = '1' then
               m03_axi_rready <= '1';
            else
               m03_axi_rready <= '0';
            end if;
         end if;
       end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if output_fsm = generate_ar4 or output_fsm = generate_ar4_residual then
            if i_packetiser_data_to_player_rdy = '1' then
               m04_axi_rready <= '1';
            else
               m04_axi_rready <= '0';
            end if;
         end if;
       end if;
    end process;

    fifo_rdata_inst : xpm_fifo_sync
    generic map (
        DOUT_RESET_VALUE    => "0",
        ECC_MODE            => "no_ecc",
        FIFO_MEMORY_TYPE    => "auto",
        FIFO_READ_LATENCY   => 0,
        FIFO_WRITE_DEPTH    => 4096,
        FULL_RESET_VALUE    => 0,
        PROG_EMPTY_THRESH   => 10,
        PROG_FULL_THRESH    => 10,
        RD_DATA_COUNT_WIDTH => 13,
        READ_DATA_WIDTH     => 512,
        READ_MODE           => "fwft",
        SIM_ASSERT_CHK      => 0,
        USE_ADV_FEATURES    => "1404",
        WAKEUP_TIME         => 0,
        WRITE_DATA_WIDTH    => 512,
        WR_DATA_COUNT_WIDTH => 13
    )
    port map (
        almost_empty  => open,
        almost_full   => open,
        data_valid    => o_packetiser_data_in_wr,
        dbiterr       => open,
        dout          => o_packetiser_data,
        empty         => tx_fifo_empty,
        full          => open,
        overflow      => open,
        prog_empty    => open,
        prog_full     => open,
        rd_data_count => open,
        rd_rst_busy   => open,
        sbiterr       => open,
        underflow     => open,
        wr_ack        => open,
        wr_data_count => open,
        wr_rst_busy   => open,
        din           => tx_fifo_din,
        injectdbiterr => '0',
        injectsbiterr => '0',
        rd_en         => tx_fifo_rd_en,
        rst           => fifo_rst,
        sleep         => '0',
        wr_clk        => i_shared_clk,
        wr_en         => tx_fifo_wr_en
    );


end RTL;
