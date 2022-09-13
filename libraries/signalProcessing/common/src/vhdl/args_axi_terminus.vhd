----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: Sept 2022 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- ARGS to local RAM wrapper.
-- Used to terminate AXI bus, and return custom value.
-- 
----------------------------------------------------------------------------------

library IEEE, axi4_lib, xpm, common_lib, technology_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use xpm.vcomponents.all;
USE common_lib.common_pkg.ALL;
use axi4_lib.axi4_stream_pkg.ALL;
use axi4_lib.axi4_lite_pkg.ALL;
use axi4_lib.axi4_full_pkg.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity args_axi_terminus is
    Port ( 
        -- ARGS interface
        -- MACE clock is 300 MHz
        i_MACE_clk                          : in std_logic;
        i_MACE_rst                          : in std_logic;
                
--        i_args_axi_terminus_Lite_axi_mosi   : in t_axi4_lite_mosi; 
--        o_args_axi_terminus_Lite_axi_miso   : out t_axi4_lite_miso;     
        
        i_args_axi_terminus_full_axi_mosi   : in  t_axi4_full_mosi;
        o_args_axi_terminus_full_axi_miso   : out t_axi4_full_miso
        

    );
end args_axi_terminus;

architecture rtl of args_axi_terminus is
COMPONENT axi_bram_ctrl_1k IS
  PORT (
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    s_axi_awaddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_awlock : IN STD_LOGIC;
    s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_wlast : IN STD_LOGIC;
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_araddr : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_arlock : IN STD_LOGIC;
    s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rlast : OUT STD_LOGIC;
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC;
    bram_rst_a : OUT STD_LOGIC;
    bram_clk_a : OUT STD_LOGIC;
    bram_en_a : OUT STD_LOGIC;
    bram_we_a : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    bram_addr_a : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
    bram_wrdata_a : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    bram_rddata_a : IN STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT; 

signal bram_rst                 : STD_LOGIC;
signal bram_clk                 : STD_LOGIC;
signal bram_en                  : STD_LOGIC;
signal bram_we_byte             : STD_LOGIC_VECTOR(3 DOWNTO 0);
signal bram_addr                : STD_LOGIC_VECTOR(11 DOWNTO 0);
signal bram_wrdata              : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal bram_rddata              : STD_LOGIC_VECTOR(31 DOWNTO 0);

signal MACE_rst_n               : std_logic;


begin

MACE_rst_n  <= NOT i_MACE_rst;

ARGS_AXI_BRAM : axi_bram_ctrl_1k
PORT MAP (
    s_axi_aclk      => i_MACE_clk,
    s_axi_aresetn   => MACE_rst_n, -- in std_logic;
    s_axi_awaddr    => i_args_axi_terminus_full_axi_mosi.awaddr(11 downto 0),
    s_axi_awlen     => i_args_axi_terminus_full_axi_mosi.awlen,
    s_axi_awsize    => i_args_axi_terminus_full_axi_mosi.awsize,
    s_axi_awburst   => i_args_axi_terminus_full_axi_mosi.awburst,
    s_axi_awlock    => i_args_axi_terminus_full_axi_mosi.awlock ,
    s_axi_awcache   => i_args_axi_terminus_full_axi_mosi.awcache,
    s_axi_awprot    => i_args_axi_terminus_full_axi_mosi.awprot,
    s_axi_awvalid   => i_args_axi_terminus_full_axi_mosi.awvalid,
    s_axi_awready   => o_args_axi_terminus_full_axi_miso.awready,
    s_axi_wdata     => i_args_axi_terminus_full_axi_mosi.wdata(31 downto 0),
    s_axi_wstrb     => i_args_axi_terminus_full_axi_mosi.wstrb(3 downto 0),
    s_axi_wlast     => i_args_axi_terminus_full_axi_mosi.wlast,
    s_axi_wvalid    => i_args_axi_terminus_full_axi_mosi.wvalid,
    s_axi_wready    => o_args_axi_terminus_full_axi_miso.wready,
    s_axi_bresp     => o_args_axi_terminus_full_axi_miso.bresp,
    s_axi_bvalid    => o_args_axi_terminus_full_axi_miso.bvalid,
    s_axi_bready    => i_args_axi_terminus_full_axi_mosi.bready ,
    s_axi_araddr    => i_args_axi_terminus_full_axi_mosi.araddr(11 downto 0),
    s_axi_arlen     => i_args_axi_terminus_full_axi_mosi.arlen,
    s_axi_arsize    => i_args_axi_terminus_full_axi_mosi.arsize,
    s_axi_arburst   => i_args_axi_terminus_full_axi_mosi.arburst,
    s_axi_arlock    => i_args_axi_terminus_full_axi_mosi.arlock ,
    s_axi_arcache   => i_args_axi_terminus_full_axi_mosi.arcache,
    s_axi_arprot    => i_args_axi_terminus_full_axi_mosi.arprot,
    s_axi_arvalid   => i_args_axi_terminus_full_axi_mosi.arvalid,
    s_axi_arready   => o_args_axi_terminus_full_axi_miso.arready,
    s_axi_rdata     => o_args_axi_terminus_full_axi_miso.rdata(31 downto 0),
    s_axi_rresp     => o_args_axi_terminus_full_axi_miso.rresp,
    s_axi_rlast     => o_args_axi_terminus_full_axi_miso.rlast,
    s_axi_rvalid    => o_args_axi_terminus_full_axi_miso.rvalid,
    s_axi_rready    => i_args_axi_terminus_full_axi_mosi.rready,

    bram_rst_a      => bram_rst,
    bram_clk_a      => bram_clk,
    bram_en_a       => bram_en,     --: OUT STD_LOGIC;
    bram_we_a       => bram_we_byte,     --: OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    bram_addr_a     => bram_addr,   --: OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
    bram_wrdata_a   => bram_wrdata, --: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    bram_rddata_a   => bram_rddata  --: IN STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
  

bram_rddata <= x"50505050";


end rtl;
