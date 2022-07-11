----------------------------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
----------------------------------------------------------------------------------------------------
--
-- Based on Version 1.1 of the Spec from 16 August 2021
--
----------------------------------------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

PACKAGE CodifHeader_pkg IS

TYPE small_fields IS RECORD
     Sample_Representation                  : std_logic_vector(3 downto 0);
     Cal_Enabled                            : STD_LOGIC;
     Complex                                : STD_LOGIC;
     Invalid                                : STD_LOGIC;
     Atypical                               : STD_LOGIC;
     Protocol                               : std_logic_vector(2 downto 0);
     Version                                : std_logic_vector(4 downto 0);
END RECORD;

-- Constructed in transmission order... based on Version 1.1 Doc dated 16 August 2021.
TYPE CodifHeader IS RECORD
    -- Word 0
    data_frame                              : STD_LOGIC_VECTOR(31 DOWNTO 0);
    epoch_offset                            : STD_LOGIC_VECTOR(31 DOWNTO 0);
    -- Word 1
    reference_epoch                         : STD_LOGIC_VECTOR(7 DOWNTO 0);
    sample_size                             : STD_LOGIC_VECTOR(7 DOWNTO 0);
    small_fields                            : small_fields;                     -- 15:   = Not Voltage
                                                                                -- 14   = Invalid
                                                                                -- 13   = Complex
                                                                                -- 12   = Cal Enabled
                                                                                -- 11:8 = Sample Representation
                                                                                -- 7:3  = Version
                                                                                -- 2:0  = Protocol
    
    reserved_field                          : STD_LOGIC_VECTOR(15 DOWNTO 0);
    alignment_period                        : STD_LOGIC_VECTOR(15 DOWNTO 0);    
    -- Word 2
    thread_ID                               : STD_LOGIC_VECTOR(15 DOWNTO 0);
    group_ID                                : STD_LOGIC_VECTOR(15 DOWNTO 0);
    secondary_ID                            : STD_LOGIC_VECTOR(15 DOWNTO 0);
    station_ID                              : STD_LOGIC_VECTOR(15 DOWNTO 0);    
    -- Word 3
    channels                                : STD_LOGIC_VECTOR(15 DOWNTO 0);
    sample_block_length                     : STD_LOGIC_VECTOR(15 DOWNTO 0);
    data_array_length                       : STD_LOGIC_VECTOR(31 DOWNTO 0);    
    -- Word 4    
    sample_periods_per_alignment_period     : STD_LOGIC_VECTOR(63 DOWNTO 0);
    -- Word 5
    synchronisation_sequence                : STD_LOGIC_VECTOR(31 DOWNTO 0);
    metadata_ID                             : STD_LOGIC_VECTOR(15 DOWNTO 0);
    metadata_bits_lower                     : STD_LOGIC_VECTOR(15 DOWNTO 0);    
    -- Word 6
    metadata_bits_mid                       : STD_LOGIC_VECTOR(63 DOWNTO 0);
    -- Word 7 
    metadata_bits_upper                     : STD_LOGIC_VECTOR(63 DOWNTO 0);   
END RECORD;

constant null_small_fields : small_fields := (
                             Atypical                               => '0',
                             Invalid                                => '0',
                             Complex                                => '0',
                             Cal_Enabled                            => '0',
                             Sample_Representation                  => (others => '0'),
                             Version                                => (others => '0'),
                             Protocol                               => (others => '0')
                             );


constant null_CodifHeader : CodifHeader := (
                                data_frame                              => (others => '0'),
                                epoch_offset                            => (others => '0'),
                                reference_epoch                         => (others => '0'),
                                sample_size                             => (others => '0'),
                                small_fields                            => null_small_fields,
                                reserved_field                          => (others => '0'),    
                                alignment_period                        => (others => '0'),
                                thread_ID                               => (others => '0'),
                                group_ID                                => (others => '0'),
                                secondary_ID                            => (others => '0'),
                                station_ID                              => (others => '0'),
                                channels                                => (others => '0'),                                
                                sample_block_length                     => (others => '0'),
                                data_array_length                       => (others => '0'),
                                sample_periods_per_alignment_period     => (others => '0'),
                                synchronisation_sequence                => (others => '0'),
                                metadata_ID                             => (others => '0'),
                                metadata_bits_upper                     => (others => '0'),
                                metadata_bits_mid                       => (others => '0'),
                                metadata_bits_lower                     => (others => '0')
                                );


constant default_small_fields : small_fields := (
                             Atypical                               => '0',
                             Invalid                                => '0',
                             Complex                                => '0',
                             Cal_Enabled                            => '0',
                             Sample_Representation                  => (others => '0'),
                             Version                                => "00011",      -- VERSION 3
                             Protocol                               => "111"
                             );
                                
constant default_CodifHeader : CodifHeader := (
                                data_frame                              => x"AAAAAAAA",
                                epoch_offset                            => x"44332211",
                                reference_epoch                         => x"BB",
                                sample_size                             => x"10",
                                small_fields                            => default_small_fields,
                                reserved_field                          => (others => '0'),    
                                alignment_period                        => (others => '0'),
                                thread_ID                               => (others => '0'),
                                group_ID                                => x"BEEF",
                                secondary_ID                            => (others => '0'),
                                station_ID                              => x"DEAD",
                                channels                                => (others => '0'),                                
                                sample_block_length                     => (others => '0'),
                                data_array_length                       => (others => '0'),
                                sample_periods_per_alignment_period     => (others => '0'),
                                synchronisation_sequence                => (others => '0'),
                                metadata_ID                             => x"1D1D",
                                metadata_bits_lower                     => x"ABCD",
                                metadata_bits_mid                       => x"0123456789ABCDEF",
                                metadata_bits_upper                     => x"FEDCBA9876543210"
                                );  


                                
constant default_pulsar_CodifHeader : CodifHeader := (
                                data_frame                              => (others => '0'),
                                epoch_offset                            => (others => '0'),
                                reference_epoch                         => x"BB",
                                sample_size                             => x"10",
                                small_fields                            => default_small_fields,
                                reserved_field                          => (others => '0'),    
                                alignment_period                        => (others => '0'),
                                thread_ID                               => (others => '0'),
                                group_ID                                => x"BEEF",
                                secondary_ID                            => (others => '0'),
                                station_ID                              => x"DEAD",
                                channels                                => (others => '0'),                                
                                sample_block_length                     => (others => '0'),
                                data_array_length                       => (others => '0'),
                                sample_periods_per_alignment_period     => (others => '0'),
                                synchronisation_sequence                => (others => '0'),
                                metadata_ID                             => x"1D1D",
                                metadata_bits_lower                     => x"ABCD",
                                metadata_bits_mid                       => x"0123456789ABCDEF",
                                metadata_bits_upper                     => x"FEDCBA9876543210"
                                );                                

end CodifHeader_pkg;