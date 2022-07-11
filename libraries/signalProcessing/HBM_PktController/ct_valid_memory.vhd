----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: David Humphrey (dave.humphrey@csiro.au)
-- 
-- Create Date: 29.09.2020 11:24:19
-- Module Name: ct_valid_memory - Behavioral
-- Description: 
--   Valid Memory.
--   Keeps track of which blocks of 8192 bytes in the HBM are valid.
--   1Gbyte/8192 bytes = 2^30/2^13 = 2^17 locations
--   Uses 4 BRAMs.
--   The BRAM has two ports. 
--     - "set" and "clear" share one port. Set has priority. 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ct_valid_memory is
    port (
        i_clk  : in std_logic;
        i_rst  : in std_logic;
        o_rstActive : out std_logic; -- high for 4096 clocks after a rising edge on i_rst.
        -- Set valid
        i_setAddr  : in std_logic_vector(16 downto 0); 
        i_setValid : in std_logic;  -- There must be at least one idle clock between set requests.
        o_duplicate : out std_logic;
        -- clear valid
        i_clearAddr : in std_logic_vector(16 downto 0);
        i_clearValid : in std_logic; -- There must be at least one idle clock between clear requests.
        -- Read contents, fixed 3 clock latency
        i_readAddr : in std_logic_vector(16 downto 0);
        o_readData : out std_logic
    );
end ct_valid_memory;

architecture Behavioral of ct_valid_memory is

    component ct_valid_bram
    port(
        clka  : in std_logic;
        wea   : in std_logic_vector(0 downto 0);
        addra : in std_logic_vector(16 downto 0);
        dina  : in std_logic_vector(0 downto 0);
        douta : out std_logic_vector(0 downto 0);
        clkb  : in std_logic;
        web   : in std_logic_vector(0 downto 0);
        addrb : in std_logic_vector(16 downto 0);
        dinb  : in std_logic_vector(31 downto 0);
        doutb : out std_logic_vector(0 downto 0));
    end component;

    signal wea : std_logic_vector(0 downto 0);
    signal addra : std_logic_vector(16 downto 0);
    signal dina : std_logic_vector(0 downto 0);
    signal clearPending : std_logic := '0';
    signal clearAddr : std_logic_vector(16 downto 0) := (others => '0');    

    signal doutb : std_logic_vector(0 downto 0);
    signal dinb : std_logic_vector(31 downto 0);
    signal web : std_logic_vector(0 downto 0);
    signal addrb : std_logic_vector(16 downto 0);
    signal rstDel1, rstDel2 : std_logic;
    signal rstActive : std_logic := '0';
    signal douta : std_logic_vector(0 downto 0);

    signal setValidDel1, setValidDel2, setValidDel3 : std_logic;
    
begin

    -- Set and clear requests can clash, but will never be back-to-back, so we just need a single register to hold over 
    -- a set request to the next clock cycle.
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                wea(0) <= '0';
                addra <= (others => '0');
                dina(0) <= '0';
            elsif i_setValid = '1' then
                wea(0) <= '1';
                addra <= i_setAddr;
                dina(0) <= '1';
                if i_clearValid = '1' then  -- Clear request happened on the same cycle, so store it for the next clock.
                    clearPending <= '1';
                    clearAddr <= i_clearAddr;
                end if;
            elsif i_clearValid = '1' then
                wea(0) <= '1';
                addra <= i_clearAddr;
                dina(0) <= '0';
            elsif clearPending = '1' then
                clearPending <= '0';
                wea(0) <= '1';
                addra <= clearAddr;
                dina(0) <= '0';
            else
                wea(0) <= '0';
            end if;
            
            rstDel1 <= i_rst;
            rstDel2 <= rstDel1;
            if rstDel1 = '1' and rstDel2 = '0' then -- rising edge of reset
                addrb <= (others => '0');
                rstActive <= '1';
                web(0) <= '1';
            elsif rstActive = '1' then
                addrb <= std_logic_vector(unsigned(addrb) + 32); -- high order bits of the address for writing 32-bit wide words
                if addrb(16 downto 5) = "111111111111" then
                    rstActive <= '0';
                    web(0) <= '0';
                end if;
            else
                addrb <= i_readAddr;
                web(0) <= '0';
            end if;
            
            o_rstActive <= i_rst or rstDel1 or rstDel2 or rstActive;
            
            -- report duplicates
            setValidDel1 <= i_setValid;
            setValidDel2 <= setValidDel1;
            setValidDel3 <= setValidDel2;
            if setValidDel3 = '1' and douta(0) = '1' then
                o_duplicate <= '1';
            else
                o_duplicate <= '0';
            end if;
        end if;
    end process;


    meminst : ct_valid_bram
    port map (
        -- Port A, used for writing. 1 bit wide x 131072 deep
        clka  => i_clk,
        wea   => wea,
        addra => addra,
        dina  => dina,
        douta => douta,
        -- port b, used for reading. Also used to reset the memory contents at startup.
        -- When writing, this is 32 bits wide x 4096 deep (12 bit address)
        -- When reading, 1 bit wide x 131072 bits deep (17 bit address)
        clkb  => i_clk,
        web   => web,
        addrb => addrb,
        dinb  => dinb,
        doutb => doutb
    );
    dinb <= (others => '0'); -- only used to reset the memory.
    o_readData <= doutb(0);
end Behavioral;
