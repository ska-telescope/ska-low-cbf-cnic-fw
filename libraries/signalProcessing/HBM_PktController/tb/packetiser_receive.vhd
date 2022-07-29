----------------------------------------------------------------------------------
-- Company:  CSIRO
-- Engineer: Jonathan Li (jonathan.li@csiro.au)
-- 
-- Create Date:    27/07/2022 
-- Module Name:    packetiser_receive - Behavioral 
-- Description: 
--   Logs data from a packet interface to a file.
--
--
-- Output text file format matches the input file format used for the atomic cots testbench "tb_vitisAccelCore":
--  hread(line_in,LFAArepeats,good);
--  hread(line_in,LFAAData,good);
--  hread(line_in,LFAAvalid,good);
--  hread(line_in,LFAAeop,good);
--  hread(line_in,LFAAerror,good);
--  hread(line_in,LFAAempty0,good);
--  hread(line_in,LFAAempty1,good);
--  hread(line_in,LFAAempty2,good);
--  hread(line_in,LFAAempty3,good);
--  hread(line_in,LFAAsop,good);
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

use std.textio.all;
use IEEE.std_logic_textio.all;
use std.env.finish;

entity packetiser_receive is
   Port ( 
      clk     : in  std_logic;     -- clock
      i_din   : in  std_logic_vector(511 downto 0);  -- actual data out.
      i_valid : in  std_logic                        -- data out valid (high for duration of the packet)
   );
end packetiser_receive;

architecture Behavioral of packetiser_receive is

  constant  data_file_name           : string := "LFAA100GE_tb_data_backup.txt"; 	

  function vec2str(vec: std_logic_vector) return string is
    variable result: string(vec'left + 1 downto 1);
  begin
    for i in vec'reverse_range loop
        if (vec(i) = '1') then
           result(i + 1) := '1';
        elsif (vec(i) = '0') then
           result(i + 1) := '0';
        else
           result(i + 1) := 'X';
        end if;
    end loop;
    return result;
  end;

begin

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
    variable line_no    : integer := 0;
    variable expect_packet_count : integer := 1; 
    variable valid_asserted : std_logic;
  begin

    FILE_OPEN(datafile,data_file_name,READ_MODE);	  

    loop    
      wait until rising_edge(clk);
      if i_valid = '1' then
	 line_no := line_no + 1;     
	 valid_asserted := '1';
	 if (not endfile(datafile)) then
            readline(datafile, line_in);
            hread(line_in,LFAArepeats,good);
            hread(line_in,LFAAData,   good);
            hread(line_in,LFAAvalid,  good);
            hread(line_in,LFAAeop,    good);
            hread(line_in,LFAAerror,  good);
            hread(line_in,LFAAempty0, good);
            hread(line_in,LFAAempty1, good);
            hread(line_in,LFAAempty2, good);
            hread(line_in,LFAAempty3, good);
            hread(line_in,LFAAsop,    good);
	   
	    assert LFAAData = i_din 
	    report "there is data comparison failure, expected data is " & vec2str(LFAAData) & 
	           "actual data is "    & vec2str(i_din)      & 
		   "happen at line"     & integer'image(line_no) &
		   "expected packet is" & integer'image(expect_packet_count) severity failure;
         else
           report "simulation successfully finished";		
	   finish;
	 end if; 
      else
	 if valid_asserted = '1' then
	    valid_asserted := '0';
            expect_packet_count := expect_packet_count + 1;
         end if;	    
      end if;	       
    end loop;
    wait;
  end process;


end Behavioral;

