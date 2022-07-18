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
        g_DEBUG_ILAs             : BOOLEAN := FALSE;
        g_HBM_bank_size          : string  := "4095MB"
    );
    Port(
        clk_freerun                     : in std_logic;
        -- shared memory interface clock (300 MHz)
        i_shared_clk                    : in std_logic;
        i_shared_rst                    : in std_logic;

        o_reset_packet_player           : out std_logic;
        ------------------------------------------------------------------------------------
        -- Data from CMAC module after CDC in shared memory clock domain
        i_data_from_cmac                : in  std_logic_vector(511 downto 0);
        i_data_valid_from_cmac          : in  std_logic;

        ------------------------------------------------------------------------------------
        -- config and status registers interface
        -- rx
    	i_rx_packet_size                : in  std_logic_vector(13 downto 0);
        i_rx_soft_reset                 : in  std_logic;
        i_enable_capture                : in  std_logic;

        o_1st_4GB_rx_addr               : out std_logic_vector(31 downto 0);
        o_2nd_4GB_rx_addr               : out std_logic_vector(31 downto 0);
        o_3rd_4GB_rx_addr               : out std_logic_vector(31 downto 0);
        o_4th_4GB_rx_addr               : out std_logic_vector(31 downto 0);

        o_capture_done                  : out std_logic;
        o_num_packets_received          : out std_logic_vector(31 downto 0);

        -- tx
        i_tx_packet_size                : in  std_logic_vector(13 downto 0);
        i_start_tx                      : in  std_logic;
      
        i_loop_tx                         : in std_logic; 
        i_expected_total_number_of_4k_axi : in std_logic_vector(31 downto 0);
        i_expected_number_beats_per_burst : in std_logic_vector(12 downto 0);
        i_expected_beats_per_packet       : in std_logic_vector(31 downto 0);
        i_expected_packets_per_burst      : in std_logic_vector(31 downto 0);
	i_expected_total_number_of_bursts : in std_logic_vector(31 downto 0);
        i_expected_number_of_loops        : in std_logic_vector(31 downto 0);
        i_time_between_bursts_ns          : in std_logic_vector(31 downto 0);

        o_tx_addr                         : out std_logic_vector(31 downto 0);
        o_tx_boundary_across_num          : out std_logic_vector(1  downto 0);
	o_axi_rvalid_but_fifo_full        : out std_logic;
	------------------------------------------------------------------------------------
        -- Data output, to the packetizer
        -- Add the packetizer records here
        o_packetiser_data_in_wr         : out std_logic;
        o_packetiser_data               : out std_logic_vector(511 downto 0);
        o_packetiser_bytes_to_transmit  : out std_logic_vector(13 downto 0);
        i_packetiser_data_to_player_rdy : in  std_logic;

        -----------------------------------------------------------------------
        i_schedule_action   : in std_logic_vector(7 downto 0);
        -----------------------------------------------------------------------

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
   
    constant max_space        : unsigned(31 downto 0) := X"FFFFFFFF";
    constant max_space_4095MB     : unsigned(31 downto 0) := X"FFF00000";

    COMPONENT ila_0
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
    END COMPONENT;

    signal num_rx_64B_axi_beats,    num_rx_64B_axi_beats_curr_4G,    num_rx_64B_axi_beats_next_4G          : unsigned(7 downto 0);
    signal num_rx_4k_axi_trans,     num_rx_4k_axi_trans_curr_4G,     num_rx_4k_axi_trans_next_4G           : unsigned(1 downto 0);
    signal num_rx_4k_axi_trans_fsm, num_rx_4k_axi_trans_fsm_curr_4G, num_rx_4k_axi_trans_fsm_next_4G       : unsigned(1 downto 0) := "00";

    signal num_rx_bytes_curr_4G, num_rx_bytes_next_4G : unsigned(13 downto 0) := (others=>'0');

    signal i_data_valid_del, i_valid_rising : std_logic; 
    signal m01_axi_4G_full,  m02_axi_4G_full,  m03_axi_4G_full,  m04_axi_4G_full  : std_logic := '0'; 
    signal LFAAaddr1,        LFAAaddr2,        LFAAaddr3,        LFAAaddr4        : std_logic_vector(32 downto 0) := (others=>'0');
    signal LFAAaddr1_shadow, LFAAaddr2_shadow, LFAAaddr3_shadow, LFAAaddr4_shadow : std_logic_vector(32 downto 0) := (others=>'0');

    type   input_fsm_type is(idle, generate_aw1_shadow_addr, check_aw1_addr_range, generate_aw1,
                                   generate_aw2_shadow_addr, check_aw2_addr_range, generate_aw2,
				   generate_aw3_shadow_addr, check_aw3_addr_range, generate_aw3,
				   generate_aw4_shadow_addr, check_aw4_addr_range, generate_aw4);
    signal input_fsm : input_fsm_type;				   
    signal direct_aw2, direct_aw3, direct_aw4 : std_logic := '0';
    signal four_kB_trans, beats_64B_trans : std_logic := '0';
    signal recv_pkt_counter : unsigned(31 downto 0) := (others=>'0');

    signal m01_fifo_rd_en, m02_fifo_rd_en, m03_fifo_rd_en, m04_fifo_rd_en  : std_logic := '0';
    signal fifo_wr_en, fifo_rd_en, fifo_rd_wready, tx_fifo_rst, rx_fifo_rst: std_logic;  
    signal fifo_rd_counter                                                 : unsigned(5 downto 0) := "000000";
    signal axi_wlast, axi_wready                                           : std_logic := '0'; 
    signal axi_wvalid, axi_wvalid_falling                                  : std_logic; 
    signal axi_wvalid_del                                                  : std_logic := '0';  
    signal axi_wdata                                                       : std_logic_vector(511 downto 0);
    
    signal wr_bank1_boundary_corss,              wr_bank2_boundary_corss              : std_logic;
    signal wr_bank3_boundary_corss,              wr_bank4_boundary_corss              : std_logic;
    signal wr_bank1_boundary_corss_curr_4G_size, wr_bank2_boundary_corss_curr_4G_size : unsigned(13 downto 0); 
    signal wr_bank3_boundary_corss_curr_4G_size, wr_bank4_boundary_corss_curr_4G_size : unsigned(13 downto 0); 

    -----------------
    --TX registers
    -----------------

    -- NEEDS TO BE AT LEAST 4K deep to handle the HBM requests when there is slow playout on the 100G.
    constant SYNC_FIFO_DEPTH : integer := 4096;

    signal o_axi_arvalid :  std_logic;
    signal i_axi_arready :  std_logic;
    signal o_axi_araddr  :  std_logic_vector(31 downto 0);
    signal o_axi_arlen   :  std_logic_vector(7 downto 0);

    signal i_axi_rvalid  :  std_logic;
    signal o_axi_rready  :  std_logic;
    signal i_axi_rdata   :  std_logic_vector(511 downto 0);
    signal i_axi_rlast   :  std_logic;
    signal i_axi_rresp   :  std_logic_vector(1 downto 0);
    
    signal running : std_logic := '0';
    signal tx_complete : std_logic := '0';
    signal axi_4k_finished : std_logic := '0';
    type rd_fsm_type is (idle, wait_fifo_reset, wait_arready, rd_4064b, wait_fifo ,finished, loopit);
    signal rd_fsm : rd_fsm_type := idle;
    type output_fsm_type is (initial_state, output_first_run0, output_first_run1 ,output_first_idle, output_idle, output_next_burst, output_next_packet, output_wait_burst_counter, read_full_packet, output_packet_finished, output_tx_complete, output_loopit, output_thats_all_folks);
    signal output_fsm       : output_fsm_type := initial_state;
    signal packetizer_wr    : std_logic;
    signal packetizer_dout  :  std_logic_vector(511 downto 0);
    
    signal readaddr         : unsigned(31 downto 0);    -- 30 bits = 1GB, 33 bits = 8GB
    
    signal total_beat_count   :  unsigned(31 downto 0) := (others => '0');
    signal current_axi_4k_count   :  unsigned(31 downto 0);
    signal wait_counter     :  unsigned(7 downto 0);
    signal current_pkt_count : unsigned(63 downto 0) := (others=>'0');
    signal fpga_beat_in_burst_counter : unsigned(31 downto 0) := (others=>'0');
    
    signal fpga_axi_beats_per_packet : unsigned(7 downto 0) := (others=>'0');
    signal beats : unsigned(7 downto 0);
    signal number_of_burst_beats : unsigned(15 downto 0) := (others=>'0');
    signal total_number_of_512b : unsigned(31 downto 0) := (others=>'0');
    signal beat_count : unsigned(31 downto 0) := (others=> '0');
    signal end_of_packet : std_logic;
    signal start_of_packet : std_logic;
    signal start_stop_tx : std_logic;
    signal wait_fifo_resetting : std_logic;
    signal error_fifo_stall : std_logic;

    signal FIFO_dout : std_logic_vector(511 downto 0);     
    signal FIFO_empty : std_logic; 
    signal FIFO_full : std_logic;      
    signal FIFO_prog_full, FIFO_almost_full : std_logic;      
    signal FIFO_RdDataCount : std_logic_vector(((ceil_log2(SYNC_FIFO_DEPTH))) downto 0);
    signal FIFO_WrDataCount : std_logic_vector(((ceil_log2(SYNC_FIFO_DEPTH))) downto 0);
    signal FIFO_din : std_logic_vector(511 downto 0);      
    signal tx_FIFO_rd_en : std_logic;  
    signal FIFO_rst : std_logic;       
    signal tx_FIFO_wr_en : std_logic;     
    signal reset_state : std_logic;
    signal ns_burst_timer_std_logic, ns_total_time_std_logic : std_logic_vector(31 downto 0) := (others=>'0');
    signal ns_burst_timer_100Mhz : unsigned(31 downto 0) := (others=>'0');
    signal ns_total_time_100Mhz : unsigned(47 downto 0) := (others=>'0');

    signal target_time_100Mhz, target_time : unsigned(47 downto 0) := (others=>'0');
    signal target_packets_100Mhz, target_packets : unsigned(63 downto 0) := (others=>'0');
    signal target_packets_std_logic : std_logic_vector(63 downto 0) := (others=>'0');

    signal time_between_bursts_ns_100Mhz : std_logic_vector(31 downto 0) := (others=>'0');

    signal run_timing, run_timing_100Mhz : std_logic;

    signal reset_state_100Mhz : std_logic;
    signal start_next_burst : std_logic;
    signal start_next_burst_latched : std_logic;
    signal clear_start_next_burst_latched : std_logic;
    signal start_next_burst_100Mhz : std_logic;
    signal fpga_pkt_count_in_this_burst : unsigned(31 downto 0);
    signal burst_count: unsigned(31 downto 0) := (others=>'0');
    signal reset_ns_burst_timer : std_logic;
    signal looping : std_logic := '0';
    signal loop_cnt: unsigned(31 downto 0) := (others=>'0');
    signal start_next_loop : std_logic := '0';
    signal wait_fifo_reset_cnt: unsigned(31 downto 0) := (others=>'0');
    signal rd_rst_busy ,wr_rst_busy : std_logic := '0';

    signal rd_fsm_debug : std_logic_vector(3 downto 0);
    signal output_fsm_debug : std_logic_vector(3 downto 0);

    signal total_pkts_to_mac : unsigned(63 downto 0) := (others=>'0');
    signal reset_cnt : unsigned(3 downto 0);


    signal first_time, compare_vectors, vectors_equal, vectors_not_equal, o_packetiser_data_in_wr_prev : std_logic;
    signal first_packet_golden_data : std_logic_vector(511 downto 0); 
    signal boundary_across_num : unsigned(1 downto 0) := "00";

begin

    o_1st_4GB_rx_addr <= LFAAaddr1(31 downto 0);
    o_2nd_4GB_rx_addr <= LFAAaddr2(31 downto 0);
    o_3rd_4GB_rx_addr <= LFAAaddr3(31 downto 0);
    o_4th_4GB_rx_addr <= LFAAaddr4(31 downto 0);

    o_capture_done            <= m04_axi_4G_full;
    o_num_packets_received    <= std_logic_vector(recv_pkt_counter);

    o_tx_addr                 <= std_logic_vector(readaddr);
    o_tx_boundary_across_num  <= std_logic_vector(boundary_across_num);
    ---------------------------------------------------------------------------------------------------
    --HBM AXI write transaction part, it is assumed that the recevied packet is always multiple of 64B,
    --i.e no residual AXI trans where less then 64B trans is needed, all the bits of imcoming data is 
    --    valid
    ---------------------------------------------------------------------------------------------------
    num_rx_64B_axi_beats          <= unsigned(i_rx_packet_size(13 downto 6)); -- 64 bytes multiple beat transaction
    num_rx_4k_axi_trans           <= "10" when (unsigned(i_rx_packet_size(13 downto 0)) > 8192) else
	   			     "01" when (unsigned(i_rx_packet_size(13 downto 0)) > 4096) else
				     "00";

    --first part of split AXI transaction at the 4GB boundary, fit to the current 4GB section 
    num_rx_64B_axi_beats_curr_4G           <= num_rx_bytes_curr_4G(13 downto 6);
    num_rx_4k_axi_trans_curr_4G            <= "10" when num_rx_bytes_curr_4G > 8192 else
                                              "01" when num_rx_bytes_curr_4G > 4096 else
                                              "00";

    --second part of split AXI transaction at the 4GB boundary, fit to the next 4GB section
    num_rx_64B_axi_beats_next_4G           <= num_rx_bytes_next_4G(13 downto 6);
    num_rx_4k_axi_trans_next_4G            <= "10" when num_rx_bytes_next_4G > 8192 else
                                              "01" when num_rx_bytes_next_4G > 4096 else
                                              "00";

    --HBM bank boundary cross condition logic, due to the fact that XRT cannot allocate 4GB size of HBM buffer, so
    --need to support the size of HBM bank to be any size, currently 4095MB is by default, and still 4096MB is second
    --choice
    g_4095MB_condition : if g_HBM_bank_size="4095MB" generate
      wr_bank1_boundary_corss                 <= '1' when (LFAAaddr1_shadow(31 downto 16) = X"FFF0") else '0';
      wr_bank2_boundary_corss		      <= '1' when (LFAAaddr2_shadow(31 downto 16) = X"FFF0") else '0';
      wr_bank3_boundary_corss                 <= '1' when (LFAAaddr3_shadow(31 downto 16) = X"FFF0") else '0';
      wr_bank4_boundary_corss                 <= '1' when (LFAAaddr4_shadow(31 downto 16) = X"FFF0") else '0'; 
      wr_bank1_boundary_corss_curr_4G_size    <= resize((max_space_4095MB - unsigned(LFAAaddr1(31 downto 0))), 14);
      wr_bank2_boundary_corss_curr_4G_size    <= resize((max_space_4095MB - unsigned(LFAAaddr2(31 downto 0))), 14);
      wr_bank3_boundary_corss_curr_4G_size    <= resize((max_space_4095MB - unsigned(LFAAaddr3(31 downto 0))), 14);
      wr_bank4_boundary_corss_curr_4G_size    <= resize((max_space_4095MB - unsigned(LFAAaddr4(31 downto 0))), 14);
    end generate g_4095MB_condition;					      

    g_4096MB_condition : if g_HBM_bank_size/="4095MB" generate
      wr_bank1_boundary_corss                 <= '1' when LFAAaddr1_shadow(32)='1' else '0';
      wr_bank2_boundary_corss                 <= '1' when LFAAaddr2_shadow(32)='1' else '0';
      wr_bank3_boundary_corss                 <= '1' when LFAAaddr3_shadow(32)='1' else '0';
      wr_bank4_boundary_corss                 <= '1' when LFAAaddr4_shadow(32)='1' else '0';
      wr_bank1_boundary_corss_curr_4G_size    <= resize((max_space - unsigned(LFAAaddr1(31 downto 0))), 14);
      wr_bank2_boundary_corss_curr_4G_size    <= resize((max_space - unsigned(LFAAaddr2(31 downto 0))), 14);
      wr_bank3_boundary_corss_curr_4G_size    <= resize((max_space - unsigned(LFAAaddr3(31 downto 0))), 14);
      wr_bank4_boundary_corss_curr_4G_size    <= resize((max_space - unsigned(LFAAaddr4(31 downto 0))), 14);
    end generate g_4096MB_condition;

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
      if rising_edge(i_shared_clk) then
         if i_rx_soft_reset = '1' then
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
            num_rx_4k_axi_trans_fsm         <= "00";
            num_rx_4k_axi_trans_fsm_curr_4G <= "00";
            num_rx_4k_axi_trans_fsm_next_4G <= "00";
            num_rx_bytes_curr_4G            <= (others => '0');
            num_rx_bytes_next_4G            <= (others => '0');
            m01_axi_4G_full  <= '0';
            m02_axi_4G_full  <= '0';
            m03_axi_4G_full  <= '0';
            m04_axi_4G_full  <= '0';
            direct_aw2       <= '0';
            direct_aw3       <= '0';
            direct_aw4       <= '0';
            four_kB_trans    <= '0';
            beats_64B_trans  <= '0';
            LFAAaddr1        <= (others => '0');
            LFAAaddr2        <= (others => '0');
            LFAAaddr3        <= (others => '0');
            LFAAaddr4        <= (others => '0');
            LFAAaddr1_shadow <= (others => '0');
            LFAAaddr2_shadow <= (others => '0');
            LFAAaddr3_shadow <= (others => '0');
            LFAAaddr4_shadow <= (others => '0');
            recv_pkt_counter <= (others => '0');
	 else 
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
	     elsif i_valid_rising = '1' and i_enable_capture = '1' then
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
             if (wr_bank1_boundary_corss = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
		num_rx_bytes_curr_4G         <= wr_bank1_boundary_corss_curr_4G_size;
		num_rx_bytes_next_4G         <= unsigned(LFAAaddr1_shadow(13 downto 0));    
	     else
                num_rx_bytes_curr_4G         <= (others=>'0');
		num_rx_bytes_next_4G         <= (others=>'0');
             end if;
	     num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
	     num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G;
	     input_fsm                       <= generate_aw1;
           when generate_aw1 =>
             if (wr_bank1_boundary_corss = '0') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then  
                   m01_axi_awvalid           <= '1';
                   m01_axi_awaddr            <= LFAAaddr1(31 downto 6) & "000000";
                   m01_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m01_axi_awready = '1') then
		      four_kB_trans               <= '0';
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
		      four_kB_trans                <= '1';
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
	             four_kB_trans                 <= '0';
                     beats_64B_trans          <= '1';
		     m01_axi_awvalid          <= '0';
                     m01_axi_awaddr           <= (others=>'0');
                     m01_axi_awlen            <= (others=>'0');
                     input_fsm                <= idle;
		     m01_axi_4G_full          <= '1';
		     LFAAaddr1(32 downto 0)   <= (others=>'1');
                  end if;
               elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
	             m01_axi_4G_full          <= '1';		  
                     input_fsm                <= idle; --one transaction finished
               elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                  m01_axi_awvalid             <= '1';
                  m01_axi_awaddr              <= LFAAaddr1(31 downto 12) & "000000000000";
                  m01_axi_awlen               <= "00111111";
                  if (m01_axi_awready = '1') then
	             four_kB_trans                 <= '1';
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
             if (wr_bank2_boundary_corss = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= wr_bank2_boundary_corss_curr_4G_size; 
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr2_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= (others=>'0');
                num_rx_bytes_next_4G         <= (others=>'0');		
	     end if;
	     num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
	     num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G;
             input_fsm                       <= generate_aw2;
           when generate_aw2 =>
             if (direct_aw2 = '1') then
		if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then     
                   m02_axi_awvalid           <= '1';
		   m02_axi_awaddr            <= LFAAaddr2(31 downto 6) & "000000";
                   m02_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m02_axi_awready = '1') then
		      four_kB_trans               <= '0';
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
		      four_kB_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m02_axi_awvalid         <= '0';
                      m02_axi_awaddr          <= (others=>'0');
                      m02_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr2(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 12)) + 1);
                   end if;
                end if; 
             elsif (wr_bank2_boundary_corss = '0') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m02_axi_awvalid           <= '1';
                   m02_axi_awaddr            <= LFAAaddr2(31 downto 6) & "000000";
                   m02_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m02_axi_awready = '1') then
		      four_kB_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m01_axi_awvalid         <= '0';
                      m01_axi_awaddr          <= (others=>'0');
                      m01_axi_awlen           <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr2(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr2(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
		      recv_pkt_counter        <= recv_pkt_counter + 1;	   
                      input_fsm               <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m02_axi_awvalid            <= '1';
                   m02_axi_awaddr             <= LFAAaddr2(31 downto 12) & "000000000000";
                   m02_axi_awlen              <= "00111111";
                   if (m01_axi_awready = '1') then
		      four_kB_trans                <= '1';
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
		     four_kB_trans          <= '0';
                     beats_64B_trans        <= '1';
		     m02_axi_awvalid        <= '0';
                     m02_axi_awaddr         <= (others=>'0');
                     m02_axi_awlen          <= (others=>'0');
                     input_fsm              <= idle;
		     m02_axi_4G_full        <= '1';
                     LFAAaddr2(32 downto 0) <= (others=>'1');
                  end if;
               elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
	             m02_axi_4G_full        <= '1';		  
                     input_fsm              <= idle; --one transaction finished
               elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                  m02_axi_awvalid            <= '1';
                  m02_axi_awaddr             <= LFAAaddr2(31 downto 12) & "000000000000";
                  m02_axi_awlen              <= "00111111";
                  if (m02_axi_awready = '1') then
		     four_kB_trans                <= '1';
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
             if (wr_bank3_boundary_corss = '1') then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= wr_bank2_boundary_corss_curr_4G_size; 
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr3_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= (others=>'0');
                num_rx_bytes_next_4G         <= (others=>'0');
             end if;
             num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
             num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G;
             input_fsm                       <= generate_aw3;
           when generate_aw3 =>
             if (direct_aw3 = '1') then
                if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then
                   m03_axi_awvalid           <= '1';
                   m03_axi_awaddr            <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m03_axi_awready = '1') then
	              four_kB_trans               <= '0';
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
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G = 0) then
                      direct_aw3              <= '0';
                      num_rx_bytes_curr_4G    <= (others=>'0');
                      num_rx_bytes_next_4G    <= (others=>'0');
		      recv_pkt_counter        <= recv_pkt_counter + 1;
                      input_fsm               <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm_next_4G > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
		      four_kB_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr3(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (wr_bank3_boundary_corss = '0') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m03_axi_awvalid           <= '1';
                   m03_axi_awaddr            <= LFAAaddr3(31 downto 6) & "000000";
                   m03_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m03_axi_awready = '1') then
	              four_kB_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m03_axi_awvalid        <= '0';
                      m03_axi_awaddr         <= (others=>'0');
                      m03_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr3(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr3(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
		   recv_pkt_counter          <= recv_pkt_counter + 1;	   
                   input_fsm                 <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
		      four_kB_trans                <= '1';
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
		      four_kB_trans           <= '0';
                      beats_64B_trans         <= '1';
		      m03_axi_awvalid         <= '0';
                      m03_axi_awaddr          <= (others=>'0');
                      m03_axi_awlen           <= (others=>'0');
                      input_fsm               <= idle;
                      m03_axi_4G_full         <= '1';
                      LFAAaddr3(32 downto 0)  <= (others=>'1');
                   end if;
                elsif (num_rx_4k_axi_trans_fsm_curr_4G = 0 and num_rx_64B_axi_beats_curr_4G = 0) then
                      m03_axi_4G_full        <= '1';
                      input_fsm              <= idle; --one transaction finished
                elsif (num_rx_4k_axi_trans_fsm_curr_4G > 0) then
                   m03_axi_awvalid            <= '1';
                   m03_axi_awaddr             <= LFAAaddr3(31 downto 12) & "000000000000";
                   m03_axi_awlen              <= "00111111";
                   if (m03_axi_awready = '1') then
	              four_kB_trans                <= '1';
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
             if (wr_bank4_boundary_corss) then --first 4GB AXI section is filled to full, need to split the next AXI transaction to two part, 
                num_rx_bytes_curr_4G         <= wr_bank4_boundary_corss_curr_4G_size;
                num_rx_bytes_next_4G         <= unsigned(LFAAaddr4_shadow(13 downto 0));
             else
                num_rx_bytes_curr_4G         <= (others=>'0');
                num_rx_bytes_next_4G         <= (others=>'0');
             end if;
             num_rx_4k_axi_trans_fsm_curr_4G <= num_rx_4k_axi_trans_curr_4G;
             num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_next_4G;
             input_fsm <= generate_aw4;
           when generate_aw4 =>
             if (direct_aw4 = '1') then
                if (num_rx_4k_axi_trans_fsm_next_4G = 0 and num_rx_64B_axi_beats_next_4G /= 0) then
                   m04_axi_awvalid           <= '1';
                   m04_axi_awaddr            <= LFAAaddr4(31 downto 6) & "000000";
                   m04_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats_next_4G);
                   if (m04_axi_awready = '1') then
		      four_kB_trans               <= '0';
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
	              four_kB_trans                <= '1';
                      beats_64B_trans         <= '0';
                      m04_axi_awvalid         <= '0';
                      m04_axi_awaddr          <= (others=>'0');
                      m04_axi_awlen           <= (others=>'0');
                      num_rx_4k_axi_trans_fsm_next_4G <= num_rx_4k_axi_trans_fsm_next_4G - 1;
                      LFAAaddr4(32 downto 12) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 12)) + 1);
                   end if;
                end if;
             elsif (wr_bank4_boundary_corss = '0') then
                if (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats /= 0) then
                   m04_axi_awvalid           <= '1';
                   m04_axi_awaddr            <= LFAAaddr4(31 downto 6) & "000000";
                   m04_axi_awlen             <= std_logic_vector(num_rx_64B_axi_beats);
                   if (m04_axi_awready = '1') then
	              four_kB_trans               <= '0';
                      beats_64B_trans        <= '1';
		      m04_axi_awvalid        <= '0';
                      m04_axi_awaddr         <= (others=>'0');
                      m04_axi_awlen          <= (others=>'0');
                      input_fsm              <= idle;
		      recv_pkt_counter       <= recv_pkt_counter + 1;
                      LFAAaddr4(32 downto 6) <= std_logic_vector(unsigned(LFAAaddr4(32 downto 6)) + resize(num_rx_64B_axi_beats,27));
                   end if;
                elsif (num_rx_4k_axi_trans_fsm = 0 and num_rx_64B_axi_beats = 0) then
                      input_fsm               <= idle; --one transaction finished
		      recv_pkt_counter        <= recv_pkt_counter + 1;
                elsif (num_rx_4k_axi_trans_fsm > 0) then --start 4K transaction first, if packet size is more than 4K
                   m04_axi_awvalid            <= '1';
                   m04_axi_awaddr             <= LFAAaddr4(31 downto 12) & "000000000000";
                   m04_axi_awlen              <= "00111111";
                   if (m04_axi_awready = '1') then
		      four_kB_trans                <= '1';
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
      end if;
    end process;

    --MUX to select between m01 m02 m03 m04 AXI buses    
    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then
            m01_axi_wvalid <= '0';
            m01_axi_wdata  <= (others => '0');
            m01_axi_wstrb  <= (others => '1');
            m01_axi_wlast  <= '0';
            m02_axi_wvalid <= '0';
            m02_axi_wdata  <= (others => '0');
            m02_axi_wstrb  <= (others => '1');
            m02_axi_wlast  <= '0';
            m03_axi_wvalid <= '0';
            m03_axi_wdata  <= (others => '0');
            m03_axi_wstrb  <= (others => '1');
            m03_axi_wlast  <= '0';
            m04_axi_wvalid <= '0';
            m04_axi_wdata  <= (others => '0');
            m04_axi_wstrb  <= (others => '1');
            m04_axi_wlast  <= '0';
            axi_wready     <= '0';
         else
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
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then
            m01_fifo_rd_en  <= '0';
         else
	   if (m01_axi_awvalid = '1' and m01_axi_awready = '1') then
              m01_fifo_rd_en  <= '1';
           elsif axi_wvalid_falling = '1' then
	      m01_fifo_rd_en  <= '0';  	 
	   end if;
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then    
            m02_fifo_rd_en  <= '0';
         else	    
            if (m02_axi_awvalid = '1' and m02_axi_awready = '1') then
               m02_fifo_rd_en  <= '1';
            elsif axi_wvalid_falling = '1' then
               m02_fifo_rd_en  <= '0';
            end if;
	 end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then     
	    m03_fifo_rd_en  <= '0';
         else   
            if (m03_axi_awvalid = '1' and m03_axi_awready = '1') then
               m03_fifo_rd_en  <= '1';
            elsif axi_wvalid_falling = '1' then
               m03_fifo_rd_en  <= '0';
	    end if;
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then
            m04_fifo_rd_en  <= '0';
	 else
            if (m04_axi_awvalid = '1' and m04_axi_awready = '1') then
               m04_fifo_rd_en  <= '1';
            elsif axi_wvalid_falling = '1' then --when one packet reading from fifo is finished
               m04_fifo_rd_en  <= '0';
            end if;
	 end if;
      end if;
    end process;

 fifo_wr_en <= i_data_valid_from_cmac and i_enable_capture; 
 fifo_rd_en <= (m01_fifo_rd_en and m01_axi_wready) or (m02_fifo_rd_en and m02_axi_wready) or (m03_fifo_rd_en and m03_axi_wready) or (m04_fifo_rd_en and m04_axi_wready);
 fifo_rd_wready <= m01_axi_wready or m02_axi_wready or m03_axi_wready or m04_axi_wready; 
 rx_fifo_rst    <= i_rx_soft_reset or i_shared_rst; 

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
	 if i_rx_soft_reset = '1' then
            fifo_rd_counter <= (others=>'0');
            axi_wlast        <= '0';
         else
	   if (four_kB_trans          = '1' and fifo_rd_counter = 63) or 
	      (beats_64B_trans        = '1' and (fifo_rd_counter = num_rx_64B_axi_beats-1          or 
	                                         fifo_rd_counter = num_rx_64B_axi_beats_curr_4G-1  or 
	                                         fifo_rd_counter = num_rx_64B_axi_beats_next_4G-1)) then
              fifo_rd_counter <= (others=>'0');
              axi_wlast        <= '1';			       
	   elsif fifo_rd_en = '1' then 
              fifo_rd_counter <= fifo_rd_counter + 1;
	      axi_wlast        <= '0';
           elsif fifo_rd_wready = '1' then
	      axi_wlast        <= '0';
	   end if;
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
        rst           => rx_fifo_rst, 
        sleep         => '0', 
        wr_clk        => i_shared_clk,   
        wr_en         => fifo_wr_en 
    );

    --////////////////////////////////////////////////////////////////////////////////////////////////////
    ------------------------------------------------------------------------------------------------------
    --HBM AXI read transaction part
    ------------------------------------------------------------------------------------------------------
    --////////////////////////////////////////////////////////////////////////////////////////////////////
    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         start_stop_tx <= i_start_tx OR i_schedule_action(1);
         reset_state <= '0';
         if (start_stop_tx = '1') then
            running <= '1';
            reset_state <= '0';
         else
            reset_state <= '1';
            running <= '0';
         end if;
      end if;
    end process;

    -- ar bus - read address
    m01_axi_arvalid   <= o_axi_arvalid   when boundary_across_num = 0 else '0';
    i_axi_arready     <= m01_axi_arready when boundary_across_num = 0 else '0';
    m01_axi_araddr    <= o_axi_araddr    when boundary_across_num = 0 else (others => '0');
    m01_axi_arlen     <= o_axi_arlen     when boundary_across_num = 0 else (others => '0');
    -- r bus - read data
    i_axi_rvalid      <= m01_axi_rvalid  when boundary_across_num = 0 else '0';
    m01_axi_rready    <= o_axi_rready    when boundary_across_num = 0 else '0';
    i_axi_rdata       <= m01_axi_rdata   when boundary_across_num = 0 else (others => '0');
    i_axi_rlast       <= m01_axi_rlast   when boundary_across_num = 0 else '0';
    i_axi_rresp       <= m01_axi_rresp   when boundary_across_num = 0 else (others => '0');

    -- ar bus - read address
    m02_axi_arvalid   <= o_axi_arvalid   when boundary_across_num = 1 else '0';
    i_axi_arready     <= m02_axi_arready when boundary_across_num = 1 else '0';
    m02_axi_araddr    <= o_axi_araddr    when boundary_across_num = 1 else (others => '0');
    m02_axi_arlen     <= o_axi_arlen     when boundary_across_num = 1 else (others => '0');
    -- r bus - read data
    i_axi_rvalid      <= m02_axi_rvalid  when boundary_across_num = 1 else '0';
    m02_axi_rready    <= o_axi_rready    when boundary_across_num = 1 else '0';
    i_axi_rdata       <= m02_axi_rdata   when boundary_across_num = 1 else (others => '0');
    i_axi_rlast       <= m02_axi_rlast   when boundary_across_num = 1 else '0';
    i_axi_rresp       <= m02_axi_rresp   when boundary_across_num = 1 else (others => '0');

    -- ar bus - read address
    m03_axi_arvalid   <= o_axi_arvalid   when boundary_across_num = 2 else '0';
    i_axi_arready     <= m03_axi_arready when boundary_across_num = 2 else '0';
    m03_axi_araddr    <= o_axi_araddr    when boundary_across_num = 2 else (others => '0');
    m03_axi_arlen     <= o_axi_arlen     when boundary_across_num = 2 else (others => '0');
    -- r bus - read data
    i_axi_rvalid      <= m03_axi_rvalid  when boundary_across_num = 2 else '0';
    m03_axi_rready    <= o_axi_rready    when boundary_across_num = 2 else '0';
    i_axi_rdata       <= m03_axi_rdata   when boundary_across_num = 2 else (others => '0');
    i_axi_rlast       <= m03_axi_rlast   when boundary_across_num = 2 else '0';
    i_axi_rresp       <= m03_axi_rresp   when boundary_across_num = 2 else (others => '0');

    -- ar bus - read address
    m04_axi_arvalid   <= o_axi_arvalid   when boundary_across_num = 3 else '0';
    i_axi_arready     <= m04_axi_arready when boundary_across_num = 3 else '0';
    m04_axi_araddr    <= o_axi_araddr    when boundary_across_num = 3 else (others => '0');
    m04_axi_arlen     <= o_axi_arlen     when boundary_across_num = 3 else (others => '0');
    -- r bus - read data
    i_axi_rvalid      <= m04_axi_rvalid  when boundary_across_num = 3 else '0';
    m04_axi_rready    <= o_axi_rready    when boundary_across_num = 3 else '0';
    i_axi_rdata       <= m04_axi_rdata   when boundary_across_num = 3 else (others => '0');
    i_axi_rlast       <= m04_axi_rlast   when boundary_across_num = 3 else '0';
    i_axi_rresp       <= m04_axi_rresp   when boundary_across_num = 3 else (others => '0');

    o_axi_rready <= '1';
    -- Read in 512 bit aligned 4k words
    o_axi_arlen(7 downto 0) <= x"3F"; -- Read 64 beats x 512 bits = 4096B 
    o_axi_araddr <= std_logic_vector(readaddr);

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         o_axi_arvalid <= '0';  
         axi_4k_finished <= '0';
         case rd_fsm is
           when idle =>
             rd_fsm_debug <= x"0";
             boundary_across_num <= (others => '0');
             readaddr <= (others =>'0');
             current_axi_4k_count <= (others =>'0');
             rd_fsm <= wait_fifo_reset;

           when wait_fifo_reset =>
             rd_fsm_debug <= x"1";
             if (start_next_loop = '1') then
                o_axi_arvalid <= '1';
                rd_fsm <= wait_arready;
             end if;

           when wait_arready =>  -- arvalid is high in this state, wait until arready is high so the transaction is complete.--o_axi_arvalid <= '0';
             rd_fsm_debug <= x"2";
             o_axi_arvalid <= '1';
             if i_axi_arready = '1' then
                o_axi_arvalid <= '0';
                readaddr <= readaddr + 4096;
                current_axi_4k_count <= current_axi_4k_count +1;
                if (current_axi_4k_count = unsigned(i_expected_total_number_of_4k_axi)) then 
                   rd_fsm <= finished; 
                else
                   rd_fsm <= wait_fifo;
                end if;
             end if;

           when wait_fifo => --issued read request on bus and now drive arvalid low
             rd_fsm_debug <= x"3";
             o_axi_arvalid <= '0';
             if (FIFO_prog_full = '1') then  -- request in lots of 64.
                rd_fsm <= wait_fifo;
             else
                rd_fsm <= wait_arready;
                o_axi_arvalid <= '1';
             end if;
	     if (readaddr = max_space_4095MB and boundary_across_num /= 3) then
		readaddr <= X"00000000";
	        boundary_across_num <= boundary_across_num + 1;
             end if;		

           when finished =>
             rd_fsm_debug <= x"4";
             if (i_loop_tx = '1') then
                rd_fsm <= loopit;
             else
                rd_fsm <= finished;
             end if;
	     if i_loop_tx = '1' then
		readaddr <= X"00000000";     
	        boundary_across_num <= (others => '0');	
             elsif (readaddr = max_space_4095MB and boundary_across_num /= 3) then
                readaddr <= X"00000000";
                boundary_across_num <= boundary_across_num + 1;
             end if;

           when loopit =>
             rd_fsm_debug <= x"5";
             axi_4k_finished <= '1';
             rd_fsm <= idle;

           when others =>
             rd_fsm <= idle;
         end case; 

         if (reset_state = '1') then
            rd_fsm <= idle;
         end if;
      end if;
    end process;
    
    --------------------------------------------------------------------------------------------
    -- Capture the memory read's of the 512bit data comming back on the AXI bus
    --------------------------------------------------------------------------------------------
    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         tx_FIFO_wr_en <= '0';
         if (i_axi_rvalid = '1') then
            if (FIFO_full = '1') then
               o_axi_rvalid_but_fifo_full <= '1'; 
            else
               FIFO_din <= i_axi_rdata;
               tx_FIFO_wr_en <= '1';
            end if;
         end if;

         if (reset_state = '1') then
            o_axi_rvalid_but_fifo_full <= '0'; 
         end if;
      end if;
    end process;

    --------------------------------------------------------------------------------------------
    -- capture the start_next_burst and make sure that it is held until the actual start of the 
    -- next burst, useful to debug using the ILA
    --------------------------------------------------------------------------------------------
    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if (start_next_burst = '1') then
            start_next_burst_latched <= '1';
         end if;
         if (clear_start_next_burst_latched = '1') then
            start_next_burst_latched <= '0';
         end if;
         if (reset_state = '1') then
            start_next_burst_latched <= '0';
         end if;
      end if;
    end process;

    --------------------------------------------------------------------------------------------
    -- Calculate the number of AXI transactions that will have had too fill the fifo per packet. 
    -- jumbo packet 9600B/64 = 150 beats
    --------------------------------------------------------------------------------------------
    beats <= unsigned(i_tx_packet_size(13 downto 6)); -- 64 bytes per beat
    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if (i_tx_packet_size(5 downto 0) = "000000") then
            fpga_axi_beats_per_packet <= beats -1; -- start counting at 0 ie 0 is 1 beat
         else
            fpga_axi_beats_per_packet <= beats;
         end if;
      end if;
    end process;

    --------------------------------------------------------------------------------------------
    -- State machine that reads whole packets out of the Fifo and presents to Packet_Player
    -- Input to the fifo comes from the data retrieved from the HBM via the AXI bus
    --------------------------------------------------------------------------------------------
    o_packetiser_data_in_wr        <= tx_FIFO_rd_en;
    o_packetiser_data              <= FIFO_dout;

    o_packetiser_bytes_to_transmit <= i_tx_packet_size(13 downto 0);

    --------------------------------------------------------------------------------------------
    -- Debug: Capture first vector sent to the MAC, so that we can compare later with the start
    -- of packet for subsequent packets and trigger on corrupt packets.
    --------------------------------------------------------------------------------------------

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         if (reset_state = '1') then
            first_time <= '1';
         else
            if (first_time = '1') then
               if (o_packetiser_data_in_wr = '1') then
                  first_time <= '0';
                  first_packet_golden_data <= o_packetiser_data;
               end if;
            end if;
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         compare_vectors <= '0';
         vectors_equal <= '0';
         vectors_not_equal <= '0';

         if (reset_state = '1') then
            o_packetiser_data_in_wr_prev <= '0';
         else
            o_packetiser_data_in_wr_prev <= o_packetiser_data_in_wr;
            if (first_time = '0') then
               if (o_packetiser_data_in_wr = '1' and o_packetiser_data_in_wr_prev = '0') then
                  compare_vectors <= '1';
                  if (first_packet_golden_data(255 downto 0) = o_packetiser_data(255 downto 0)) then
                     vectors_equal <= '1';
                  else
                     vectors_not_equal <= '1';
                  end if;
               end if;
            end if;
         end if;
      end if;
    end process;

    process(i_shared_clk)
    begin
      if rising_edge(i_shared_clk) then
         FIFO_rst <= '0';
         reset_ns_burst_timer <= '0';
         tx_FIFO_rd_en <= '0';
         start_of_packet <='0';
         end_of_packet <='0';
         start_next_loop <= '0';
         o_reset_packet_player <= '0';
         tx_complete <= '0';
         clear_start_next_burst_latched <= '0';
         run_timing <= '1';
         wait_fifo_resetting <= '0';
         error_fifo_stall <= '0';

         case output_fsm is
           when initial_state =>
             output_fsm_debug <= x"0";
             total_pkts_to_mac <= (others=>'0');
             output_fsm <= output_first_run0;
             loop_cnt <= (others =>'0');
             run_timing <= '0';

           when output_first_run0 =>
             output_fsm_debug <= x"1";
             FIFO_rst <= '1';
             o_reset_packet_player <= '1';
             wait_fifo_reset_cnt <= (others => '0');
             output_fsm <= output_first_run1;
             run_timing <= '0';

           when output_first_run1 =>
             output_fsm_debug <= x"2";
             if (wait_fifo_reset_cnt = to_unsigned(3, wait_fifo_reset_cnt'length)) then           
                if (rd_rst_busy = '0' and wr_rst_busy = '0') then 
                   output_fsm <= output_idle;
                end if;
             else
                 wait_fifo_reset_cnt <= wait_fifo_reset_cnt +1;
             end if;
             run_timing <= '0';

           when output_idle =>
             output_fsm_debug <= x"3";
             current_pkt_count <=(others=>'0');
             fpga_pkt_count_in_this_burst <= (others=>'0');
             beat_count <= (others => '0');
             total_beat_count <= (others => '0');
             burst_count <= (others => '0');
             run_timing <= '0';

             if (running = '1') then
                output_fsm <= output_next_burst;
                start_next_loop <= '1';
             end if;

           when output_next_burst =>  
             output_fsm_debug <= x"4";
             reset_ns_burst_timer <= '1';
             fpga_pkt_count_in_this_burst <= (others=>'0');
             fpga_beat_in_burst_counter <= (others => '0');
             -- Wait till we have all the packets for a given burst so that there is no stalling, 
             -- Also will help to identify if the fifo is being starved from the AXI HBM side. 
                    
             if FIFO_RdDataCount((ceil_log2(SYNC_FIFO_DEPTH)) downto 0) > i_expected_number_beats_per_burst((ceil_log2(SYNC_FIFO_DEPTH)) downto 0) then -- FIFO is 2k deep.
                output_fsm <= output_next_packet;
             else
                fpga_beat_in_burst_counter <= (others => '0');
             end if;

           when output_next_packet =>
             output_fsm_debug <= x"5";
             beat_count <= (others => '0');
             if (i_packetiser_data_to_player_rdy = '1') then
                output_fsm <= read_full_packet;
                total_pkts_to_mac <= total_pkts_to_mac + 1;
                start_of_packet <= '1';
             end if;
  
           when read_full_packet => -- start of reading
             output_fsm_debug <= x"6";
             -- Fifo is configured as FirstWordFallThrough, so data is immediatly available
             -- check empty
             tx_FIFO_rd_en <= '1';                                                       
             if (beat_count = unsigned(i_expected_beats_per_packet)) then
                end_of_packet <='1';
                current_pkt_count <= current_pkt_count + 1;
                output_fsm <= output_packet_finished;
             else
                beat_count <= beat_count +1;
                fpga_beat_in_burst_counter <= fpga_beat_in_burst_counter +1;  
                total_beat_count <= total_beat_count +1;  
             end if;

           when output_packet_finished =>
             output_fsm_debug <= x"7";
             if (fpga_pkt_count_in_this_burst = unsigned(i_expected_packets_per_burst)) then
                if (burst_count = unsigned(i_expected_total_number_of_bursts)) then
                   output_fsm <= output_tx_complete;
                else
                   output_fsm <= output_wait_burst_counter;
                end if; 
             else
                fpga_pkt_count_in_this_burst <= fpga_pkt_count_in_this_burst +1;
                output_fsm <= output_next_burst; 
             end if;

           when output_wait_burst_counter =>
             output_fsm_debug <= x"8";
             if (target_packets > total_pkts_to_mac) then
                clear_start_next_burst_latched <= '1';
                output_fsm <= output_next_burst;
                burst_count <= burst_count +1;
             end if;

           when output_tx_complete =>
             output_fsm_debug <= x"9";
             output_fsm <= output_tx_complete;
             if (i_loop_tx = '1') then
                output_fsm <= output_loopit;  
                wait_fifo_reset_cnt <= (others => '0');  
             end if;
                    
           when output_loopit =>
             output_fsm_debug <= x"A";
             if (loop_cnt = unsigned(i_expected_number_of_loops)) then
                 output_fsm <= output_thats_all_folks;  
             else
                 wait_fifo_reset_cnt <= wait_fifo_reset_cnt +1;
                 if (wait_fifo_reset_cnt = to_unsigned(0,wait_fifo_reset_cnt'length)) then
                    FIFO_rst <= '1';
                 elsif (wait_fifo_reset_cnt < to_unsigned(3,wait_fifo_reset_cnt'length)) then
                    wait_fifo_resetting <= '1';
                     -- give it a few clocks to clear the fifo's
                 else
                    wait_fifo_resetting <= '1';
                    if (rd_rst_busy = '0' and wr_rst_busy = '0') then 
                       wait_fifo_resetting <= '0';
                       output_fsm <= output_idle;
                       looping <= '1';
                       loop_cnt <= loop_cnt + 1;
                    end if;
                 end if;
             end if;

           when output_thats_all_folks =>
             output_fsm_debug <= x"B";
             tx_complete <= '1';
             output_fsm <= output_thats_all_folks;  

           when others =>
             output_fsm <= output_idle;

         end case; 
         if (reset_state = '1') then
            o_reset_packet_player <= '1';
            output_fsm <= initial_state;
        end if;
      end if;     
    end process;

    --------------------------------------
    -- Timer running off the fixed 100Mhz
    -------------------------------------- 
    ns_counter : process(clk_freerun)
    begin
        if rising_edge(clk_freerun) then
            start_next_burst_100Mhz <= '0';
            if (reset_state_100Mhz = '1') then
                ns_burst_timer_100Mhz <= (others => '0');
                ns_total_time_100Mhz <= (others => '0');
                start_next_burst_100Mhz <= '0';
                target_packets_100Mhz <= to_unsigned(1,target_packets_100Mhz'length);
                target_time_100Mhz <= resize(unsigned(time_between_bursts_ns_100Mhz), target_time_100Mhz'length);
            elsif (run_timing_100Mhz = '1') then                
                -- calculate how many packets we should have sent by now
                ns_total_time_100Mhz <= ns_total_time_100Mhz + to_unsigned(10,ns_total_time_100Mhz'length);
                if (ns_total_time_100Mhz >= target_time_100Mhz) then
                    target_time_100Mhz <= target_time_100Mhz + resize(unsigned(time_between_bursts_ns_100Mhz), target_time_100Mhz'length);
                    target_packets_100Mhz <= target_packets_100Mhz + 1;
                end if;
            end if;
        end if;
    end process ns_counter;

    --------------------------------------------------------------------------------------------
    -- FIFO for write addresses
    -- Input to the fifo comes from "input_fsm".
    -- It is read as fast as addresses are accepted by the shared memory bus.
    --------------------------------------------------------------------------------------------
    data_fifo : xpm_fifo_sync
    generic map (
        DOUT_RESET_VALUE => "0",    -- String
        ECC_MODE => "no_ecc",       -- String
        FIFO_MEMORY_TYPE => "BLOCK", -- String
        FIFO_READ_LATENCY => 1,     -- DECIMAL
        FIFO_WRITE_DEPTH => SYNC_FIFO_DEPTH,   -- DECIMAL; Allow up to 32 outstanding write requests.
        FULL_RESET_VALUE => 0,      -- DECIMAL
        PROG_EMPTY_THRESH => 10,    -- DECIMAL
        PROG_FULL_THRESH => (SYNC_FIFO_DEPTH/2),     -- DECIMAL
        RD_DATA_COUNT_WIDTH => ((ceil_log2(SYNC_FIFO_DEPTH))+1),  -- DECIMAL
        READ_DATA_WIDTH => 512,      -- DECIMAL
        READ_MODE => "fwft",        -- String
        SIM_ASSERT_CHK => 0,        -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        USE_ADV_FEATURES => "1F1F", -- String  -- bit 1 is prof_full_flag, bit 2 and bit 10 enables write data count and read data count
        WAKEUP_TIME => 0,           -- DECIMAL
        WRITE_DATA_WIDTH => 512,     -- DECIMAL
        WR_DATA_COUNT_WIDTH => ((ceil_log2(SYNC_FIFO_DEPTH))+1)   -- DECIMAL
    )
    port map (
        almost_empty => open,     -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
        almost_full => FIFO_almost_full,      -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
        data_valid => open,       -- Need to set bit 12 of "USE_ADV_FEATURES" to enable this output. 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
        dbiterr => open,          -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
        dout => FIFO_dout,      -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
        empty => FIFO_empty,    -- 1-bit output: Empty Flag: When asserted, this signal indicates that- the FIFO is empty.
        full => FIFO_full,      -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full.
        overflow => open,         -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is full
        prog_empty => open,       -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value.
        prog_full => FIFO_prog_full,        -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value.
        rd_data_count => FIFO_RdDataCount, -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
        rd_rst_busy => rd_rst_busy,      -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
        sbiterr => open,          -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
        underflow => open,        -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty.
        wr_ack => open,           -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
        wr_data_count => FIFO_WrDataCount, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
        wr_rst_busy => wr_rst_busy,      -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
        din => FIFO_din,        -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
        injectdbiterr => '0',     -- 1-bit input: Double Bit Error Injection
        injectsbiterr => '0',     -- 1-bit input: Single Bit Error Injection:
        rd_en => tx_FIFO_rd_en, -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO.
        rst => FIFO_rst,        -- 1-bit input: Reset: Must be synchronous to wr_clk.
        sleep => '0',             -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
        wr_clk => i_shared_clk,   -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en => tx_FIFO_wr_en      -- 1-bit input: Write Enable:
    );

	     
    xpm_cdc_inst : xpm_cdc_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1    
    )
    port map (
        dest_clk        => i_shared_clk,   
        dest_out        => start_next_burst, 
                
        src_clk         => clk_freerun,    
        src_in          => start_next_burst_100Mhz
    );

    xpm_cdc_inst14 : xpm_cdc_array_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1, 
        WIDTH           => 64    
    )
    port map (
        dest_clk        => i_shared_clk,   
        dest_out        => target_packets_std_logic,       
        src_clk         => clk_freerun,       
        src_in          => std_logic_vector(target_packets_100Mhz)
    );
    
   target_packets <=  unsigned(target_packets_std_logic);

    xpm_cdc_inst1 : xpm_cdc_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1    
    )
    port map (
        dest_clk        => clk_freerun,   
        dest_out        => reset_state_100Mhz, 
        src_clk         => i_shared_clk,    
        src_in          => reset_state
    );

    xpm_cdc_inst11 : xpm_cdc_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1    
    )
    port map (
        dest_clk        => clk_freerun,   
        dest_out        => run_timing_100Mhz, 
        src_clk         => i_shared_clk,    
        src_in          => run_timing
    );
    

    xpm_cdc_inst2 : xpm_cdc_array_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1, 
        WIDTH           => 32    
    )
    port map (
        dest_clk        => i_shared_clk,   
        dest_out        => ns_burst_timer_std_logic,        
        src_clk         => clk_freerun,    
        src_in          => std_logic_vector(ns_burst_timer_100Mhz)
    );


    xpm_cdc_inst3 : xpm_cdc_array_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1, 
        WIDTH           => 32    
    )
    port map (
        dest_clk        => i_shared_clk,   
        dest_out        => ns_total_time_std_logic,       
        src_clk         => clk_freerun,    
        src_in          => std_logic_vector(ns_total_time_100Mhz(47 downto (47-31)))
    );

    xpm_cdc_inst4 : xpm_cdc_array_single
    generic map (
        DEST_SYNC_FF    => 4,   
        INIT_SYNC_FF    => 1,   
        SRC_INPUT_REG   => 1,   
        SIM_ASSERT_CHK  => 1, 
        WIDTH           => 32    
    )
    port map (
        dest_clk        => clk_freerun,   
        dest_out        => time_between_bursts_ns_100Mhz,       
        src_clk         => i_shared_clk,    
        src_in          => i_time_between_bursts_ns
    );
    



end RTL;
