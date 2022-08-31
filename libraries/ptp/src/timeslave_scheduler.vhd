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
--
--    This module will take in four time vectors (80 bits) for the following, Start TX, Stop TX, Start RX, Stop RX.
--    
--    These vectors will be connected into the HBM controller to start and stop packet playback and capture.
--    
--    Initially this will only support TX or RX at time.
--    
--    The statemachine below will trigger based on schedule_control and detect error in settings.
--    
--    Time vectors should be loaded first.
--    The enable the relevant vectors via schedule_control.
--    
--    The State machine will load the start time vector and evaluate this against time from Timeslave IP.
--    Once time has been reached, the start bit will be set.
--    If a stop time is also set, a second loop will occur to evalute that time.
--    Once time has been reached, the stop bit will be set.
--    State machine will settle in a COMPLETE state and a reset will need to be issued to setup another trigger time.
--
--  ################################# 
--  - - field_name        : schedule_control
--      width             : 32
--      access_mode       : RW
--      reset_value       : 0x0
--      field_description : "Multi bit control vector that will allow different operations of scheduled hardware actions.
--                           Assumes a valid future time has been set in the schedule_ptp_xxxx fields above.
--                           Bit 0 = reset CNIC logic and the Scheduler SM to IDLE.
--                           Bit 1 = Enable TX start time.
--                           Bit 2 = Enable TX stop time.
--                           Bit 3 = Enable RX start time.
--                           Bit 4 = Enable RX stop time.
--                           "
--  #################################
--  - - field_name        : schedule_debug
--      width             : 32
--      access_mode       : RO
--      reset_value       : 0x0
--      field_description : "Feedback from hardware..
--                           Bit 0 = Running state, 1 - running ... 0 - stopped , ie waiting for time
--                           Bit 1 = TX start achieved
--                           Bit 2 = TX stop achieved
--                           Bit 3 = RX start achieved
--                           Bit 4 = RX stop achieved
--                           Bit 5 = error condition, eg time scheduled and real time is already in the future.
--                           Bit 6 = in reset. 
--                           Bit 7 = SM in complete state."
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
        
        i_CMAC_b_clk                : in std_logic;
        i_cmac_b_reset              : in std_logic;
        
        i_ARGs_clk                  : in std_logic;
        i_ARGs_rst                  : in std_logic;
        
        o_schedule                  : out std_logic_vector(7 downto 0);
        
        o_ptp_source_select         : out std_logic;
        
        -- PTP Data
        i_PTP_time_CMAC_clk         : in std_logic_vector(79 downto 0);
        i_PTP_pps_CMAC_clk          : in std_logic;
    
        i_PTP_time_ARGs_clk         : in std_logic_vector(79 downto 0);
        i_PTP_pps_ARGs_clk          : in std_logic;
        
        i_PTP_time_ARGs_clk_b       : in std_logic_vector(79 downto 0);
        i_PTP_pps_ARGs_clk_b        : in std_logic;
        
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
    
signal action_time_sub_seconds          : std_logic_vector(31 downto 0);
signal action_time_seconds_lower        : std_logic_vector(31 downto 0);
signal action_time_seconds_upper        : std_logic_vector(15 downto 0);

signal current_time_sub_seconds         : std_logic_vector(31 downto 0);
signal current_time_seconds_lower       : std_logic_vector(31 downto 0);
signal current_time_seconds_upper       : std_logic_vector(15 downto 0);

signal schedule_control_cache           : std_logic_vector(7 downto 0);

signal actions                          : std_logic_vector(7 downto 0);

signal rx_actions                       : std_logic;
signal tx_actions                       : std_logic;

type time_trigger_statemachine is (IDLE, CHECK, ERROR, LOAD, TIME_1, TIME_2, TIME_3, TIME_4, ACTION, COMPLETE);
signal time_trigger_sm : time_trigger_statemachine;
signal time_trigger_sm_debug            : std_logic_vector(3 downto 0);

signal Stop_run                         : std_logic;

signal o_schedule_int                   : std_logic_vector(7 downto 0);
signal schedule_debug                   : std_logic_vector(7 downto 0);

signal ptp_time_internal                : std_logic_vector(79 downto 0);
signal ptp_source_select                : std_logic;

begin

------------------------------------------------------------------------------------------------------------------------------------------------------

o_schedule          <= o_schedule_int;

o_ptp_source_select <= ptp_source_select;

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
-- choose PTP source to use.

ptp_time_internal <=    i_PTP_time_ARGs_clk when ptp_source_select = '0' else
                        i_PTP_time_ARGs_clk_b;
        
------------------------------------------------------------------------------------------------------------------------------------------------------
-- provide feedback to host using the following logic.
-- initally it is an error condition to RX and TX at the same time.

p_scheduler_feedback : process(i_ARGs_clk)
begin
    if rising_edge(i_ARGs_clk) then
        ptp_source_select   <= timeslave_rw_registers.ptp_source_select;
    
        --timeslave_ro_registers.schedule_debug				<= x"000000" & schedule_debug;
        timeslave_ro_registers.schedule_debug_running       <= schedule_debug(0);
        timeslave_ro_registers.schedule_debug_tx_start      <= schedule_debug(1);
        timeslave_ro_registers.schedule_debug_tx_stop       <= schedule_debug(2);
        timeslave_ro_registers.schedule_debug_rx_start      <= schedule_debug(3);
        timeslave_ro_registers.schedule_debug_rx_stop       <= schedule_debug(4);
        timeslave_ro_registers.schedule_debug_error         <= schedule_debug(5);
        timeslave_ro_registers.schedule_debug_reset         <= schedule_debug(6);
        timeslave_ro_registers.schedule_debug_complete      <= schedule_debug(7);

--        Bit 0 = Running state, 1 - running ... 0 - stopped , ie waiting for time
--        Bit 1 = TX start achieved
--        Bit 2 = TX stop achieved
--        Bit 3 = RX start achieved
--        Bit 4 = RX stop achieved
--        Bit 5 = error condition, eg time scheduled and real time is already in the future.
--        Bit 6 = in reset.
--        Bit 7 = SM in complete state.
        ---------------------------------------------------
        if time_trigger_sm = IDLE then 
            schedule_debug(0)   <= '0'; 
        else
            schedule_debug(0)   <= '1';
        end if;
        ---------------------------------------------------
        schedule_debug(6)       <= schedule_control_cache(0);
        ---------------------------------------------------
--        Current CNIC can only TX or RX at a time.
--        Therefore if TX and RX is configured, error condition.
        tx_actions              <= timeslave_rw_registers.schedule_control_tx_start_time OR timeslave_rw_registers.schedule_control_tx_stop_time;
        rx_actions              <= timeslave_rw_registers.schedule_control_rx_start_time OR timeslave_rw_registers.schedule_control_rx_stop_time; 
        
        if time_trigger_sm = ERROR then 
            schedule_debug(5)   <= '1';
        else
            schedule_debug(5)   <= '0';
        end if;
        ---------------------------------------------------
        if time_trigger_sm = COMPLETE then 
            schedule_debug(7)   <= '1';
        else
            schedule_debug(7)   <= '0';
        end if;
        ---------------------------------------------------
        schedule_debug(1)       <= actions(1);
        schedule_debug(2)       <= actions(2);
        schedule_debug(3)       <= actions(3);
        schedule_debug(4)       <= actions(4);
        
    end if;
end process;

actions <= o_schedule_int;

-------------------------------------------------------------------------------------------------------------------------------------------
-- 

control_proc : process(i_ARGs_clk)
begin
    if rising_edge(i_ARGs_clk) then
        timeslave_ro_registers.current_ptp_sub_seconds      <= ptp_time_internal(31 downto 0);
        timeslave_ro_registers.current_ptp_seconds_lower	<= ptp_time_internal(63 downto 32);
        timeslave_ro_registers.current_ptp_seconds_upper	<= x"0000" & ptp_time_internal(79 downto 64);
        
        current_time_sub_seconds                            <= ptp_time_internal(31 downto 0);
        current_time_seconds_lower	                        <= ptp_time_internal(63 downto 32);
        current_time_seconds_upper                          <= ptp_time_internal(79 downto 64);
        
--        Bit 0 = reset CNIC logic and the Scheduler SM to IDLE.
--        Bit 1 = Enable TX start time.
--        Bit 2 = Enable TX stop time.
--        Bit 3 = Enable RX start time.
--        Bit 4 = Enable RX stop time.
        schedule_control_cache(0)                           <= timeslave_rw_registers.schedule_control_reset;
        schedule_control_cache(1)                           <= timeslave_rw_registers.schedule_control_tx_start_time;
        schedule_control_cache(2)                           <= timeslave_rw_registers.schedule_control_tx_stop_time;
        schedule_control_cache(3)                           <= timeslave_rw_registers.schedule_control_rx_start_time;
        schedule_control_cache(4)                           <= timeslave_rw_registers.schedule_control_rx_stop_time;

        o_schedule_int(0)   <= schedule_control_cache(0);

        if ((i_ARGs_rst = '1') OR (schedule_control_cache(0) = '1')) then
            time_trigger_sm             <= IDLE;
            o_schedule_int(4 downto 1)  <= x"0";
        else
            -- compare along the time vector with 16 bits intervals, the final compare is 32 bits
            case time_trigger_sm is
                when IDLE =>
                    o_schedule_int(4 downto 1)  <= x"0";
                    Stop_run                    <= '0';
                    
                    if schedule_control_cache(4 downto 1) /= x"0" then
                        time_trigger_sm <= CHECK;
                    end if;
        
                when CHECK =>
                    if tx_actions = '1' and rx_actions = '1' then
                        time_trigger_sm <= ERROR;
                    else
                        time_trigger_sm <= LOAD;
                    end if;
                    
                when ERROR => 
            
            ----------------------------------------------------------------------------------------
                when LOAD =>
                    time_trigger_sm <= TIME_1;
                    
                    if Stop_run = '0' and schedule_control_cache(1) = '1' then
                        action_time_sub_seconds      <= timeslave_rw_registers.tx_start_ptp_sub_seconds;
                        action_time_seconds_lower    <= timeslave_rw_registers.tx_start_ptp_seconds_lower;
                        action_time_seconds_upper    <= timeslave_rw_registers.tx_start_ptp_seconds_upper(15 downto 0);
                    elsif Stop_run = '0' and schedule_control_cache(3) = '1' then
                        action_time_sub_seconds      <= timeslave_rw_registers.rx_start_ptp_sub_seconds;
                        action_time_seconds_lower    <= timeslave_rw_registers.rx_start_ptp_seconds_lower;
                        action_time_seconds_upper    <= timeslave_rw_registers.rx_start_ptp_seconds_upper(15 downto 0);
                    elsif Stop_run = '1' and schedule_control_cache(2) = '1' then
                        action_time_sub_seconds      <= timeslave_rw_registers.tx_stop_ptp_sub_seconds;
                        action_time_seconds_lower    <= timeslave_rw_registers.tx_stop_ptp_seconds_lower;
                        action_time_seconds_upper    <= timeslave_rw_registers.tx_stop_ptp_seconds_upper(15 downto 0);
                    elsif Stop_run = '1' and schedule_control_cache(4) = '1' then
                        action_time_sub_seconds      <= timeslave_rw_registers.rx_stop_ptp_sub_seconds;
                        action_time_seconds_lower    <= timeslave_rw_registers.rx_stop_ptp_seconds_lower;
                        action_time_seconds_upper    <= timeslave_rw_registers.rx_stop_ptp_seconds_upper(15 downto 0);
                    end if;
                                 
            ----------------------------------------------------------------------------------------
                when TIME_1 =>
                    if current_time_seconds_upper >= action_time_seconds_upper then
                        time_trigger_sm <= TIME_2;
                    end if;
                
                when TIME_2 =>
                    if current_time_seconds_lower(31 downto 16) >= action_time_seconds_lower(31 downto 16) then
                        time_trigger_sm <= TIME_3;
                    end if;
                
                when TIME_3 =>
                    if current_time_seconds_lower(15 downto 0) >= action_time_seconds_lower(15 downto 0) then
                        time_trigger_sm <= TIME_4;
                    end if;
                
                when TIME_4 =>
                    if current_time_sub_seconds >= action_time_sub_seconds then
                        time_trigger_sm <= ACTION;
                    end if;
                
                when ACTION =>
                    if ((schedule_control_cache(2) = '1') OR (schedule_control_cache(4) = '1')) AND Stop_run = '0' then
                        time_trigger_sm <= LOAD;
                        Stop_run        <= '1';
                    else
                        time_trigger_sm <= COMPLETE;
                    end if;
                        
                    o_schedule_int(1)   <= schedule_control_cache(1);               -- TX Start Trigger.
                    o_schedule_int(2)   <= schedule_control_cache(2) AND Stop_run;  -- TX Stop
                    o_schedule_int(3)   <= schedule_control_cache(3);               -- RX Start Trigger.
                    o_schedule_int(4)   <= schedule_control_cache(4) AND Stop_run;  -- RX Stop
               
                when COMPLETE =>
                
                
                when OTHERS =>
                    time_trigger_sm <= IDLE;
        
            end case;
            
        end if;
    end if;
end process;

        
------------------------------------------------------------------------------------------------------------------------------------------------------
debug_gen : IF DEBUG_ILA GENERATE

    time_trigger_sm_debug <=    x"1" when time_trigger_sm = IDLE else
                                x"2" when time_trigger_sm = CHECK else
                                x"3" when time_trigger_sm = ERROR else
                                x"4" when time_trigger_sm = LOAD else
                                x"5" when time_trigger_sm = TIME_1 else
                                x"6" when time_trigger_sm = TIME_2 else
                                x"7" when time_trigger_sm = TIME_3 else
                                x"8" when time_trigger_sm = TIME_4 else
                                x"9" when time_trigger_sm = ACTION else
                                x"A" when time_trigger_sm = COMPLETE else
                                x"0";

    PTP_scheduled_ila : ila_0
        port map (
            clk                     => i_ARGs_clk,
            
            probe0(31 downto 0)     => action_time_sub_seconds,
            probe0(63 downto 32)    => action_time_seconds_lower,
            probe0(79 downto 64)    => action_time_seconds_upper(15 downto 0),
            
            probe0(111 downto 80)   => current_time_sub_seconds,
            probe0(143 downto 112)  => current_time_seconds_lower,
            probe0(159 downto 144)  => current_time_seconds_upper,
        
            probe0(167 downto 160)  => o_schedule_int,
            probe0(175 downto 168)  => schedule_debug,
            
            probe0(183 downto 176)  => schedule_control_cache,
            probe0(184)             => '0',
            probe0(185)             => Stop_run,
            probe0(189 downto 186)  => time_trigger_sm_debug,
            probe0(191 downto 190)  => (OTHERS => '0')
        );
        
END GENERATE;    
-------------------------------------------------------------


end Behavioral;
