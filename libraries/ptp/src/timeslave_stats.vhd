----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: Feb 2022
-- Design Name: 
-- Module Name: timeslave_stats
-- Dependencies: Timeslave 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE, axi4_lib, technology_lib, common_lib, signal_processing_common, Timeslave_CMAC_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE axi4_lib.axi4_stream_pkg.ALL;
USE technology_lib.tech_mac_100g_pkg.ALL;
USE common_lib.common_pkg.ALL;
use IEEE.NUMERIC_STD.ALL;

use axi4_lib.axi4_lite_pkg.ALL;
USE axi4_lib.axi4_full_pkg.ALL;
USE Timeslave_CMAC_lib.CMAC_cmac_reg_pkg.ALL;

entity timeslave_stats is
    Generic (
        CMAC_INSTANCES             : integer := 2
    );
    Port ( 
        CMAC_clk_1                  : in std_logic;
        CMAC_clk_2                  : in std_logic;
        
        ARGs_clk                    : in std_logic;
        
        cmac_reset                  : in std_logic;
    
        -- PTP Data
        PTP_time_CMAC_clk           : t_slv_80_arr(0 to (CMAC_INSTANCES-1));
        PTP_pps_CMAC_clk            : std_logic_vector((CMAC_INSTANCES-1) downto 0);
    
        PTP_time_ARGs_clk           : t_slv_80_arr(0 to (CMAC_INSTANCES-1));
        PTP_pps_ARGs_clk            : std_logic_vector((CMAC_INSTANCES-1) downto 0)
    
    
    );
end timeslave_stats;

architecture Behavioral of timeslave_stats is

COMPONENT ila_0
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
END COMPONENT;
    
begin


-------------------------------------------------------------
-- some monitoring logic to measure PPS drift after the init 90 sec line up?




-------------------------------------------------------------
PTP_compare_ila : ila_0
    port map (
        clk                     => ARGs_clk,
   	    probe0(79 downto 0)     => PTP_time_ARGs_clk(0),
   	    probe0(80)              => PTP_pps_ARGs_clk(0),
   	    probe0(99 downto 81)    => (others => '0'),
   	    probe0(179 downto 100)  => PTP_time_ARGs_clk(1),
   	    probe0(180)             => PTP_pps_ARGs_clk(1),
   	    
   	    probe0(191 downto 181)  => (others => '0')
   	);

-------------------------------------------------------------
end Behavioral;
