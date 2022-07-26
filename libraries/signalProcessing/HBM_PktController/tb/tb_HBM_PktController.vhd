----------------------------------------------------------------------------------
-- Company: CSIRO 
-- Engineer: Jonathan Li (jonathan.li@csiro.au)
-- 
-- Create Date: 18 July 2022
-- Module Name: tb_HBM_PktController - Behavioral
-- Description: 
--  Testbench for HBM packet controller with AXI read and write
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use IEEE.std_logic_textio.all;
library xpm;
use xpm.vcomponents.all;
library common_lib, axi4_lib;
library HBM_PktController_lib, PSR_Packetiser_lib;
use common_lib.common_pkg.all;
use axi4_lib.axi4_stream_pkg.all;
use axi4_lib.axi4_lite_pkg.all;
use axi4_lib.axi4_full_pkg.all;
use std.env.finish;

entity tb_HBM_PktController is
end tb_HBM_PktController;

architecture Behavioral of tb_HBM_PktController is

constant  data_file_name           : string := "LFAA100GE_tb_data.txt";

signal    clock_300                : std_logic := '0';    -- 3.33ns
signal    clock_100                : std_logic := '0';    -- 10ns

signal    testCount_300            : integer   := 0;
signal    clock_300_rst            : std_logic := '1';
signal    power_up_rst_clock_300   : std_logic_vector(31 downto 0) := X"FFFFFFFF";

signal    testCount_100            : integer   := 0;
signal    clock_100_rst            : std_logic := '1';
signal    power_up_rst_clock_100   : std_logic_vector(31 downto 0) := X"FFFFFFFF";

signal m01_awvalid  : std_logic;
signal m01_awready  : std_logic;
signal m01_awaddr   : std_logic_vector(31 downto 0);
signal m01_awid     : std_logic_vector(0 downto 0);
signal m01_awlen    : std_logic_vector(7 downto 0);
signal m01_awsize   : std_logic_vector(2 downto 0);
signal m01_awburst  : std_logic_vector(1 downto 0);
signal m01_awlock   : std_logic_vector(1 downto 0);
signal m01_awcache  : std_logic_vector(3 downto 0);
signal m01_awprot   : std_logic_vector(2 downto 0);
signal m01_awqos    : std_logic_vector(3 downto 0);
signal m01_awregion : std_logic_vector(3 downto 0);
signal m01_wvalid   : std_logic;
signal m01_wready   : std_logic;
signal m01_wdata    : std_logic_vector(511 downto 0);
signal m01_wstrb    : std_logic_vector(63 downto 0);
signal m01_wlast    : std_logic;
signal m01_bvalid   : std_logic;
signal m01_bready   : std_logic;
signal m01_bresp    : std_logic_vector(1 downto 0);
signal m01_bid      : std_logic_vector(0 downto 0);
signal m01_arvalid  : std_logic;
signal m01_arready  : std_logic;
signal m01_araddr   : std_logic_vector(31 downto 0);
signal m01_arid     : std_logic_vector(0 downto 0);
signal m01_arlen    : std_logic_vector(7 downto 0);
signal m01_arsize   : std_logic_vector(2 downto 0);
signal m01_arburst  : std_logic_vector(1 downto 0);
signal m01_arlock   : std_logic_vector(1 downto 0);
signal m01_arcache  : std_logic_vector(3 downto 0);
signal m01_arprot   : std_logic_Vector(2 downto 0);
signal m01_arqos    : std_logic_vector(3 downto 0);
signal m01_arregion : std_logic_vector(3 downto 0);
signal m01_rvalid   : std_logic;
signal m01_rready   : std_logic;
signal m01_rdata    : std_logic_vector(511 downto 0);
signal m01_rlast    : std_logic;
signal m01_rid      : std_logic_vector(0 downto 0);
signal m01_rresp    : std_logic_vector(1 downto 0);

signal m02_awvalid  : std_logic;
signal m02_awready  : std_logic;
signal m02_awaddr   : std_logic_vector(31 downto 0);
signal m02_awid     : std_logic_vector(0 downto 0);
signal m02_awlen    : std_logic_vector(7 downto 0);
signal m02_awsize   : std_logic_vector(2 downto 0);
signal m02_awburst  : std_logic_vector(1 downto 0);
signal m02_awlock   : std_logic_vector(1 downto 0);
signal m02_awcache  : std_logic_vector(3 downto 0);
signal m02_awprot   : std_logic_vector(2 downto 0);
signal m02_awqos    : std_logic_vector(3 downto 0);
signal m02_awregion : std_logic_vector(3 downto 0);
signal m02_wvalid   : std_logic;
signal m02_wready   : std_logic;
signal m02_wdata    : std_logic_vector(511 downto 0);
signal m02_wstrb    : std_logic_vector(63 downto 0);
signal m02_wlast    : std_logic;
signal m02_bvalid   : std_logic;
signal m02_bready   : std_logic;
signal m02_bresp    : std_logic_vector(1 downto 0);
signal m02_bid      : std_logic_vector(0 downto 0);
signal m02_arvalid  : std_logic;
signal m02_arready  : std_logic;
signal m02_araddr   : std_logic_vector(31 downto 0);
signal m02_arid     : std_logic_vector(0 downto 0);
signal m02_arlen    : std_logic_vector(7 downto 0);
signal m02_arsize   : std_logic_vector(2 downto 0);
signal m02_arburst  : std_logic_vector(1 downto 0);
signal m02_arlock   : std_logic_vector(1 downto 0);
signal m02_arcache  : std_logic_vector(3 downto 0);
signal m02_arprot   : std_logic_Vector(2 downto 0);
signal m02_arqos    : std_logic_vector(3 downto 0);
signal m02_arregion : std_logic_vector(3 downto 0);
signal m02_rvalid   : std_logic;
signal m02_rready   : std_logic;
signal m02_rdata    : std_logic_vector(511 downto 0);
signal m02_rlast    : std_logic;
signal m02_rid      : std_logic_vector(0 downto 0);
signal m02_rresp    : std_logic_vector(1 downto 0);

signal m03_awvalid  : std_logic;
signal m03_awready  : std_logic;
signal m03_awaddr   : std_logic_vector(31 downto 0);
signal m03_awid     : std_logic_vector(0 downto 0);
signal m03_awlen    : std_logic_vector(7 downto 0);
signal m03_awsize   : std_logic_vector(2 downto 0);
signal m03_awburst  : std_logic_vector(1 downto 0);
signal m03_awlock   : std_logic_vector(1 downto 0);
signal m03_awcache  : std_logic_vector(3 downto 0);
signal m03_awprot   : std_logic_vector(2 downto 0);
signal m03_awqos    : std_logic_vector(3 downto 0);
signal m03_awregion : std_logic_vector(3 downto 0);
signal m03_wvalid   : std_logic;
signal m03_wready   : std_logic;
signal m03_wdata    : std_logic_vector(511 downto 0);
signal m03_wstrb    : std_logic_vector(63 downto 0);
signal m03_wlast    : std_logic;
signal m03_bvalid   : std_logic;
signal m03_bready   : std_logic;
signal m03_bresp    : std_logic_vector(1 downto 0);
signal m03_bid      : std_logic_vector(0 downto 0);
signal m03_arvalid  : std_logic;
signal m03_arready  : std_logic;
signal m03_araddr   : std_logic_vector(31 downto 0);
signal m03_arid     : std_logic_vector(0 downto 0);
signal m03_arlen    : std_logic_vector(7 downto 0);
signal m03_arsize   : std_logic_vector(2 downto 0);
signal m03_arburst  : std_logic_vector(1 downto 0);
signal m03_arlock   : std_logic_vector(1 downto 0);
signal m03_arcache  : std_logic_vector(3 downto 0);
signal m03_arprot   : std_logic_Vector(2 downto 0);
signal m03_arqos    : std_logic_vector(3 downto 0);
signal m03_arregion : std_logic_vector(3 downto 0);
signal m03_rvalid   : std_logic;
signal m03_rready   : std_logic;
signal m03_rdata    : std_logic_vector(511 downto 0);
signal m03_rlast    : std_logic;
signal m03_rid      : std_logic_vector(0 downto 0);
signal m03_rresp    : std_logic_vector(1 downto 0);

signal m04_awvalid  : std_logic;
signal m04_awready  : std_logic;
signal m04_awaddr   : std_logic_vector(31 downto 0);
signal m04_awid     : std_logic_vector(0 downto 0);
signal m04_awlen    : std_logic_vector(7 downto 0);
signal m04_awsize   : std_logic_vector(2 downto 0);
signal m04_awburst  : std_logic_vector(1 downto 0);
signal m04_awlock   : std_logic_vector(1 downto 0);
signal m04_awcache  : std_logic_vector(3 downto 0);
signal m04_awprot   : std_logic_vector(2 downto 0);
signal m04_awqos    : std_logic_vector(3 downto 0);
signal m04_awregion : std_logic_vector(3 downto 0);
signal m04_wvalid   : std_logic;
signal m04_wready   : std_logic;
signal m04_wdata    : std_logic_vector(511 downto 0);
signal m04_wstrb    : std_logic_vector(63 downto 0);
signal m04_wlast    : std_logic;
signal m04_bvalid   : std_logic;
signal m04_bready   : std_logic;
signal m04_bresp    : std_logic_vector(1 downto 0);
signal m04_bid      : std_logic_vector(0 downto 0);
signal m04_arvalid  : std_logic;
signal m04_arready  : std_logic;
signal m04_araddr   : std_logic_vector(31 downto 0);
signal m04_arid     : std_logic_vector(0 downto 0);
signal m04_arlen    : std_logic_vector(7 downto 0);
signal m04_arsize   : std_logic_vector(2 downto 0);
signal m04_arburst  : std_logic_vector(1 downto 0);
signal m04_arlock   : std_logic_vector(1 downto 0);
signal m04_arcache  : std_logic_vector(3 downto 0);
signal m04_arprot   : std_logic_Vector(2 downto 0);
signal m04_arqos    : std_logic_vector(3 downto 0);
signal m04_arregion : std_logic_vector(3 downto 0);
signal m04_rvalid   : std_logic;
signal m04_rready   : std_logic;
signal m04_rdata    : std_logic_vector(511 downto 0);
signal m04_rlast    : std_logic;
signal m04_rid      : std_logic_vector(0 downto 0);
signal m04_rresp    : std_logic_vector(1 downto 0);

signal packetiser_data_in_wr : std_logic;
signal packetiser_data       : std_logic_vector(511 downto 0);
signal packetiser_data_to_player_rdy : std_logic;
signal packetiser_bytes_to_transmit  : std_logic_vector(13 downto 0);
signal i_reset_packet_player         : std_logic;

signal LFAADone                      : std_logic := '0';
signal s_axi_data                    : std_logic_vector(511 downto 0);
signal s_axi_data_valid              : std_logic;
signal i_rx_soft_reset               : std_logic;

signal i_lfaa_bank1_start_addr       : std_logic_vector(31 downto 0) := (others=>'0');
signal i_lfaa_bank2_start_addr       : std_logic_vector(31 downto 0) := (others=>'0');
signal i_lfaa_bank3_start_addr       : std_logic_vector(31 downto 0) := (others=>'0');
signal i_lfaa_bank4_start_addr       : std_logic_vector(31 downto 0) := (others=>'0');
signal update_rx_start_addr          : std_logic := '0';

begin

  clock_300 <= not clock_300 after 3.33 ns;
  clock_100 <= not clock_100 after 10   ns;

  -------------------------------------------------------------------------------------------------------------
  -- powerup resets for SIM
  test_runner_proc_clk100: process(clock_100)
  begin
    if rising_edge(clock_100) then
       -- power up reset logic
       if power_up_rst_clock_100(31) = '1' then
          power_up_rst_clock_100(31 downto 0) <= power_up_rst_clock_100(30 downto 0) & '0';
          clock_100_rst   <= '1';
          testCount_100   <= 0;
       else
          clock_100_rst   <= '0';
          testCount_100   <= testCount_100 + 1;
       end if;
    end if;
  end process;
  
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


  process
    file     datafile: text;
    variable line_in : line;
    variable good    : boolean;

    variable LFAArepeats : std_logic_vector(15 downto 0);
    variable LFAAData  : std_logic_vector(511 downto 0);
    variable LFAAvalid : std_logic_vector(3 downto 0);
    variable LFAAeop   : std_logic_vector(3 downto 0);
    variable LFAAerror : std_logic_vector(3 downto 0);
    variable LFAAempty0 : std_logic_vector(3 downto 0);
    variable LFAAempty1 : std_logic_vector(3 downto 0);
    variable LFAAempty2 : std_logic_vector(3 downto 0);
    variable LFAAempty3 : std_logic_vector(3 downto 0);
    variable LFAAsop    : std_logic_vector(3 downto 0);
  begin
    LFAADone         <= '0';	  
    s_axi_data       <= (others => '0');
    s_axi_data_valid <= '0';

    wait until clock_100_rst = '0';
    wait for 1 us;

    update_rx_start_addr <= '1';
    i_lfaa_bank1_start_addr <= X"FCCCCC00";

    FILE_OPEN(datafile,data_file_name,READ_MODE);

    wait until rising_edge(clock_300);
    for i in 1 to 300 loop
      while(not endfile(datafile)) loop
        readline(datafile, line_in);
        hread(line_in,LFAArepeats,good);
        hread(line_in,LFAAData,good);
        hread(line_in,LFAAvalid,good);
        hread(line_in,LFAAeop,good);
        hread(line_in,LFAAerror,good);
        hread(line_in,LFAAempty0,good);
        hread(line_in,LFAAempty1,good);
        hread(line_in,LFAAempty2,good);
        hread(line_in,LFAAempty3,good);
        hread(line_in,LFAAsop,good);

        if LFAAeop = "1000" then
	   s_axi_data       <= LFAAData;
           s_axi_data_valid <= '1';
           wait until rising_edge(clock_300);
           s_axi_data       <= (others => '0');
           s_axi_data_valid <= '0';
	   wait until rising_edge(clock_300);
	   wait until rising_edge(clock_300);
	   wait until rising_edge(clock_300);
           wait until rising_edge(clock_300);
	   wait until rising_edge(clock_300);
           wait until rising_edge(clock_300); 
        elsif LFAAvalid = "1111" then
	   s_axi_data       <= LFAAData;
	   s_axi_data_valid <= '1';
           wait until rising_edge(clock_300);
        end if;
	report "i=" & integer'image(i);
      end loop;
      if i=2 then
         for j in 1 to 300 loop
      	     wait until rising_edge(clock_300);
         end loop;	
      end if;	 
      file_close(datafile);
      file_open(datafile, data_file_name, read_mode);
    end loop;
    LFAADone <= '1';
    wait for 50 us;
    report "simulation successfully finished";
    finish;
  end process;

  DUT : entity HBM_PktController_lib.HBM_PktController
  port map(
           clk_freerun                       => clock_100,
           -- shared memory interface clock (300 MHz)
           i_shared_clk                      => clock_300,
           i_shared_rst                      => clock_300_rst, 

           o_reset_packet_player             => i_reset_packet_player,
           ------------------------------------------------------------------------------------
           -- Data from CMAC module after CDC in shared memory clock domain
           i_data_from_cmac                  => s_axi_data,
           i_data_valid_from_cmac            => s_axi_data_valid,

           ------------------------------------------------------------------------------------
           -- config and status registers interface
           -- rx
           i_rx_packet_size                  => "10000001000000", --9024bytes 
           i_rx_soft_reset                   => '0', 
           i_enable_capture                  => '1',

           i_lfaa_bank1_addr                 => i_lfaa_bank1_start_addr,
           i_lfaa_bank2_addr                 => i_lfaa_bank2_start_addr,
           i_lfaa_bank3_addr                 => i_lfaa_bank3_start_addr,
           i_lfaa_bank4_addr                 => i_lfaa_bank4_start_addr,
           update_start_addr                 => update_rx_start_addr, 

           o_1st_4GB_rx_addr                 => open,
           o_2nd_4GB_rx_addr                 => open,
           o_3rd_4GB_rx_addr                 => open,
           o_4th_4GB_rx_addr                 => open,

           o_capture_done                    => open,
           o_num_packets_received            => open,

           -- tx
           i_tx_packet_size                  => "10000001000000", --2176bytes 
           i_start_tx                        => '0',
           i_loop_tx                         => '0',
           i_expected_total_number_of_4k_axi => X"00000007", 
           i_expected_number_beats_per_burst => "0000110100110",
           i_expected_beats_per_packet       => X"0000008D",
           i_expected_packets_per_burst      => X"00000003",
           i_expected_total_number_of_bursts => X"00000001",
           i_expected_number_of_loops        => (others=>'0'),
           i_time_between_bursts_ns          => X"000000C8", 

           o_tx_addr                         => open,
           o_tx_boundary_across_num          => open,
           o_axi_rvalid_but_fifo_full        => open,
           ------------------------------------------------------------------------------------
           -- Data output, to the packetizer
           -- Add the packetizer records here
           o_packetiser_data_in_wr           => packetiser_data_in_wr,
           o_packetiser_data                 => packetiser_data,
           o_packetiser_bytes_to_transmit    => packetiser_bytes_to_transmit,
           i_packetiser_data_to_player_rdy   => packetiser_data_to_player_rdy,

           i_schedule_action                 => (others => '0'),

           -----------------------------------------------------------------------
           --first 4GB section of AXI
           --aw bus
           m01_axi_awvalid                   => m01_awvalid,
           m01_axi_awready                   => m01_awready,
           m01_axi_awaddr                    => m01_awaddr,
           m01_axi_awlen                     => m01_awlen,
           --w bus
           m01_axi_wvalid                    => m01_wvalid,
           m01_axi_wdata                     => m01_wdata,
           m01_axi_wstrb                     => m01_wstrb,
           m01_axi_wlast                     => m01_wlast,
           m01_axi_wready                    => m01_wready,

           -- ar bus - read address
           m01_axi_arvalid                   => m01_arvalid,
           m01_axi_arready                   => m01_arready,
           m01_axi_araddr                    => m01_araddr,
           m01_axi_arlen                     => m01_arlen,
           -- r bus - read data
           m01_axi_rvalid                    => m01_rvalid,
           m01_axi_rready                    => m01_rready,
           m01_axi_rdata                     => m01_rdata,
           m01_axi_rlast                     => m01_rlast,
           m01_axi_rresp                     => m01_rresp,
	
	   -----------------------------------------------------------------------
           --second 4GB section of AXI
           --aw bus
           m02_axi_awvalid                   => m02_awvalid,
           m02_axi_awready                   => m02_awready,
           m02_axi_awaddr                    => m02_awaddr,
           m02_axi_awlen                     => m02_awlen,
           --w bus
           m02_axi_wvalid                    => m02_wvalid,
           m02_axi_wdata                     => m02_wdata,
           m02_axi_wstrb                     => m02_wstrb,
           m02_axi_wlast                     => m02_wlast,
           m02_axi_wready                    => m02_wready,

           -- ar bus - read address
           m02_axi_arvalid                   => m02_arvalid,
           m02_axi_arready                   => m02_arready,
           m02_axi_araddr                    => m02_araddr,
           m02_axi_arlen                     => m02_arlen,
           -- r bus - read data
           m02_axi_rvalid                    => m02_rvalid,
           m02_axi_rready                    => m02_rready,
           m02_axi_rdata                     => m02_rdata,
           m02_axi_rlast                     => m02_rlast,
           m02_axi_rresp                     => m02_rresp,
 
           -----------------------------------------------------------------------
           --third 4GB section of AXI
           --aw bus
           m03_axi_awvalid                   => m03_awvalid,
           m03_axi_awready                   => m03_awready,
           m03_axi_awaddr                    => m03_awaddr,
           m03_axi_awlen                     => m03_awlen,
           --w bus
           m03_axi_wvalid                    => m03_wvalid,
           m03_axi_wdata                     => m03_wdata,
           m03_axi_wstrb                     => m03_wstrb,
           m03_axi_wlast                     => m03_wlast,
           m03_axi_wready                    => m03_wready,

           -- ar bus - read address
           m03_axi_arvalid                   => m03_arvalid,
           m03_axi_arready                   => m03_arready,
           m03_axi_araddr                    => m03_araddr,
           m03_axi_arlen                     => m03_arlen,
           -- r bus - read data
           m03_axi_rvalid                    => m03_rvalid,
           m03_axi_rready                    => m03_rready,
           m03_axi_rdata                     => m03_rdata,
           m03_axi_rlast                     => m03_rlast,
           m03_axi_rresp                     => m03_rresp,
		   
           -----------------------------------------------------------------------
           --third 4GB section of AXI
           --aw bus
           m04_axi_awvalid                   => m04_awvalid,
           m04_axi_awready                   => m04_awready,
           m04_axi_awaddr                    => m04_awaddr,
           m04_axi_awlen                     => m04_awlen,
           --w bus
           m04_axi_wvalid                    => m04_wvalid,
           m04_axi_wdata                     => m04_wdata,
           m04_axi_wstrb                     => m04_wstrb,
           m04_axi_wlast                     => m04_wlast,
           m04_axi_wready                    => m04_wready,

           -- ar bus - read address
           m04_axi_arvalid                   => m04_arvalid,
           m04_axi_arready                   => m04_arready,
           m04_axi_araddr                    => m04_araddr,
           m04_axi_arlen                     => m04_arlen,
           -- r bus - read data
           m04_axi_rvalid                    => m04_rvalid,
           m04_axi_rready                    => m04_rready,
           m04_axi_rdata                     => m04_rdata,
           m04_axi_rlast                     => m04_rlast,
           m04_axi_rresp                     => m04_rresp
       );
	
      i_packet_player : entity PSR_Packetiser_lib.packet_player
        Generic Map(
            LBUS_TO_CMAC_INUSE      => false,      -- FUTURE WORK to IMPLEMENT AXI
            PLAYER_CDC_FIFO_DEPTH   => 512
            -- FIFO is 512 Wide, 9KB packets = 73728 bits, 512 * 256 = 131072, 256 depth allows ~1.88 9K packets, we are target packets sizes smaller than this.
        )
        Port map (
            i_clk400                => clock_300,
            i_reset_400             => i_reset_packet_player,

            i_cmac_clk              => clock_100,
            i_cmac_clk_rst          => clock_100_rst,

            i_bytes_to_transmit     => packetiser_bytes_to_transmit, 
            i_data_to_player        => packetiser_data,
            i_data_to_player_wr     => packetiser_data_in_wr,
            o_data_to_player_rdy    => packetiser_data_to_player_rdy,

            o_cmac_ready            => open,

            -- traffic stats
            o_time_between_packets_largest  => open,
            o_bytes_transmitted_last_hsec   => open,

            -- streaming AXI to CMAC
            o_tx_axis_tdata         => open,
            o_tx_axis_tkeep         => open,
            o_tx_axis_tvalid        => open,
            o_tx_axis_tlast         => open,
            o_tx_axis_tuser         => open,
            i_tx_axis_tready        => '1',

            -- LBUS to CMAC
            o_data_to_transmit      => open,
            i_data_to_transmit_ctl  => (others=>'0')
        );



  HBM4G_1 : entity HBM_PktController_lib.HBM_axi_tbModel
    generic map (
        AXI_ADDR_WIDTH => 32, 
        AXI_ID_WIDTH => 1, 
        AXI_DATA_WIDTH => 512, 
        READ_QUEUE_SIZE => 16, 
        MIN_LAG => 60,    
        INCLUDE_PROTOCOL_CHECKER => TRUE,
        RANDSEED => 43526,             -- natural := 12345;
        LATENCY_LOW_PROBABILITY => 60, -- natural := 95;  -- probability, as a percentage, that non-zero gaps between read beats will be small (i.e. < 3 clocks)
        LATENCY_ZERO_PROBABILITY => 60 -- natural := 80   -- probability, as a percentage, that the gap between read beats will be zero.
    ) Port map (
        i_clk          => clock_300,
        i_rst_n        => not clock_300_rst, 
        axi_awaddr     => m01_awaddr(31 downto 0),
        axi_awid       => "0", 
        axi_awlen      => m01_awlen,
        axi_awsize     => "110",
        axi_awburst    => "01", 
        axi_awlock     => "00",  
        axi_awcache    => "0011", 
        axi_awprot     => "000",
        axi_awqos      => "0000", 
        axi_awregion   => "0000",
        axi_awvalid    => m01_awvalid, 
        axi_awready    => m01_awready, 
        axi_wdata      => m01_wdata, 
        axi_wstrb      => m01_wstrb,
        axi_wlast      => m01_wlast,
        axi_wvalid     => m01_wvalid,
        axi_wready     => m01_wready,
        axi_bresp      => open,
        axi_bvalid     => open,
        axi_bready     => '1', 
        axi_bid        => open,
        axi_araddr     => m01_araddr(31 downto 0),
        axi_arlen      => m01_arlen,
        axi_arsize     => m01_arsize,
        axi_arburst    => m01_arburst,
        axi_arlock     => "00",
        axi_arcache    => "0011",
        axi_arprot     => "000",
        axi_arvalid    => m01_arvalid,
        axi_arready    => m01_arready,
        axi_arqos      => "0000",
        axi_arid       => "0",
	axi_arregion   => "0000",
        axi_rdata      => m01_rdata,
        axi_rresp      => m01_rresp,
        axi_rlast      => m01_rlast,
        axi_rvalid     => m01_rvalid,
        axi_rready     => m01_rready
    );


    HBM4G_2 : entity HBM_PktController_lib.HBM_axi_tbModel
    generic map (
        AXI_ADDR_WIDTH => 32,
        AXI_ID_WIDTH => 1,
        AXI_DATA_WIDTH => 512,
        READ_QUEUE_SIZE => 16,
        MIN_LAG => 60,
        INCLUDE_PROTOCOL_CHECKER => TRUE,
        RANDSEED => 43526,             -- natural := 12345;
        LATENCY_LOW_PROBABILITY => 95, -- natural := 95;  -- probability, as a percentage, that non-zero gaps between read beats will be small (i.e. < 3 clocks)
        LATENCY_ZERO_PROBABILITY => 80 -- natural := 80   -- probability, as a percentage, that the gap between read beats will be zero.
    ) Port map (
        i_clk          => clock_300,
        i_rst_n        => not clock_300_rst,
        axi_awaddr     => m02_awaddr(31 downto 0),
        axi_awid       => "0",
        axi_awlen      => m02_awlen,
        axi_awsize     => "110",
        axi_awburst    => "01",
        axi_awlock     => "00",
        axi_awcache    => "0011",
        axi_awprot     => "000",
        axi_awqos      => "0000",
        axi_awregion   => "0000",
        axi_awvalid    => m02_awvalid,
        axi_awready    => m02_awready,
        axi_wdata      => m02_wdata,
        axi_wstrb      => m02_wstrb,
        axi_wlast      => m02_wlast,
        axi_wvalid     => m02_wvalid,
        axi_wready     => m02_wready,
        axi_bresp      => open,
        axi_bvalid     => open,
        axi_bready     => '1',
        axi_bid        => open,
        axi_araddr     => m02_araddr(31 downto 0),
        axi_arlen      => m02_arlen,
        axi_arsize     => m02_arsize,
        axi_arburst    => m02_arburst,
        axi_arlock     => "00",
        axi_arcache    => "0011",
        axi_arprot     => "000",
        axi_arvalid    => m02_arvalid,
        axi_arready    => m02_arready,
        axi_arqos      => "0000",
        axi_arid       => "0",
        axi_arregion   => "0000",
        axi_rdata      => m02_rdata,
        axi_rresp      => m02_rresp,
        axi_rlast      => m02_rlast,
        axi_rvalid     => m02_rvalid,
        axi_rready     => m02_rready
    );


    HBM4G_3 : entity HBM_PktController_lib.HBM_axi_tbModel
    generic map (
        AXI_ADDR_WIDTH => 32,
        AXI_ID_WIDTH => 1,
        AXI_DATA_WIDTH => 512,
        READ_QUEUE_SIZE => 16,
        MIN_LAG => 60,
        INCLUDE_PROTOCOL_CHECKER => TRUE,
        RANDSEED => 43526,             -- natural := 12345;
        LATENCY_LOW_PROBABILITY => 95, -- natural := 95;  -- probability, as a percentage, that non-zero gaps between read beats will be small (i.e. < 3 clocks)
        LATENCY_ZERO_PROBABILITY => 80 -- natural := 80   -- probability, as a percentage, that the gap between read beats will be zero.
    ) Port map (
        i_clk          => clock_300,
        i_rst_n        => not clock_300_rst,
        axi_awaddr     => m03_awaddr(31 downto 0),
        axi_awid       => "0",
        axi_awlen      => m03_awlen,
        axi_awsize     => "110",
        axi_awburst    => "01",
        axi_awlock     => "00",
        axi_awcache    => "0011",
        axi_awprot     => "000",
        axi_awqos      => "0000",
        axi_awregion   => "0000",
        axi_awvalid    => m03_awvalid,
        axi_awready    => m03_awready,
        axi_wdata      => m03_wdata,
        axi_wstrb      => m03_wstrb,
        axi_wlast      => m03_wlast,
        axi_wvalid     => m03_wvalid,
        axi_wready     => m03_wready,
        axi_bresp      => open,
        axi_bvalid     => open,
        axi_bready     => '1',
        axi_bid        => open,
        axi_araddr     => m03_araddr(31 downto 0),
        axi_arlen      => m03_arlen,
        axi_arsize     => m03_arsize,
        axi_arburst    => m03_arburst,
        axi_arlock     => "00",
        axi_arcache    => "0011",
        axi_arprot     => "000",
        axi_arvalid    => m03_arvalid,
        axi_arready    => m03_arready,
        axi_arqos      => "0000",
        axi_arid       => "0",
        axi_arregion   => "0000",
        axi_rdata      => m03_rdata,
        axi_rresp      => m03_rresp,
        axi_rlast      => m03_rlast,
        axi_rvalid     => m03_rvalid,
        axi_rready     => m03_rready
    );


    HBM4G_4 : entity HBM_PktController_lib.HBM_axi_tbModel
    generic map (
        AXI_ADDR_WIDTH => 32,
        AXI_ID_WIDTH => 1,
        AXI_DATA_WIDTH => 512,
        READ_QUEUE_SIZE => 16,
        MIN_LAG => 60,
        INCLUDE_PROTOCOL_CHECKER => TRUE,
        RANDSEED => 43526,             -- natural := 12345;
        LATENCY_LOW_PROBABILITY => 95, -- natural := 95;  -- probability, as a percentage, that non-zero gaps between read beats will be small (i.e. < 3 clocks)
        LATENCY_ZERO_PROBABILITY => 80 -- natural := 80   -- probability, as a percentage, that the gap between read beats will be zero.
    ) Port map (
        i_clk          => clock_300,
        i_rst_n        => not clock_300_rst,
        axi_awaddr     => m04_awaddr(31 downto 0),
        axi_awid       => "0",
        axi_awlen      => m04_awlen,
        axi_awsize     => "110",
        axi_awburst    => "01",
        axi_awlock     => "00",
        axi_awcache    => "0011",
        axi_awprot     => "000",
        axi_awqos      => "0000",
        axi_awregion   => "0000",
        axi_awvalid    => m04_awvalid,
        axi_awready    => m04_awready,
        axi_wdata      => m04_wdata,
        axi_wstrb      => m04_wstrb,
        axi_wlast      => m04_wlast,
        axi_wvalid     => m04_wvalid,
        axi_wready     => m04_wready,
        axi_bresp      => open,
        axi_bvalid     => open,
        axi_bready     => '1',
        axi_bid        => open,
        axi_araddr     => m04_araddr(31 downto 0),
        axi_arlen      => m04_arlen,
        axi_arsize     => m04_arsize,
        axi_arburst    => m04_arburst,
        axi_arlock     => "00",
        axi_arcache    => "0011",
        axi_arprot     => "000",
        axi_arvalid    => m04_arvalid,
        axi_arready    => m04_arready,
        axi_arqos      => "0000",
        axi_arid       => "0",
        axi_arregion   => "0000",
        axi_rdata      => m04_rdata,
        axi_rresp      => m04_rresp,
        axi_rlast      => m04_rlast,
        axi_rvalid     => m04_rvalid,
        axi_rready     => m04_rready
    );

end Behavioral;
