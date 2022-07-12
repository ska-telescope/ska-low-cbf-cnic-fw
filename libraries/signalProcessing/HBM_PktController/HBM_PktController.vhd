----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Jason van Aardt, jason.vanaardt@csiro.au
-- 
-- Create Date: 27.10.2021 
-- Module Name: HBM_PktController
-- Description: 
--      Reads Packets out of the HBM AXI M1 512 bit interface and writes them out over a 512bit Lbus to the packetizer or the 100G MAC
--
----------------------------------------------------------------------------------
-- Structure
-- ---------
-- This is the top level of the HBM_PktController
--  + Registers which apply to controllering the PktController
-- The HBM_PktController will use the full 8 Gbyte of memory, but currently uses 1GByte  
-- 
-- The incomming packets are 512bit aligned in HBM memory, to make it easier to read out and put directly 
-- on the 512bit Lbus towards the packetizer or 100G CMAC. 
--
-- (2154*8)/512 = 33.65625, i.e. 34 512bit CMAC Lbus transactions per packet of size 2154
-- (1 Gbyte)/((34*512)/8 bytes) = 2^30/2176 = 2^17 = 493447.5294117647 packets.
--  
--
--  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
--  See the file LICENSE for more info.
----------------------------------------------------------------------------------

library IEEE, ct_lib, common_lib, xpm, HBM_PktController_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library cnic_lib;
use cnic_lib.cnic_top_pkg.all;
--USE HBM_PktController_lib.ct_atomic_pst_in_reg_pkg.ALL;

USE HBM_PktController_lib.HBM_PktController_hbm_pktcontroller_reg_pkg.ALL;
USE common_lib.common_pkg.ALL;

library xpm;
use xpm.vcomponents.all;

Library axi4_lib;
USE axi4_lib.axi4_lite_pkg.ALL;
use axi4_lib.axi4_full_pkg.all;


entity HBM_PktController is
    generic (
        g_DEBUG_ILAs                    : BOOLEAN := FALSE
    );
    Port(
        clk_freerun     : in std_logic;
        -- shared memory interface clock (300 MHz)
        i_shared_clk     : in std_logic;
        i_shared_rst     : in std_logic;


        o_reset_packet_player : out std_logic;
        -- Registers (uses the shared memory clock)
        i_saxi_mosi       : in  t_axi4_lite_mosi; -- MACE IN
        o_saxi_miso       : out t_axi4_lite_miso; -- MACE OUT
        
        o_start_stop_tx   : out std_logic;  -- reset from the register module, copied out to be used downstream.
        
        ------------------------------------------------------------------------------------
        -- Data output, to the packetizer
        -- Add the packetizer records here
        o_packetiser_data_in_wr  : out std_logic;
        o_packetiser_data        : out std_logic_vector(511 downto 0);
        o_packetiser_bytes_to_transmit : out std_logic_vector(13 downto 0);
        i_packetiser_data_to_player_rdy : in std_logic;

        -----------------------------------------------------------------------
        i_schedule_action   : in std_logic_vector(7 downto 0);
        -------------------------------------------------------------
        -- 512 bit wide AXI bus to the shared memory. 
        -- This has the aw, b, ar and r buses (the w bus is on the output of the LFAA decode module)
        -- w bus - write data
        
	-- m01
        m01_axi_awvalid  : out std_logic;
        m01_axi_awready  : in std_logic;
        m01_axi_awaddr   : out std_logic_vector(31 downto 0);
        m01_axi_awlen    : out std_logic_vector(7 downto 0);
        -- b bus - write response
        m01_axi_bvalid    : in std_logic;
        m01_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m01_axi_arvalid   : out std_logic;
        m01_axi_arready   : in std_logic;
        m01_axi_araddr    : out std_logic_vector(31 downto 0);
        m01_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m01_axi_rvalid    : in std_logic;
        m01_axi_rready    : out std_logic;
        m01_axi_rdata     : in std_logic_vector(511 downto 0);
        m01_axi_rlast     : in std_logic;
        m01_axi_rresp     : in std_logic_vector(1 downto 0);

	-- m02
        m02_axi_awvalid  : out std_logic;
        m02_axi_awready  : in std_logic;
        m02_axi_awaddr   : out std_logic_vector(31 downto 0);
        m02_axi_awlen    : out std_logic_vector(7 downto 0);
        -- b bus - write response
        m02_axi_bvalid    : in std_logic;
        m02_axi_bresp     : in std_logic_vector(1 downto 0);
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

	-- m03
        m03_axi_awvalid  : out std_logic;
        m03_axi_awready  : in std_logic;
        m03_axi_awaddr   : out std_logic_vector(31 downto 0);
        m03_axi_awlen    : out std_logic_vector(7 downto 0);
        -- b bus - write response
        m03_axi_bvalid    : in std_logic;
        m03_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m03_axi_arvalid   : out std_logic;
        m03_axi_arready   : in std_logic;
        m03_axi_araddr    : out std_logic_vector(31 downto 0);
        m03_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m03_axi_rvalid    : in std_logic;
        m03_axi_rready    : out std_logic;
        m03_axi_rdata     : in std_logic_vector(511 downto 0);
        m03_axi_rlast     : in std_logic;
        m03_axi_rresp     : in std_logic_vector(1 downto 0);

	-- m04
        m04_axi_awvalid  : out std_logic;
        m04_axi_awready  : in std_logic;
        m04_axi_awaddr   : out std_logic_vector(31 downto 0);
        m04_axi_awlen    : out std_logic_vector(7 downto 0);
        -- b bus - write response
        m04_axi_bvalid    : in std_logic;
        m04_axi_bresp     : in std_logic_vector(1 downto 0);
        -- ar bus - read address
        m04_axi_arvalid   : out std_logic;
        m04_axi_arready   : in std_logic;
        m04_axi_araddr    : out std_logic_vector(31 downto 0);
        m04_axi_arlen     : out std_logic_vector(7 downto 0);
        -- r bus - read data
        m04_axi_rvalid    : in std_logic;
        m04_axi_rready    : out std_logic;
        m04_axi_rdata     : in std_logic_vector(511 downto 0);
        m04_axi_rlast     : in std_logic;
        m04_axi_rresp     : in std_logic_vector(1 downto 0)   
    );
end HBM_PktController;

architecture RTL of HBM_PktController is
    
    COMPONENT ila_0
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
    END COMPONENT;


    -- NEEDS TO BE AT LEAST 4K deep to handle the HBM requests when there is slow playout on the 100G.
    constant SYNC_FIFO_DEPTH : integer := 4096;

    -- register interface
    signal config_rw : t_config_rw;
    signal config_ro : t_config_ro;

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
    signal FIFO_rd_en : std_logic;  
    signal FIFO_rst : std_logic;       
    signal FIFO_wr_en : std_logic;     
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

    --signal debug_firstvector_compare_ethernet_hdr : std_logic_vector(511 downto 0); 
    --signal debug_firstvector_trigger : std_logic := '1';
    --signal pkt_first_vector_bad : std_logic;
    signal reset_cnt : unsigned(3 downto 0);


    signal first_time, compare_vectors, vectors_equal, vectors_not_equal, o_packetiser_data_in_wr_prev : std_logic;
    signal first_packet_golden_data : std_logic_vector(511 downto 0); 


begin
    ARGS_register_HBM_PktController : entity HBM_PktController_lib.HBM_PktController_hbm_pktcontroller_reg
    port map (
        MM_CLK  => i_shared_clk, -- in std_logic;
        MM_RST  => i_shared_rst, -- in std_logic;
        SLA_IN  => i_saxi_mosi,  -- IN    t_axi4_lite_mosi;
        SLA_OUT => o_saxi_miso,  -- OUT   t_axi4_lite_miso;

        CONFIG_FIELDS_RW   => config_rw, -- OUT t_config_rw;
        CONFIG_FIELDS_RO   => config_ro  
    );
    
    config_ro.running <= running; 
    config_ro.looping <= looping;
    config_ro.loop_cnt <= std_logic_vector(loop_cnt);
    config_ro.tx_complete <= tx_complete; 
    config_ro.current_pkt_count_high <= std_logic_vector(current_pkt_count(63 downto 32));  
    config_ro.current_pkt_count_low <= std_logic_vector(current_pkt_count(31 downto 0));  
    config_ro.current_axi_4k_count <= std_logic_vector(current_axi_4k_count); 
    config_ro.total_beat_count <= std_logic_vector(total_beat_count); 
    config_ro.fpga_axi_beats_per_packet(fpga_axi_beats_per_packet'range) <= std_logic_vector(fpga_axi_beats_per_packet);

    config_ro.beat_count <= std_logic_vector(beat_count); 
    config_ro.burst_count <= std_logic_vector(burst_count);

    config_ro.fpga_beat_in_burst_counter <= std_logic_vector(fpga_beat_in_burst_counter); 

    config_ro.fpga_pkt_count_in_this_burst <= std_logic_vector(fpga_pkt_count_in_this_burst);

    config_ro.ns_total_time <= ns_total_time_std_logic;
    config_ro.ns_burst_timer <= ns_burst_timer_std_logic;
    config_ro.fifo_prog_full <= FIFO_prog_full;
    config_ro.fifo_full <= FIFO_full;
    config_ro.rd_fsm_debug(rd_fsm_debug'range) <= std_logic_vector(rd_fsm_debug);
    config_ro.output_fsm_debug(output_fsm_debug'range) <= std_logic_vector(output_fsm_debug);

    config_ro.fifo_rddatacount(FIFO_RdDataCount'range) <= std_logic_vector(FIFO_RdDataCount);
    config_ro.fifo_wrdatacount(FIFO_WrDataCount'range) <= std_logic_vector(FIFO_WrDataCount);

    config_ro.total_pkts_to_mac_high(31 downto 0) <= std_logic_vector(total_pkts_to_mac(63 downto 32));
    config_ro.total_pkts_to_mac_low(31 downto 0) <= std_logic_vector(total_pkts_to_mac(31 downto 0));

    process(i_shared_rst, i_shared_clk)
    begin
        if rising_edge(i_shared_clk) then
            start_stop_tx <= config_rw.start_stop_tx OR i_schedule_action(1);
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
    m01_axi_arvalid   <= o_axi_arvalid;
    i_axi_arready     <= m01_axi_arready;
    m01_axi_araddr    <= o_axi_araddr;
    m01_axi_arlen     <= o_axi_arlen;
    -- r bus - read data
    i_axi_rvalid      <= m01_axi_rvalid;
    m01_axi_rready    <= o_axi_rready;
    i_axi_rdata       <= m01_axi_rdata;
    i_axi_rlast       <= m01_axi_rlast;
    i_axi_rresp       <= m01_axi_rresp; 

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
                        readaddr <= (others =>'0');
                        current_axi_4k_count <= (others =>'0');
                        rd_fsm <= wait_fifo_reset;

                    when wait_fifo_reset =>
                        rd_fsm_debug <= x"1";
                        --if (running = '1') then
                        if (start_next_loop = '1') then
                            --if (rd_rst_busy = '0' and wr_rst_busy = '0') then 
                                --if i_axi_arready = '1' then
                                    o_axi_arvalid <= '1';
                                    rd_fsm <= wait_arready;
                                --end if;
                            --end if;
                        end if;

                    when wait_arready =>  -- arvalid is high in this state, wait until arready is high so the transaction is complete.--o_axi_arvalid <= '0';
                        rd_fsm_debug <= x"2";
                        o_axi_arvalid <= '1';
                        if i_axi_arready = '1' then
                                o_axi_arvalid <= '0';
                                -- update the address and make the read request
                                readaddr <= readaddr + 4096;
                                current_axi_4k_count <= current_axi_4k_count +1;
                                -- let it increment the address first
                                if (current_axi_4k_count = unsigned(config_rw.expected_total_number_of_4k_axi)) then 
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

                    when finished =>
                        rd_fsm_debug <= x"4";
                        if (config_rw.loop_tx = '1') then
                                rd_fsm <= loopit;
                        else
                            rd_fsm <= finished;
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
            FIFO_wr_en <= '0';
            if (i_axi_rvalid = '1') then
                if (FIFO_full = '1') then
                    config_ro.axi_rvalid_but_fifo_full <= '1'; 
                else
                    FIFO_din <= i_axi_rdata;
                    FIFO_wr_en <= '1';
                end if;
            end if;

            if (reset_state = '1') then
                config_ro.axi_rvalid_but_fifo_full <= '0'; 
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
    beats <= unsigned(config_rw.packet_size(13 downto 6)); -- 64 bytes per beat
    process(i_shared_clk)
    begin
        if rising_edge(i_shared_clk) then
            if (config_rw.packet_size(5 downto 0) = "000000") then
                --axi_beats_per_packet <= "000000" & beats -1; -- start counting at 0 ie 0 is 1 beat
                fpga_axi_beats_per_packet <= beats -1; -- start counting at 0 ie 0 is 1 beat
            else
                --axi_beats_per_packet <= "000000" & (beats);
                fpga_axi_beats_per_packet <= beats;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------------------------------
    -- State machine that reads whole packets out of the Fifo and presents to Packet_Player
    -- Input to the fifo comes from the data retrieved from the HBM via the AXI bus
    --------------------------------------------------------------------------------------------
    o_packetiser_data_in_wr <= FIFO_rd_en;
    o_packetiser_data       <= FIFO_dout;

    o_packetiser_bytes_to_transmit <= config_rw.packet_size(13 downto 0);


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
                if(first_time = '1') then
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
                if(first_time = '0') then
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
            FIFO_rd_en <= '0';
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
                    --debug_firstvector_trigger <= '1';
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
                    
                    if FIFO_RdDataCount((ceil_log2(SYNC_FIFO_DEPTH)) downto 0) > config_rw.expected_number_beats_per_burst((ceil_log2(SYNC_FIFO_DEPTH)) downto 0) then    -- FIFO is 2k deep.
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
                            FIFO_rd_en <= '1';                                                       
--                            if (FIFO_empty = '1') then
--                                error_fifo_stall <= '1';
--                            else
                                if (beat_count = unsigned(config_rw.expected_beats_per_packet)) then
                                    end_of_packet <='1';
                                    current_pkt_count <= current_pkt_count + 1;
                                    output_fsm <= output_packet_finished;
                                else
                                    beat_count <= beat_count +1;
                                    fpga_beat_in_burst_counter <= fpga_beat_in_burst_counter +1;  
                                    total_beat_count <= total_beat_count +1;  
                                end if;
--                            end if;
                            

                when output_packet_finished =>
                    output_fsm_debug <= x"7";
                    if ( fpga_pkt_count_in_this_burst = unsigned(config_rw.expected_packets_per_burst)) then
                        if ( burst_count = unsigned(config_rw.expected_total_number_of_bursts) ) then
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
                    if(target_packets > total_pkts_to_mac) then
                        clear_start_next_burst_latched <= '1';
                        output_fsm <= output_next_burst;
                        burst_count <= burst_count +1;
                    end if;

                when output_tx_complete =>
                    output_fsm_debug <= x"9";
                    output_fsm <= output_tx_complete;
                    if (config_rw.loop_tx = '1') then
                        output_fsm <= output_loopit;  
                        wait_fifo_reset_cnt <= (others => '0');  
                    end if;
                    
                when output_loopit =>
                    output_fsm_debug <= x"A";
                    if (loop_cnt = unsigned(config_rw.expected_number_of_loops)) then
                        output_fsm <= output_thats_all_folks;  
                    else
                        wait_fifo_reset_cnt <= wait_fifo_reset_cnt +1;
                        if (wait_fifo_reset_cnt = to_unsigned(0,wait_fifo_reset_cnt'length)) then
                            FIFO_rst <= '1';
                            --o_reset_packet_player <= '1';       -- Reset the FIFOs in the packet_player.
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

                -- ns_burst_timer_100Mhz <= ns_burst_timer_100Mhz +10;
                -- if (ns_burst_timer_100Mhz >= unsigned(time_between_bursts_ns_100Mhz)) then
                --     start_next_burst_100Mhz <= '1';
                --     ns_burst_timer_100Mhz <= (others => '0');
                -- end if;                    
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
        rd_en => FIFO_rd_en, -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. 
        rst => FIFO_rst,        -- 1-bit input: Reset: Must be synchronous to wr_clk.
        sleep => '0',             -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
        wr_clk => i_shared_clk,   -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en => FIFO_wr_en      -- 1-bit input: Write Enable: 
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
        src_in          => config_rw.time_between_bursts_ns
    );
    

debug_ILAs : IF g_DEBUG_ILAs GENERATE
    -- Capture transactions using the ILA
    u_m01_ila : ila_0
    port map (
        clk => i_shared_clk,
        probe0(3 downto 0) => rd_fsm_debug,
        probe0(33 downto 4) => m01_axi_araddr(29 downto 0),
        probe0(34) => m01_axi_arvalid,
        probe0(35) => m01_axi_arready,
        probe0(67 downto 36) => first_packet_golden_data(31 downto 0),
 
        probe0(68) => m01_axi_rvalid,
        probe0(69) => m01_axi_rready,
        probe0(70) => m01_axi_rlast,
        probe0(72 downto 71) => m01_axi_rresp(1 downto 0),

        probe0(76 downto 73) => output_fsm_debug,
        probe0(90 downto 77) => FIFO_WrDataCount,
        probe0(91) => FIFO_prog_full,
        probe0(92) => FIFO_full,
        probe0(93) => FIFO_wr_en,
        probe0(109 downto 94) =>FIFO_din(15 downto 0), 
        probe0(123 downto 110) => FIFO_RdDataCount,
        probe0(124) => FIFO_rd_en,
        probe0(125) => vectors_equal, 
        probe0(126) => vectors_not_equal, 
        probe0(127) => compare_vectors,
        probe0(128) => first_time,
        probe0(129) => FIFO_empty, 
        probe0(130) => FIFO_rst, 
        probe0(131) => rd_rst_busy, 
        probe0(132) => wr_rst_busy, 
        probe0(133) => wait_fifo_resetting,
        probe0(134) => error_fifo_stall, 
        probe0(139 downto 135) => (others => '0'),
        probe0(140) => start_next_loop, 
        probe0(141) => i_packetiser_data_to_player_rdy, 
        probe0(142) => o_packetiser_data_in_wr, 
        probe0(174 downto 143) => o_packetiser_data(31 downto 0),
        probe0(188 downto 175) => o_packetiser_bytes_to_transmit, 
        probe0(189) => start_next_burst, 
        probe0(190) => start_next_burst_latched, 
        probe0(191) => clear_start_next_burst_latched
    );
    
    -- Capture transactions using the ILA
    error_condition_ila : ila_0
    port map (
        clk => i_shared_clk,
        probe0(3 downto 0) => rd_fsm_debug,
        probe0(35 downto 4)     => o_packetiser_data(511 downto 480),

        probe0(67 downto 36)    => o_packetiser_data(383 downto 352),
 
        probe0(68) => m01_axi_rvalid,
        probe0(69) => m01_axi_rready,
        probe0(70) => m01_axi_rlast,
        probe0(72 downto 71) => m01_axi_rresp(1 downto 0),

        probe0(76 downto 73) => output_fsm_debug,
        probe0(90 downto 77) => FIFO_WrDataCount,
        probe0(91) => FIFO_prog_full,
        probe0(92) => FIFO_full,
        probe0(93) => FIFO_wr_en,
        probe0(109 downto 94) =>FIFO_din(15 downto 0), 
        probe0(123 downto 110) => FIFO_RdDataCount,
        probe0(124) => FIFO_rd_en,
        probe0(125) => vectors_equal, 
        probe0(126) => vectors_not_equal, 
        probe0(127) => compare_vectors,
        probe0(128) => first_time,
        probe0(129) => FIFO_empty, 
        probe0(130) => FIFO_rst, 
        probe0(131) => rd_rst_busy, 
        probe0(132) => wr_rst_busy, 
        probe0(133) => wait_fifo_resetting,
        probe0(134) => error_fifo_stall, 
        probe0(139 downto 135) => (others => '0'),
        probe0(140) => start_next_loop, 
        probe0(141) => i_packetiser_data_to_player_rdy, 
        probe0(142) => o_packetiser_data_in_wr, 
        probe0(174 downto 143) => o_packetiser_data(31 downto 0),
        probe0(188 downto 175) => o_packetiser_bytes_to_transmit, 
        probe0(189) => start_next_burst, 
        probe0(190) => start_next_burst_latched, 
        probe0(191) => clear_start_next_burst_latched
    );

    u_ila_2 : ila_0
    port map (
        clk => i_shared_clk,
        probe0(63 downto 0) => std_logic_vector(target_packets),
        probe0(127 downto 64) => std_logic_vector(total_pkts_to_mac),
        probe0(128) => run_timing, 
        probe0(191 downto 129) => (others=>'0')
    );

    u_ila_3 : ila_0
    port map (
        clk => clk_freerun,
        probe0(47 downto 0) => std_logic_vector(target_time_100Mhz),
        probe0(95 downto 48) => std_logic_vector(ns_total_time_100Mhz),
        probe0(96) => run_timing_100Mhz, 
        probe0(191 downto 97) => (others=>'0')

    );
    
END GENERATE;    

end RTL;
