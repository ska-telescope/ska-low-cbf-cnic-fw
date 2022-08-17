----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: Giles Babich
-- 
-- Create Date: Mar 2022
-- Design Name: 
-- Module Name: timeslave_scheduler
-- Dependencies: Timeslave 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
--################################# 
--- - field_name        : schedule_control
--  width             : 32
--  access_mode       : RW
--  reset_value       : 0x0
--  field_description : "Multi bit control vector that will allow different operations of scheduled hardware actions.
--                       Assumes a valid future time has been set in the schedule_ptp_xxxx fields above.
--                       This register will be polled and update the operations accordingly, will throttle update operations to every 1us.
--                       Bit 0 = reset logic to be scheduled, this will run a 100us reset pulse at the start of the run.
--                       Bit 1 = start run.
--                       Bit 2 = end current run.
--                       "
--#################################
--- - field_name        : schedule_debug
--  width             : 32
--  access_mode       : RO
--  reset_value       : 0x0
--  field_description : "Feedback from hardware..
--                       Bit 0 = Running state, 1 - running ... 0 - stopped
--                       Bit 1 = waiting to reach start time
--                       Bit 2 = past start time
--                       Bit 3 = error condition"
----------------------------------------------------------------------------------

library IEEE, axi4_lib, technology_lib, common_lib, signal_processing_common, Timeslave_CMAC_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE axi4_lib.axi4_stream_pkg.ALL;
USE technology_lib.tech_mac_100g_pkg.ALL;
USE common_lib.common_pkg.ALL;
use IEEE.NUMERIC_STD.ALL;

use axi4_lib.axi4_lite_pkg.ALL;
USE axi4_lib.axi4_full_pkg.ALL;
USE Timeslave_CMAC_lib.timeslave_timeslave_reg_pkg.ALL;

entity timeslave_scheduler is
    Generic (
        DEBUG_ILA                   : BOOLEAN := FALSE
    );
    Port ( 
        i_CMAC_clk                  : in std_logic;
        i_cmac_reset                : in std_logic;
        
        i_ARGs_clk                  : in std_logic;
        i_ARGs_rst                  : in std_logic;
        
        o_schedule                  : out std_logic_vector(7 downto 0);
        
        -- PTP Data
        i_PTP_time_CMAC_clk         : in std_logic_vector(79 downto 0);
        i_PTP_pps_CMAC_clk          : in std_logic;
    
        i_PTP_time_ARGs_clk         : in std_logic_vector(79 downto 0);
        i_PTP_pps_ARGs_clk          : in std_logic;
        
        i_Timeslave_Lite_axi_mosi   : in t_axi4_lite_mosi; 
        o_Timeslave_Lite_axi_miso   : out t_axi4_lite_miso
    
    );
end timeslave_scheduler;

architecture Behavioral of timeslave_scheduler is

COMPONENT ila_0
PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
END COMPONENT;
    
signal timeslave_rw_registers           : t_timeslave_scheduler_rw;
signal timeslave_ro_registers           : t_timeslave_scheduler_ro;    
    
signal start_time_sub_seconds           : std_logic_vector(31 downto 0);
signal start_time_seconds_lower         : std_logic_vector(31 downto 0);
signal start_time_seconds_upper         : std_logic_vector(15 downto 0);

signal current_time_sub_seconds         : std_logic_vector(31 downto 0);
signal current_time_seconds_lower       : std_logic_vector(31 downto 0);
signal current_time_seconds_upper       : std_logic_vector(15 downto 0);

signal schedule_control_cache           : std_logic_vector(7 downto 0);
signal schedule_control_cache_d         : std_logic_vector(7 downto 0);

type time_trigger_statemachine is (IDLE, TIME_1, TIME_2, TIME_3, TIME_4, ACTION);
signal time_trigger_sm : time_trigger_statemachine;

signal Start_time_seek                  : std_logic;
signal Stop_run                         : std_logic;

signal o_schedule_int                   : std_logic_vector(7 downto 0);
signal schedule_debug                   : std_logic_vector(7 downto 0);

constant TS_registers                   : integer := 3;

signal TS_registers_in                  : t_slv_32_arr(0 to (TS_registers-1));
signal TS_registers_out                 : t_slv_32_arr(0 to (TS_registers-1));
    
begin

------------------------------------------------------------------------------------------------------------------------------------------------------

o_schedule  <= o_schedule_int;

------------------------------------------------------------------------------------------------------------------------------------------------------
ARGS_Timeslave_lite : entity Timeslave_CMAC_lib.Timeslave_timeslave_reg 
    
    PORT MAP (
        -- AXI Lite signals, 300 MHz Clock domain
        MM_CLK                          => i_ARGs_clk,
        MM_RST                          => i_ARGs_rst,
        
        SLA_IN                          => i_Timeslave_Lite_axi_mosi,
        SLA_OUT                         => o_Timeslave_Lite_axi_miso,

        TIMESLAVE_SCHEDULER_FIELDS_RW   => timeslave_rw_registers,
        
        TIMESLAVE_SCHEDULER_FIELDS_RO   => timeslave_ro_registers
        
        );

------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do CDC with this arrangement instead of the time from TS core with the ARGs clock due to the timing constraint requirements.

TS_registers_in(0)  <= i_PTP_time_CMAC_clk(31 downto 0);
TS_registers_in(1)  <= i_PTP_time_CMAC_clk(63 downto 32);
TS_registers_in(2)  <= x"0000" & i_PTP_time_CMAC_clk(79 downto 64);

CDC_time_from_timeslave : FOR i IN 0 TO (TS_registers - 1) GENERATE
        stats_crossing : entity signal_processing_common.sync_vector
            generic map (
                WIDTH => 32
            )
            Port Map ( 
                clock_a_rst => i_cmac_reset,
                Clock_a     => i_CMAC_clk,
                data_in     => TS_registers_in(i),
                
                Clock_b     => i_ARGs_clk,
                data_out    => TS_registers_out(i)
            );  

    END GENERATE;
        
------------------------------------------------------------------------------------------------------------------------------------------------------

reg_proc : process(i_ARGs_clk)
begin
    if rising_edge(i_ARGs_clk) then
        timeslave_ro_registers.current_ptp_sub_seconds      <= TS_registers_out(0);
        timeslave_ro_registers.current_ptp_seconds_lower	<= TS_registers_out(1);
        timeslave_ro_registers.current_ptp_seconds_upper	<= TS_registers_out(2);
        
        current_time_sub_seconds                            <= TS_registers_out(0);
        current_time_seconds_lower	                        <= TS_registers_out(1);
        current_time_seconds_upper                          <= TS_registers_out(2)(15 downto 0);
        
        timeslave_ro_registers.schedule_debug				<= x"000000" & schedule_debug;


        start_time_sub_seconds      <= timeslave_rw_registers.tx_start_ptp_sub_seconds;
        start_time_seconds_lower    <= timeslave_rw_registers.tx_start_ptp_seconds_lower;
        start_time_seconds_upper    <= timeslave_rw_registers.tx_start_ptp_seconds_upper(15 downto 0);
        
        
        
        schedule_control_cache      <= timeslave_rw_registers.schedule_control(7 downto 0);
        schedule_control_cache_d    <= schedule_control_cache;
        
        
        if i_ARGs_rst = '1' then
            Start_time_seek     <= '0';
            Stop_run            <= '0';
            time_trigger_sm     <= IDLE;
            o_schedule_int      <= x"00";
            schedule_debug      <= x"00";
        
        else
        
            if schedule_control_cache(1) = '1' then  -- start    
                Start_time_seek     <= '1';
                Stop_run            <= '0';
            elsif schedule_control_cache(2) = '1' then  -- stop 
                Start_time_seek     <= '0';
                Stop_run            <= '1';
            end if;
           
            if time_trigger_sm = IDLE then
                schedule_debug  <= x"00";   -- Stopped.
            elsif time_trigger_sm = TIME_1 then
                schedule_debug  <= x"03";   -- Running and waiting for start time.
            elsif time_trigger_sm = IDLE then
                schedule_debug  <= x"05";   -- Running past start time.
            end if;                
                
            -- compare along the time vector with 16 bits intervals, the final compare is 32 bits
            case time_trigger_sm is
                when IDLE =>
                    o_schedule_int  <= x"04";   -- Stop Trigger.
                    
                    if Start_time_seek = '1' then
                        time_trigger_sm <= TIME_1;
                    end if;
                               
                when TIME_1 =>
                    if current_time_seconds_upper >= start_time_seconds_upper then
                        time_trigger_sm <= TIME_2;
                    end if;
                
                when TIME_2 =>
                    if current_time_seconds_lower(31 downto 16) >= start_time_seconds_lower(31 downto 16) then
                        time_trigger_sm <= TIME_3;
                    end if;
                
                when TIME_3 =>
                    if current_time_seconds_lower(15 downto 0) >= start_time_seconds_lower(15 downto 0) then
                        time_trigger_sm <= TIME_4;
                    end if;
                
                when TIME_4 =>
                    if current_time_sub_seconds >= start_time_sub_seconds then
                        time_trigger_sm <= ACTION;
                    end if;
                
                when ACTION =>
                    if Stop_run = '1' then
                        time_trigger_sm <= IDLE;
                    end if;
                        
                    o_schedule_int  <= x"02";   -- Start Trigger.
               
                
                when OTHERS =>
                    time_trigger_sm <= IDLE;
    
            end case;
        end if;
    end if;
end process;

        
------------------------------------------------------------------------------------------------------------------------------------------------------
debug_gen : IF DEBUG_ILA GENERATE

    PTP_scheduled_ila : ila_0
        port map (
            clk                     => i_ARGs_clk,
            
            probe0(31 downto 0)     => start_time_sub_seconds,
            probe0(63 downto 32)    => start_time_seconds_lower,
            probe0(79 downto 64)    => start_time_seconds_upper(15 downto 0),
            
            probe0(111 downto 80)   => current_time_sub_seconds,
            probe0(143 downto 112)  => current_time_seconds_lower,
            probe0(159 downto 144)  => current_time_seconds_upper,
        
            probe0(167 downto 160)  => o_schedule_int,
            probe0(175 downto 168)  => schedule_debug,
            
            probe0(183 downto 176)  => schedule_control_cache,
            probe0(184)             => Start_time_seek,
            probe0(185)             => Stop_run,
            probe0(191 downto 186)  => (OTHERS => '0')
        );
        
END GENERATE;    
-------------------------------------------------------------


end Behavioral;
