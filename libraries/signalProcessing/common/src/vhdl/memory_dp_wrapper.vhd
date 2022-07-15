----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: 07/14/2022 
-- Design Name: 
-- Module Name: memory_dp_wrapper - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE, common_lib, xpm;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use common_lib.common_pkg.ALL;
use xpm.vcomponents.all;
library UNISIM;
use UNISIM.VComponents.all;


entity memory_dp_wrapper is
    GENERIC (
        g_NO_OF_ADDR_BITS   : INTEGER := 9;
        g_D_Q_WIDTH         : INTEGER := 512
    );
    Port ( 
        clk_a           : in std_logic;
        clk_b           : in std_logic;
    
        data_in         : in std_logic_vector((g_D_Q_WIDTH-1) downto 0);
        addr_in         : in std_logic_vector((g_NO_OF_ADDR_BITS-1) downto 0);
        data_in_wr      : in std_logic; 
        
        data_out        : out std_logic_vector((g_D_Q_WIDTH-1) downto 0);
        addr_out        : in std_logic_vector((g_NO_OF_ADDR_BITS-1) downto 0)
    
    );
end memory_dp_wrapper;

architecture Behavioral of memory_dp_wrapper is


CONSTANT ADDR_SPACE             : INTEGER := pow2(g_NO_OF_ADDR_BITS);
CONSTANT MEMORY_SIZE_GENERIC    : INTEGER := ADDR_SPACE * g_D_Q_WIDTH;

signal ram_wr       : std_logic_vector(0 downto 0);

begin

ram_wr(0)   <= data_in_wr;


xpm_memory_sdpram_inst : xpm_memory_sdpram
    generic map (    
        -- Common module generics
        MEMORY_SIZE             => MEMORY_SIZE_GENERIC, --262144,          -- Total memory size in bits; 512 x 512 = 262144
        MEMORY_PRIMITIVE        => "block",         --string; "auto", "distributed", "block" or "ultra" ;
        CLOCKING_MODE           => "independent_clock", --string; "common_clock", "independent_clock" 
        MEMORY_INIT_FILE        => "none",         --string; "none" or "<filename>.mem" 
        MEMORY_INIT_PARAM       => "",             --string;
        USE_MEM_INIT            => 0,              --integer; 0,1
        WAKEUP_TIME             => "disable_sleep",--string; "disable_sleep" or "use_sleep_pin" 
        MESSAGE_CONTROL         => 0,              --integer; 0,1
        ECC_MODE                => "no_ecc",       --string; "no_ecc", "encode_only", "decode_only" or "both_encode_and_decode" 
        AUTO_SLEEP_TIME         => 0,              --Do not Change
        USE_EMBEDDED_CONSTRAINT => 0,              --integer: 0,1
        MEMORY_OPTIMIZATION     => "true",          --string; "true", "false" 
    
        -- Port A module generics
        WRITE_DATA_WIDTH_A      => g_D_Q_WIDTH,             --positive integer
        BYTE_WRITE_WIDTH_A      => g_D_Q_WIDTH,             --integer; 8, 9, or WRITE_DATA_WIDTH_A value
        ADDR_WIDTH_A            => g_NO_OF_ADDR_BITS,              --positive integer
    
        -- Port B module generics
        READ_DATA_WIDTH_B       => g_D_Q_WIDTH,            --positive integer
        ADDR_WIDTH_B            => g_NO_OF_ADDR_BITS,              --positive integer
        READ_RESET_VALUE_B      => "0",            --string
        READ_LATENCY_B          => 3,              --non-negative integer
        WRITE_MODE_B            => "no_change")    --string; "write_first", "read_first", "no_change" 
    port map (
        -- Common module ports
        sleep                   => '0',
        -- Port A (Write side)
        clka                    => clk_a,  -- clock from the 100GE core; 322 MHz
        ena                     => '1',
        wea                     => ram_wr,
        addra                   => addr_in,
        dina                    => data_in,
        injectsbiterra          => '0',
        injectdbiterra          => '0',
        -- Port B (read side)
        clkb                    => clk_b,  -- This goes to a dual clock fifo to meet the external interface clock to connect to the HBM at 300 MHz.
        rstb                    => '0',
        enb                     => '1',
        regceb                  => '1',
        addrb                   => addr_out,
        doutb                   => data_out,
        sbiterrb                => open,
        dbiterrb                => open
    );


end Behavioral;
