----------------------------------------------------------------------------------
-- Company: CSIRO
-- Engineer: David Humphrey (dave.humphrey@csiro.au)
-- 
-- Create Date: 13.09.2020 23:55:03
-- Module Name: ct_atomic_pst_readout - Behavioral
-- Description: 
--  Readout data for PST processing from the first stage corner turn.
-- 
--  -----------------------------------------------------------------------------
--  Flow chart:
--
--    commands in (i_currentBuffer, i_previousBuffer, i_readStart, i_Nchannels)
--        |
--    Wait until all previous memory read requests have returned, and the buffer is empty.
--        |
--    Generate Read addresses on the AXI bus to shared memory ------------>>>----------------
--     (Read from 3 different virtual channels at a time)                                   |
--        |                                                                         Generate start of frame signal to 
--    Data from shared memory goes into BRAM buffer                                 cross the clock domain to the read side.
--     (write side of buffer is 512 deep x 512 bits wide)                           Also send the packet count to the read side for the first packet in the frame.
--        |                                                                                 |
--    Read data from BRAM buffer into 128 bit registers ------------------<<<----------------
--     (Read side of the buffer is 2048 deep x 128 bits wide)
--        |
--    Send data from 128 bit registers to the filterbanks, 32 bits at a time.
--
--  -----------------------------------------------------------------------------
--  Structure:
-- 
--   commands in -> read address fsm (ar_fsm) -> AXI AR bus (axi_arvalid, axi_arready, axi_araddr, axi_arlen)
--                                            -> 
--
--   Read data bus (axi_rvalid, axi_rdata etc) -> BRAM buffer (write side = 512 deep x 512 bits) -> 3 x 128 bit registers (one for each filterbank output) -> 3 x 32 bit FIFOs -> ouptut busses
--           ar_fsm    -->  ar FIFO            -> buffer_FIFOs                                   -> read fsm 
--
--  There are several buffers :
--    - ar_FIFO : Holds information about the read request until the read data comes back from the external memory.
--    - Buffer  : Main buffer, write side 512 deep x 512 bits wide, split into 3 buffers, one for each channel being read out
--                Read side of the buffer is 2048 deep x 128 bits wide. It needs to be 128 bits wide in order to have sufficient read bandwidth.
--    - buffer_fifos : 3 fifos, one for each buffer in the main buffer, holds information about each word in the buffer
--    - reg128  : 3 x 128 bit registers, to convert from 128 bit data out of the buffer to 32 bit data that is sent to the filterbanks
--    - fifo32 : 3 x 32 bit wide FIFOs, to stream data to the filterbanks.
--     
--  ------------------------------------------------------------------------------
--  BRAM buffer structure
--  Requirements :
--    - dual clock, since input clock is the 300 MHz clock from the AXI bus, while output clock is 450 MHz clock to the filterbanks
--    - 512 wide input (=width of the AXI bus)
--    - Buffer data for 3 different virtual channels (since this module drives 3 dual-pol filterbanks)
--  Structure :
--    - Input is 512 deep x 512 bits wide. 
--    - Output is 2048 deep x 128 bits wide.
--    On the input side, the buffer is split into 3 regions of 128 words
--    - Address 0 to 127
--    - Address 128 to 255
--    - Address 256 to 383
--
--  In addition to the main 512x512 buffer, a FIFO is kept for each of the three regions in the buffer
--  Every time a 512 bit word is written to the buffer, an entry is written to the FIFO
--  FIFO contents :
--      - bits 15:0  = HDeltaP (HDeltaP and VDeltaP are the fine delay information placed in the meta info for this output data)
--      - bits 31:16 = VDeltaP
--      - bit 35:32  = S = Number of samples in the 512 bit word - 1. Note 512 bits = 64 bytes = 16 samples, so this ranges from 0 to 15
--                     For the first word in a channel, the data will be left aligned, i.e. in bits(511 downto (512 - (S+1)*32))
--                     while for the last word it will be right aligned, i.e. in bits((S+1)*32 downto 0).
--
--  Each of these 3 FIFOs uses 1x18K BRAM.
--  After a start of frame signal is received, the read side fsm waits until all the FIFOs contain at least 32 entries before it starts reading.
--  Then the read fsm reads at the rate programmed in the registers (i.e. a fixed number of output clock cycles per output frame).
--  
--  Coarse Delay implementation:
--   To implement the coarse delay for each channel :
--    - Reads from shared memory are 512 bit aligned
--    - Reads from the the BRAM buffer are 128 bit aligned
--    - Reads from the 128 bit register are 32 bit aligned, i.e. aligned to the first sample. 
--
--  Output frames & coarse Delay
--   The coarse delay is up to 2047 LFAA samples.
--   The last sample output to the PST filterbanks for a frame is <last sample in frame> - 2048 + coarse_delay
--   This means that the first sample output to the PST filterbanks will be 
--       <last sample in the previous frame> - 2048 + coarse_delay - <preload> 
--     =  <last sample in the previous frame> - 2048 + coarse_delay - 2880
--     =  <last sample in the previous frame> - 4928 + coarse_delay
--   The output is in units of blocks of 64 samples, because
--    - 64 samples matches with the data required for PSS
--    - Oversampling in the PST filterbank means that we need to generate a new output every 192 samples, i.e. 3*64 samples.
--  
--   Preload data for the PST filterbank consists of (12*256 - 192) = 2880 samples.
--   Two requirements on the frame length:
--    - In order to have the same pattern of read addresses in each frame, a frame needs to have a multiple of 192 LFAA samples.
--    - Frames also need to be a multiple of 2048 LFAA samples, so that they are a whole number of LFAA frames.
--   These requirements together mean that 
--    - The length of a frame should be a multiple of 3 LFAA frames.
--    - The number of PST outputs per frame will be (LFAA Frames per buffer * 2048)/192
--
--   e.g. 
--    For a frame length of 27 LFAA frames, and a coarse delay of 7 samples:
--      - Frame length = 27*2048*1080ns = 59.7 ms
--      - PST outputs per frame = 27*2048/192 = 288
--      - First sample output is from 
-- 
--  For diagrams showing how the coarse delay relates to buffers see 
--    https://confluence.skatelescope.org/display/SE/PSS+and+PST+Coarse+Corner+Turner
--  ------------------------------------------------------------------------------
--  Memory latency
--  The HBM controller quotes a memory latency of 128 memory clocks (i.e. 900MHz clocks)
--  (or possibly more, depending on transaction patterns.)
--  There are two separate command queues in the HBM controller of 128 and 12 entries. Likely both are enabled 
--  in the Vitis design.
--  128 x 900 MHz clocks = 142 ns = 43 x 300 MHz clocks.
--  So we can roughly expect that read data will be returned around 43 clocks after the read 
--  request has been issued. Since we are requesting bursts of 16 x 256 bit words, there will likely be 
--  3 or 4 transactions in flight if we are reading at the full rate.
----------------------------------------------------------------------------------

library IEEE, xpm, common_lib, HBM_PktController_lib, trafgen_lib;
use IEEE.STD_LOGIC_1164.ALL;
use xpm.vcomponents.all;
use IEEE.NUMERIC_STD.ALL;
USE common_lib.common_pkg.ALL;
USE HBM_PktController_lib.HBM_PktController_hbm_pktcontroller_reg_pkg.ALL;
USE trafgen_lib.trafgen_top_pkg.all;


entity HBM_readout is
    generic (
        -- Number of LFAA blocks per frame for the PSS/PST output.
        -- Each LFAA block is 2048 time samples. e.g. 27 for a 60 ms corner turn.
        -- This value needs to be a multiple of 3 so that there are a whole number of PST outputs per frame.
        -- Maximum value is 30, (limited by the 256MByte buffer size, which has to fit 1024 virtual channels)
        g_LFAA_BLOCKS_PER_FRAME : integer := 27   -- Number of LFAA blocks per frame; must be a multiple of 3,
    );
    Port(
        shared_clk : in std_logic; -- Shared memory clock
        i_rst      : in std_logic; -- module reset, on shared_clk.
        -- input signals to trigger reading of a buffer, on shared_clk
        i_currentBuffer : in std_logic_vector(1 downto 0);
        i_previousBuffer : in std_logic_vector(1 downto 0); -- because of the initialisation data, we need some data from the end of this buffer also.
        i_readStart  : in std_logic; -- Pulse to start readout from readBuffer
        i_packetCount  : in std_logic_vector(31 downto 0); -- Packet Count for the first packet in i_currentBuffer
        i_Nchannels  : in std_logic_vector(11 downto 0); -- Total number of virtual channels to read out,
        i_clocksPerPacket : in std_logic_vector(15 downto 0); -- Number of clocks per output, connect to register "output_cycles"
        -- Reading Coarse and fine delay info from the registers
        -- In the registers, word 0, bits 15:0  = Coarse delay, word 0 bits 31:16 = Hpol DeltaP, word 1 bits 15:0 = Vpol deltaP, word 1 bits 31:16 = deltaDeltaP
        o_delayTableAddr : out std_logic_vector(11 downto 0); -- 4 addresses per virtual channel, up to 1024 virtual channels
        i_delayTableData : in std_logic_vector(31 downto 0); -- Data from the delay table with 3 cycle latency. 
        i_startPacket : in std_logic_vector(31 downto 0); -- LFAA Packet count that the fine delays in the delay table are relative to. Fine delays are based on the first LFAA sample that contributes to a given filterbank output
        -- Read and write to the valid memory, to check the place we are reading from in the HBM has valid data
        o_validMemReadAddr : out std_logic_vector(16 downto 0); -- 8192 bytes per LFAA packet, 1 GByte of memory, so 1Gbyte/8192 bytes = 2^30/2^13 = 2^17
        i_validMemReadData : in std_logic;  -- read data returned 3 clocks later.
        o_validMemWriteAddr : out std_logic_vector(16 downto 0); -- write always clears the memory (mark the block as invalid).
        o_validMemWrEn      : out std_logic;
        -- Data output to the filterbanks
        -- meta fields are 
        --   - .HDeltaP(15:0), .VDeltaP(15:0) : phase across the band, used by the fine delay.
        --   - .frameCount(36:0), = high 32 bits is the LFAA frame count, low 5 bits is the 64 sample block within the frame. 
        --   - .virtualChannel(15:0) = Virtual channels are processed in order, so this just counts.
        --   - .valid                = Number of virtual channels being processed may not be a multiple of 3, so there is also a valid qualifier.
        FB_clk  : in std_logic;
        o_sof   : out std_logic; -- start of frame.
        o_sofFull : out std_logic; -- start of a full frame, i.e. 60ms of data.
        o_HPol0 : out t_slv_8_arr(1 downto 0);
        o_VPol0 : out t_slv_8_arr(1 downto 0);
        o_meta0 : out t_atomic_CT_pst_META_out;
        
        o_HPol1 : out t_slv_8_arr(1 downto 0);
        o_VPol1 : out t_slv_8_arr(1 downto 0);
        o_meta1 : out t_atomic_CT_pst_META_out;
        
        o_HPol2 : out t_slv_8_arr(1 downto 0);
        o_VPol2 : out t_slv_8_arr(1 downto 0);
        o_meta2 : out t_atomic_CT_pst_META_out;
        
        o_valid : out std_logic;
        -- AXI read address and data input buses
        -- ar bus - read address
        o_axi_arvalid : out std_logic;
        i_axi_arready : in std_logic;
        o_axi_araddr  : out std_logic_vector(29 downto 0);
        o_axi_arlen   : out std_logic_vector(7 downto 0);
        -- r bus - read data
        i_axi_rvalid  : in std_logic;
        o_axi_rready  : out std_logic;
        i_axi_rdata   : in std_logic_vector(511 downto 0);
        i_axi_rlast   : in std_logic;
        i_axi_rresp   : in std_logic_vector(1 downto 0);
        -- errors and debug
        -- Flag an error; we were asked to start reading but we haven't finished reading the previous frame.
        o_readOverflow : out std_logic;     -- Pulses high in the shared_clk domain.
        o_Unexpected_rdata : out std_logic; -- data was returned from the HBM that we didn't expect (i.e. no read request was put in for it)
        o_dataMissing : out std_logic       -- Read from a HBM address that we haven't written data to. Most reads are 8 beats = 8*64 = 512 bytes, so this will go high 16 times per missing LFAA packet.
    );
end ct_atomic_pst_readout;

architecture Behavioral of ct_atomic_pst_readout is
    
    signal bufRdAddr : std_logic_vector(10 downto 0);
    signal bufDout : std_logic_vector(127 downto 0);
    
    signal FBpacketCount : std_logic_vector(36 downto 0);
    signal cdc_dataOut : std_logic_vector(63 downto 0);
    signal cdc_dataIn : std_logic_vector(63 downto 0);
    signal shared_to_FB_valid, shared_to_FB_valid_del1 : std_logic;
    signal shared_to_FB_send, shared_to_FB_rcv : std_logic := '0';
    --signal FBbufferStartAddr : std_logic_vector(7 downto 0);
    signal FBClocksPerPacket, FBClocksPerPacketMinusTwo : std_logic_vector(15 downto 0);
    signal FBNChannels : std_logic_vector(15 downto 0);
    signal bufReadAddr0, bufReadAddr1, bufReadAddr2 : std_logic_vector(8 downto 0);
    
    signal ARFIFO_dout : std_logic_vector(157 downto 0);
    signal ARFIFO_validOut : std_logic;
    signal ARFIFO_empty : std_logic;
    signal ARFIFO_full : std_logic;
    signal ARFIFO_RdDataCount : std_logic_vector(5 downto 0);
    signal ARFIFO_WrDataCount : std_logic_vector(5 downto 0);
    signal ARFIFO_din : std_logic_vector(157 downto 0);
    signal ARFIFO_rdEn : std_logic;
    signal ARFIFO_rst : std_logic;
    signal ARFIFO_wrEn : std_logic;
    
    signal ar_virtualChannel : std_logic_vector(9 downto 0);
    signal ar_virtualChannelDel1, ar_virtualChannelDel2, ar_virtualChannelDel3, ar_virtualChannelDel4 : std_logic_vector(9 downto 0);
    signal ar_currentBuffer : std_logic_vector(1 downto 0);
    signal ar_previousBuffer : std_logic_vector(1 downto 0);
    signal ar_packetCount : std_logic_vector(31 downto 0);
    signal ar_NChannels : std_logic_vector(11 downto 0);
    signal ar_startPacket : std_logic_vector(31 downto 0);
    signal ar_clocksPerPacket : std_logic_vector(15 downto 0);
    
    signal buf0VirtualChannel, buf1VirtualChannel, buf2VirtualChannel : std_logic_vector(9 downto 0);
    signal buf0CoarseDelay, buf1CoarseDelay, buf2CoarseDelay : std_logic_vector(15 downto 0);
    signal buf0HpolDeltaP, buf1HpolDeltaP, buf2HpolDeltaP : std_logic_vector(15 downto 0);
    signal buf0VpolDeltaP, buf1VpolDeltaP, buf2VpolDeltaP : std_logic_vector(15 downto 0);
    signal buf0DeltaDeltaP, buf1DeltaDeltaP, buf2DeltaDeltaP : std_logic_vector(15 downto 0);    
    
    type ar_fsm_type is (getDelay0FirstWord, getDelay0SecondWord, getDelay0ThirdWord, getDelay0FourthWord,
                         getDelay1FirstWord, getDelay1SecondWord, getDelay1ThirdWord, getDelay1FourthWord,
                         getDelay2FirstWord, getDelay2SecondWord, getDelay2ThirdWord, getDelay2FourthWord,
                         waitDelaysValid, getDataIdle, getBuf0Data, 
                         getBuf1Data, getBuf2Data, waitARReady, checkAllVirtualChannelsDone, waitAllDone, checkDone, done);
    signal ar_fsm, ar_fsmDel1, ar_fsmDel2, ar_fsmDel3, ar_fsmDel4 : ar_fsm_type;
    signal arfsmWaitCount : std_logic_vector(2 downto 0);
    signal pendingReads, bufMaxUsed : t_slv_10_arr(2 downto 0);
    signal ARFIFO_wrBeats : std_logic_vector(9 downto 0);
    signal ARFIFO_rdBeats : std_logic_vector(9 downto 0);
    signal buf0Buffer : std_logic_vector(1 downto 0);
    signal buf0Sample : std_logic_vector(15 downto 0);
    signal buf0Len : std_logic_vector(2 downto 0);
    signal buf0SamplesRemaining : std_logic_vector(15 downto 0);
    signal buf0SamplesToRead : std_logic_vector(7 downto 0);
    signal buf0Len_ext : std_logic_vector(15 downto 0);
    
    signal buf1Buffer : std_logic_vector(1 downto 0);
    signal buf1Sample : std_logic_vector(15 downto 0);
    signal buf1Len : std_logic_vector(2 downto 0);
    signal buf1SamplesRemaining : std_logic_vector(15 downto 0);
    signal buf1SamplesToRead : std_logic_vector(7 downto 0);
    signal buf1Len_ext : std_logic_vector(15 downto 0);
    
    signal buf2Buffer : std_logic_vector(1 downto 0);
    signal buf2Sample : std_logic_vector(15 downto 0);
    signal buf2Len : std_logic_vector(2 downto 0);
    signal buf2SamplesRemaining : std_logic_vector(15 downto 0);
    signal buf2SamplesToRead : std_logic_vector(7 downto 0);
    signal buf2Len_ext : std_logic_vector(15 downto 0);
    signal buf0HasMoreSamples, buf1HasMoreSamples, buf2HasMoreSamples : std_logic;
    signal buf0FirstRead, buf0LastRead, buf1FirstRead, buf1LastRead, buf2FirstRead, buf2LastRead : std_logic;
    
    signal buf0SampleRelative, buf1SampleRelative, buf2SampleRelative : std_logic_vector(19 downto 0);
    signal fineDelayPacketOffset : std_logic_vector(31 downto 0);
    
    signal rdata_beats : std_logic_vector(2 downto 0);
    signal rdata_beatCount : std_logic_vector(2 downto 0);
    signal rdata_deltaDeltaPXsampleOffset : signed(47 downto 0);
    signal rdata_deltaDeltaPXsampleOffsetDel3 : std_logic_vector(47 downto 0);
    signal rdata_deltaDeltaPXsampleOffsetDel4 : std_logic_vector(47 downto 0);
    signal rdata_deltaDeltaPXsampleOffsetDel5 : std_logic_vector(26 downto 0);
    signal rdata_deltaDeltaPXsampleOffsetDel6 : std_logic_vector(26 downto 0);
    
    signal rdata_phaseStepXsampleOffset : signed(58 downto 0); -- result of a 27 * 32 bit multiply.
    signal rdata_phaseStepXsampleOffsetDel3, rdata_phaseStepXsampleOffsetDel4 : std_logic_vector(58 downto 0);
    
    signal rdata_roundupDel5 : std_logic := '0';
    
    signal rdata_HDeltaPDel5, rdata_VDeltaPDel5, rdata_HDeltaPDel4, rdata_VDeltaPDel4, rdata_HDeltaPDel3, rdata_VDeltaPDel3, rdata_HDeltaPDel2, rdata_VDeltaPDel2, rdata_HDeltaP, rdata_VDeltaP : std_logic_vector(15 downto 0);
    signal rdata_HDeltaPDel6, rdata_VDeltaPDel6, rdata_HDeltaPDel7, rdata_VDeltaPDel7 : std_logic_vector(26 downto 0);
    --signal rdata_validSamples, rdata_validSamplesDel2, rdata_validSamplesDel3, rdata_validSamplesDel4, rdata_validSamplesDel5, rdata_validSamplesDel6, rdata_validSamplesDel7 : std_logic_vector(3 downto 0);
    signal rdata_rdStartOffset, rdata_rdStartOffsetDel2, rdata_rdStartOffsetDel3, rdata_rdStartOffsetDel4, rdata_rdStartOffsetDel5, rdata_rdStartOffsetDel6, rdata_rdStartOffsetDel7 : std_logic_vector(3 downto 0);
    signal axi_rvalid_del1, axi_rvalid_del2, axi_rvalid_del3, axi_rvalid_del4, axi_rvalid_del5, axi_rvalid_del6, axi_rvalid_del7 : std_logic;
    signal rdata_stream, rdata_streamDel2, rdata_streamDel3, rdata_streamDel4, rdata_streamDel5, rdata_streamDel6, rdata_streamDel7 : std_logic_vector(1 downto 0);
    signal ar_regUsed : std_logic := '0';
    signal rdata_deltaDeltaP : std_logic_vector(15 downto 0);
    
    signal bufFIFO_din : std_logic_vector(67 downto 0);
    signal bufFIFO_dout, bufFIFO_doutDel : t_slv_68_arr(2 downto 0);
    signal bufFIFO_empty : std_logic_vector(2 downto 0);
    signal bufFIFO_rdDataCount : t_slv_10_arr(2 downto 0);
    signal bufFIFO_wrDataCount : t_slv_10_arr(2 downto 0);
    signal bufFIFO_rdEn, bufFIFO_wrEn, bufFIFO_wrEnDel1 : std_logic_vector(2 downto 0);
    signal rdata_sampleOffset : std_logic_vector(31 downto 0);
    
    signal bufWrAddr : std_logic_vector(8 downto 0);
    signal bufWrAddr0, bufWrAddr1, bufWrAddr2 : std_logic_vector(6 downto 0);
    signal bufWE : std_logic_vector(0 downto 0);
    
    signal axi_arvalid : std_logic;
    signal axi_araddr  : std_logic_vector(29 downto 0);
    signal axi_arlen   : std_logic_vector(2 downto 0);

    signal ARFIFO_dinDel1, ARFIFO_dinDel2, ARFIFO_dinDel3 : std_logic_vector(157 downto 0);
    signal ARFIFO_dinDel4 : std_logic_vector(157 downto 0);
    signal ARFIFO_wrEnDel1, ARFIFO_wrEnDel2, ARFIFO_wrEnDel3, ARFIFO_wrEnDel4 : std_logic;
    signal rdata_dvalid : std_logic;
    signal bufWrData : std_logic_vector(511 downto 0);
    
    signal validMemWriteAddr, validMemWriteAddrDel1, validMemWriteAddrDel2 : std_logic_vector(16 downto 0);
    signal validMemWrEn, validMemWrEnDel1, validMemWrEnDel2 : std_logic;
    signal axi_arvalidDel1 : std_logic;
    signal readStartDel1, readStartDel2 : std_logic;

    type rd_fsm_type is (reset_output_fifos_start, reset_output_fifos_wait, reset_output_fifos, reset_output_fifos_wait1, reset_output_fifos_wait2, rd_wait, rd_buf0, rd_buf1, rd_buf2, rd_start, idle);
    signal rd_fsm : rd_fsm_type := idle;
    signal readOutRst : std_logic := '0';
    signal buf0WordsRemaining, buf1WordsRemaining, buf2WordsRemaining : std_logic_vector(15 downto 0) := x"0000";
    signal buf0RdEnableDel2, buf0RdEnableDel1, buf0RdEnable : std_logic := '0';
    signal buf1RdEnableDel2, buf1RdEnableDel1, buf1RdEnable : std_logic := '0';
    signal buf2RdEnableDel2, buf2RdEnableDel1, buf2RdEnable : std_logic := '0';
    signal bufRdValid : std_logic_vector(2 downto 0);
    signal rdStop : std_logic_vector(2 downto 0);
    signal rstBusy : std_logic_vector(2 downto 0);
    signal buf0ReadDone, buf1ReadDone, buf2ReadDone : std_logic := '0';
    signal channelCount : std_logic_vector(15 downto 0);
    
    signal rdOffset : t_slv_2_arr(2 downto 0);
    signal readoutData : t_slv_32_arr(2 downto 0);
    signal readoutHDeltaP : t_slv_16_arr(2 downto 0);
    signal readoutVDeltaP : t_slv_16_arr(2 downto 0);
    signal readoutHOffsetP : t_slv_16_arr(2 downto 0);
    signal readoutVOffsetP : t_slv_16_arr(2 downto 0);
    signal bufFIFOHalfFull : std_logic_vector(2 downto 0);
    signal allPacketsSent : std_logic;
    
    signal readoutStartDel : std_logic_vector(15 downto 0) := x"0000";
    signal readoutStart : std_logic := '0';
    signal readPacket : std_logic := '0';
    signal clockCount : std_logic_vector(15 downto 0);
    signal packetsRemaining : std_logic_vector(15 downto 0);
    signal validOut : std_logic_vector(2 downto 0);
    signal packetCount : std_logic_vector(36 downto 0);
    signal meta0VirtualChannel, meta1VirtualChannel, meta2VirtualChannel : std_logic_vector(15 downto 0);
    signal sofFull, sof : std_logic := '0';
    signal axi_rdataDel1 : std_logic_vector(511 downto 0);
    signal selRFI : std_logic;
    signal clockCountIncrement : std_logic := '0';
    signal clockCountZero : std_logic := '0';
    
    signal buf0PhaseOffset, buf0PhaseStep : std_logic_vector(31 downto 0);
    signal buf1PhaseOffset, buf1PhaseStep : std_logic_vector(31 downto 0);
    signal buf2PhaseOffset, buf2PhaseStep : std_logic_vector(31 downto 0);
    
    signal rdata_phaseStep : std_logic_vector(26 downto 0);
    signal rdata_phaseOffset : std_logic_vector(31 downto 0);
    
    signal rdata_HphaseOffsetDel2, rdata_HphaseOffsetDel3, rdata_HphaseOffsetDel4, rdata_HphaseOffsetDel5, rdata_HphaseOffsetDel6, rdata_HphaseOffsetDel7 : std_logic_vector(15 downto 0);
    signal rdata_VphaseOffsetDel2, rdata_VphaseOffsetDel3, rdata_VphaseOffsetDel4, rdata_VphaseOffsetDel5, rdata_VphaseOffsetDel6, rdata_VphaseOffsetDel7 : std_logic_vector(15 downto 0);
    signal rdata_phaseStepRoundupDel5 : std_logic;
    signal rdata_phaseStepXsampleOffsetDel5, rdata_phaseStepXsampleOffsetDel6 : std_logic_vector(15 downto 0);
    
    signal rstDel1, rstDel2, rstInternal, rstFIFOs, rstFIFOsDel1 : std_logic := '0';
    signal rstCount : std_logic_vector(8 downto 0) := "000000000";
    
    component ila_beamData
    port (
        clk : in std_logic;
        probe0 : in std_logic_vector(119 downto 0)); 
    end component;
    
    component ila_2
    port (
        clk : in std_logic;
        probe0 : in std_logic_vector(63 downto 0)); 
    end component;    
    
begin
    
    o_axi_arlen(7 downto 3) <= "00000";  -- Never ask for more than 8 x 64 byte words.
    o_axi_arlen(2 downto 0) <= axi_arlen(2 downto 0);
    o_axi_rready <= '1';
    o_axi_arvalid <= axi_arvalid;
    o_axi_araddr <= axi_araddr;
    
    o_validMemReadAddr <= axi_araddr(29 downto 13);
    
    process(shared_clk)
        variable buf0SampleTemp, buf1SampleTemp, buf2SampleTemp : std_logic_vector(15 downto 0);
        variable buf0SampleRelative_v, buf1SampleRelative_v, buf2SampleRelative_v : std_logic_vector(15 downto 0);
        variable buf0SamplesToRead16bit, buf1SamplesToRead16bit, buf2SamplesToRead16bit : std_logic_vector(15 downto 0);
        variable buf0Lenx16, buf1Lenx16, buf2Lenx16 : std_logic_vector(19 downto 0);
        --variable buf0SamplesToRead20bit, buf1SamplesToRead20bit, buf2SamplesToRead20bit : std_logic_vector(19 downto 0);
        variable buf0SampleTemp8bit, buf1SampleTemp8bit, buf2SampleTemp8bit : std_logic_vector(7 downto 0);
        variable fineDelaySampleOffset, sampleRelative : std_logic_vector(31 downto 0);
        variable LFAABlock_v : std_logic_vector(4 downto 0);
        variable samplesToRead_v, readStartAddr_v : std_logic_vector(4 downto 0);
        
    begin
        if rising_edge(shared_clk) then
        
            ----------------------------------------------------------------------------
            -- write to clear the valid memory (mark the block as invalid).
             
            LFAABlock_v := axi_araddr(17 downto 13);
            axi_arvalidDel1 <= axi_arvalid;
            if ((((axi_araddr(29 downto 28) = ar_currentBuffer) and (axi_araddr(12 downto 9) = "0000") and (unsigned(LFAABlock_v) = 0)) or
                 ((axi_araddr(29 downto 28) = ar_currentBuffer) and (axi_araddr(12 downto 9) = "0001") and (unsigned(LFAABlock_v) = 0)) or
                 ((axi_araddr(29 downto 28) = ar_currentBuffer) and (axi_araddr(12 downto 9) = "0010") and (unsigned(LFAABlock_v) = 0))) and 
                (axi_arvalid = '1' and axi_arvalidDel1 = '0')) then
                -- Note axi_araddr(29:28) = 256 MByte buffer in the HBM  = valid memory address bits (16:15)
                --      axi_araddr(27:18) = virtual channel              = valid memory address bits (14:5)
                --      axi_araddr(17:13) = LFAA block                   = valid memory address bits (4:0)
                --      axi_araddr(12:0)  = byte within the 8192 byte LFAA block.
                --                          Reads are 512 bytes, so if bits(12:9) = "1111" then this is the last read from this LFAA block.
                -- This clause clears the valid bit :
                --   - For the last three LFAA blocks in the previous buffer, on the first three memory requests to the first LFAA block in the current buffer
                --     (This happens on the reads of current buffer to ensure that all the preload blocks in the previous buffer are cleared,
                --      since large values of the coarse delay may mean that not all of the 3 LFAA blocks are in previous buffer are read to preload the filterbanks)
                validMemWrEn <= '1';
                validMemWriteAddr(16 downto 15) <= ar_previousBuffer;
                validMemWriteAddr(14 downto 5) <= axi_araddr(27 downto 18);
                if axi_araddr(12 downto 9) = "0000" then
                    validMemWriteAddr(4 downto 0) <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME - 3,5));
                elsif axi_araddr(12 downto 9) = "0001" then
                    validMemWriteAddr(4 downto 0) <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME - 2,5));
                else 
                    validMemWriteAddr(4 downto 0) <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME - 1,5));
                end if;
            elsif (((axi_araddr(29 downto 28) = ar_currentBuffer) and (axi_araddr(12 downto 9) = "1111") and (unsigned(LFAABlock_v) < (g_LFAA_BLOCKS_PER_FRAME-3))) and 
                   (axi_arvalid = '1' and axi_arvalidDel1 = '0')) then
                -- clear the valid bit
                --   - on the last read from any but the final 3 blocks in this buffer.
                --     (since up to 3 blocks at the end of the buffer are used to preload the filterbank for the next frame)
                validMemWriteAddr <= axi_araddr(29 downto 13);
                validMemWrEn <= '1';
            else
                validMemWrEn <= '0';
            end if;
            -- Need to delay writing to the valid memory by a few clocks, since we are also reading from the valid memory at the same time.
            -- The write must come after the read.
            validMemWriteAddrDel1 <= validMemWriteAddr;
            validMemWrEnDel1      <= validMemWrEn;
            
            validMemWriteAddrDel2 <= validMemWriteAddrDel1;
            validMemWrEnDel2      <= validMemWrEnDel1;
            
            o_validMemWriteAddr <= validMemWriteAddrDel2;
            o_validMemWrEn <= validMemWrEnDel2;
            
            -----------------------------------------------------------------------------
            -- State machine to read from the shared memory
            readStartDel1 <= i_readStart;
            readStartDel2 <= readStartDel1;
           
            rstDel1 <= i_rst;
            rstDel2 <= rstDel1;
            if rstDel1 = '1' and rstDel2 = '0' then
                rstInternal <= '1';
                rstCount <= "111111111";
            else
                rstInternal <= '0';
                if rstCount /= "000000000" then
                    rstCount <= std_logic_vector(unsigned(rstCount) - 1);
                end if;
            end if;
            if rstCount = "000000001" then
                rstFIFOs <= '1'; -- rstCount creates a delay before we reset the FIFOs, to ensure that any outstanding HBM requests have been returned.
            else
                rstFIFOs <= '0';
            end if;
            rstFIFOsDel1 <= rstFIFOs;
            
            if rstInternal = '1' then
                ar_fsm <= done;
            elsif i_readStart = '1' then
                -- start generating read addresses.
                ar_fsm <= getDelay0FirstWord;
                ar_virtualChannel <= (others => '0');
                ar_currentBuffer <= i_currentBuffer;
                ar_previousBuffer <= i_previousBuffer;
                ar_packetCount <= i_packetCount;
                ar_NChannels <= i_NChannels;
                ar_startPacket <= i_startPacket;
                ar_clocksPerPacket <= i_clocksPerPacket;
                axi_arvalid <= '0';
            else
                case ar_fsm is
                    ---------------------------------------------------------------------------
                    -- Read data from the delayTable
                    -- Before reading a group of 3 virtual channels, we have to get the coarse and fine delay information.
                    when getDelay0FirstWord =>
                        o_delayTableAddr <= ar_virtualChannel & "00";
                        ar_fsm <= getDelay0SecondWord;
                    
                    when getDelay0SecondWord =>
                        o_delayTableAddr <= ar_virtualChannel & "01";
                        ar_fsm <= getDelay0ThirdWord;
                        
                    when getDelay0ThirdWord => -- 3rd word is the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "10";
                        ar_fsm <= getDelay0FourthWord;
                        
                    when getDelay0FourthWord => -- 4th word is the step in the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "11";
                        ar_virtualChannel <= std_logic_vector(unsigned(ar_virtualChannel) + 1);
                        ar_fsm <= getDelay1FirstWord;


                    when getDelay1FirstWord =>
                        o_delayTableAddr <= ar_virtualChannel & "00";
                        ar_fsm <= getDelay1SecondWord;
                    
                    when getDelay1SecondWord =>
                        o_delayTableAddr <= ar_virtualChannel & "01";
                        ar_fsm <= getDelay1ThirdWord;
                        
                    when getDelay1ThirdWord => -- 3rd word is the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "10";
                        ar_fsm <= getDelay1FourthWord;
                        
                    when getDelay1FourthWord => -- 4th word is the step in the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "11";
                        ar_virtualChannel <= std_logic_vector(unsigned(ar_virtualChannel) + 1);
                        ar_fsm <= getDelay2FirstWord;
                    
                    when getDelay2FirstWord =>
                        o_delayTableAddr <= ar_virtualChannel & "00";
                        ar_fsm <= getDelay2SecondWord;
                    
                    when getDelay2SecondWord =>
                        o_delayTableAddr <= ar_virtualChannel & "01";
                        ar_fsm <= getDelay2ThirdWord;
                        
                    when getDelay2ThirdWord => -- 3rd word is the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "10";
                        ar_fsm <= getDelay2FourthWord;
                        
                    when getDelay2FourthWord => -- 4th word is the step in the phase offset.
                        o_delayTableAddr <= ar_virtualChannel & "11";
                        ar_virtualChannel <= std_logic_vector(unsigned(ar_virtualChannel) + 1);
                        ar_fsm <= waitDelaysValid;
                        arfsmWaitCount <= "100";
                    
                    when waitDelaysValid =>
                        -- wait for the latency of the delay memory so that coarse and fine delay signals are valid (buf0CoarseDelay etc.)
                        arfsmWaitCount <= std_logic_vector(unsigned(arfsmWaitCount) - 1);
                        if arfsmWaitCount = "000" then
                            ar_fsm <= getDataIdle;
                        end if;
                        
                    ----------------------------------------------------------------------------------
                    -- Read data from HBM
                    --  byte address within a buffer has 
                    --     - bits 12:0 = byte within an LFAA packet (LFAA packets are 8192 bytes)
                    --     - bits 17:13 = packet count within the buffer (up to 32 LFAA packets per buffer)
                    --     - bits 27:18 = virtual channel
                    --     - bits 29:28 = buffer selection
                    when getDataIdle =>
                        -- Check there is space available in the buffers, and if so then get more data for the buffer with the least amount of data
                        if ((unsigned(bufMaxUsed(0)) <= unsigned(bufMaxUsed(1))) and 
                            (unsigned(bufMaxUsed(0)) <= unsigned(bufMaxUsed(2))) and
                            (unsigned(bufMaxUsed(0)) < 116)) then
                            ar_fsm <= getBuf0Data;
                        elsif ((unsigned(bufMaxUsed(1)) <= unsigned(bufMaxUsed(2))) and (unsigned(bufMaxUsed(1)) < 116)) then
                            ar_fsm <= getBuf1Data;
                        elsif (unsigned(bufMaxUsed(2)) < 116) then
                            ar_fsm <= getBuf2Data;
                        end if;
                        axi_arvalid <= '0';
                         
                    when getBuf0Data =>  -- "buf0" in the name "getBuf0Data" refers to the particular virtual channel
                        axi_arvalid <= '1';
                        axi_araddr(29 downto 28) <= buf0Buffer; -- which HBM buffer
                        axi_araddr(27 downto 18) <= buf0VirtualChannel;
                        axi_araddr(17 downto 0) <= buf0Sample(15 downto 11) & buf0Sample(10 downto 0) & "00"; -- LFAA packet within the buffer (bits 17:13), sample (bits 12:2), 4 byte aligned (bits 1:0 = "00")
                        axi_arlen(2 downto 0) <= buf0Len;
                        ar_fsm <= waitARReady;

                    when getBuf1Data =>
                        axi_arvalid <= '1';
                        axi_araddr(29 downto 28) <= buf1Buffer; -- which HBM buffer
                        axi_araddr(27 downto 18) <= buf1VirtualChannel;
                        axi_araddr(17 downto 0) <= buf1Sample(15 downto 11) & buf1Sample(10 downto 0) & "00"; -- LFAA packet within the buffer (bits 17:13), sample (bits 12:2), 4 byte aligned (bits 1:0 = "00")
                        axi_arlen(2 downto 0) <= buf1Len;
                        ar_fsm <= waitARReady;
                    
                    when getBuf2Data =>
                        axi_arvalid <= '1';
                        axi_araddr(29 downto 28) <= buf2Buffer; -- which HBM buffer
                        axi_araddr(27 downto 18) <= buf2VirtualChannel;
                        axi_araddr(17 downto 0) <= buf2Sample(15 downto 11) & buf2Sample(10 downto 0) & "00"; -- LFAA packet within the buffer (bits 17:13), sample (bits 12:2), 4 byte aligned (bits 1:0 = "00")
                        axi_arlen(2 downto 0) <= buf2Len;
                        ar_fsm <= waitARReady;
                    
                    when waitARReady =>
                        if i_axi_arready = '1' then
                            axi_arvalid <= '0';
                            ar_fsm <= checkDone;
                        end if;
                        
                    when checkDone => -- check if we have more data to get for each virtual channel
                        if buf0HasMoreSamples = '1' or buf1HasMoreSamples = '1' or buf2HasMoreSamples = '1' then
                            ar_fsm <= getDataIdle;
                        else
                            ar_fsm <= checkAllVirtualChannelsDone;
                        end if; 
                    
                    when checkAllVirtualChannelsDone =>
                        if (unsigned(ar_NChannels) > unsigned(ar_virtualChannel)) then
                            ar_fsm <= getDelay0FirstWord; -- Get the next group of 3 virtual channels.
                        else
                            ar_fsm <= waitAllDone;
                        end if;
                    
                    
                    when waitAllDone =>
                        -- Wait until the ar_fifo is empty, since we should flag an error is we start up again without draining the fifo.
                        if ARFIFO_WrDataCount = "000000" then 
                            ar_fsm <= done;
                        end if;
                        
                    when done =>
                        ar_fsm <= done;
                        axi_arvalid <= '0';
                        
                    when others =>
                        ar_fsm <= done;
                end case;
            end if;
            
            ar_fsmDel1 <= ar_fsm;
            ar_fsmDel2 <= ar_fsmDel1;
            ar_fsmDel3 <= ar_fsmDel2;
            ar_fsmDel4 <= ar_fsmDel3;
            
            ar_virtualChannelDel1 <= ar_virtualChannel;
            ar_virtualChannelDel2 <= ar_virtualChannelDel1;
            ar_virtualChannelDel3 <= ar_virtualChannelDel2;
            ar_virtualChannelDel4 <= ar_virtualChannelDel3;
            
            -- Total space which could be used in the buffers after all pending reads return
            for i in 0 to 2 loop
                bufMaxUsed(i) <= std_logic_vector(unsigned(bufFIFO_wrDataCount(i)) + unsigned(pendingReads(i)));
            end loop;
            
            -- Capture, and update the delay information
            -- In the registers, word 0, bits 15:0  = Coarse delay, word 0 bits 31:16 = Hpol DeltaP, word 1 bits 15:0 = Vpol deltaP, word 1 bits 31:16 = deltaDeltaP
            -- For updates :
            --   DeltaDeltaP is the phase change in units which are 2^(-15) smaller than deltaP
            --   DeltaDeltaP is the phase change per 64 samples.
            -- So the equation is (applied at the output of the ar_fifo):
            --  DeltaP_out = deltaP + 2^(-15) * deltadeltaP * (sample - (first Sample))/64
            if ar_fsmDel4 = getDelay0FirstWord then
                buf0VirtualChannel <= ar_virtualChannelDel4;
                buf0CoarseDelay <= "00000" & i_delayTableData(10 downto 0);
                buf0HpolDeltaP <= i_delayTableData(31 downto 16);
                buf0FirstRead <= '1';
                buf0LastRead <= '0';
            elsif ar_fsmDel4 = getDelay0SecondWord then
                buf0VpolDeltaP <= i_delayTableData(15 downto 0);
                buf0DeltaDeltaP <= i_delayTableData(31 downto 16);
                -- Get the starting address to read from
                --  =  <last sample in the previous frame> - 4928 + coarse_delay
                -- (g_LFAA_BLOCKS_PER_FRAME, ar_currentBuffer, ar_previousBuffer)
                buf0Buffer <= ar_previousBuffer; -- initial reads are the pre-load data from the previous buffer
                buf0SampleTemp := std_logic_vector((g_LFAA_BLOCKS_PER_FRAME * 2048) - 4928 + unsigned(buf0CoarseDelay));
                buf0SampleTemp8bit := '0' & buf0SampleTemp(6 downto 0);
                -- Round it down so we have 64 byte aligned accesses to the HBM. Note buf0Sample is the sample within the buffer for this particular virtual channel
                buf0Sample <= buf0SampleTemp(15 downto 4) & "0000"; -- This gets multiplied by 4 to get the byte address, so the byte address will be 64 byte aligned.
                buf0SampleRelative_v := std_logic_vector(unsigned(buf0CoarseDelay) - 4928); -- Index of the sample to be read relative to the first sample in the buffer.
                buf0SampleRelative <= buf0SampleRelative_v(15) & buf0SampleRelative_v(15) & buf0SampleRelative_v(15) & buf0SampleRelative_v(15) & buf0SampleRelative_v;
                -- Number of 64 byte words to read.
                -- First read is chosen such that the remaining reads are aligned to a 512 byte boundary (i.e. 8*64 bytes).
                -- The 64 byte word we are reading within the current 512 byte block is buf0SampleTemp(6 downto 4)
                -- so if buf0SampleTemp(6:4) = "000" then length = 8, "001" => 7, "010" => 6, "011" => 5, "100" => 4, "101" => 3, "110" => 2, "111" => 1
                -- But axi length of "0000" means a length of 1. So buf0SampleTemp(6:4) = "000" -> length = "111", "001" => "110" etc.
                buf0Len <= not buf0SampleTemp(6 downto 4);  -- buf0Len = number of beats in the AXI memory transaction - 1.
                -- Up to 512 bytes per read = up to 128 samples per read (each sample is 4 bytes),
                -- so the number of samples read is the number to the next 512 byte boundary, i.e. 128 - buf0SampleTemp(6:0)
                buf0SamplesToRead <= std_logic_vector(128 - unsigned(buf0SampleTemp8bit));
                --buf0SamplesToRead <= std_logic_vector(unsigned((not buf0SampleTemp8bit)) + 1);  -- Number of valid samples that actually get read in the AXI memory transaction. 
                -- total number of samples per frame is g_LFAA_BLOCKS_PER_FRAME * 2048, plus the preload of 12*256 - 192 = 2880 samples
                buf0SamplesRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME * 2048 + 2880,16)); 
            elsif ar_fsm = getBuf0Data then
                buf0Sample <= std_logic_vector(unsigned(buf0Sample) + unsigned(buf0Len_ext) + 16);
                buf0SamplesToRead16bit := "00000000" & buf0SamplesToRead;
                buf0Lenx16 := "0000000000000" & buf0Len & "0000";
                -- buf0SampleRelative is the index of the sample corresponding to a 16 sample boundary in the readout in the first data word returned from the HBM
                -- It is used to determine the fine delay to use. Note +16 here because buf0Len is 1 less than the number of beats, and each beat is 16 samples.
                buf0SampleRelative <= std_logic_vector(signed(buf0SampleRelative) + signed(buf0Lenx16) + 16);  
                buf0SamplesRemaining <= std_logic_vector(unsigned(buf0SamplesRemaining) - unsigned(buf0SamplesToRead16bit));
                buf0FirstRead <= '0';
            elsif ar_fsmDel1 = getBuf0Data then  -- Second of two steps to update buf0Sample when we issue a read request
                if (unsigned(buf0Sample) = (g_LFAA_BLOCKS_PER_FRAME * 2048)) then -- i.e. if we have hit the end of the preload buffer, then go to the start of the next buffer.
                    buf0Sample <= (others => '0');
                    buf0Buffer <= ar_currentBuffer;
                end if;
                if (unsigned(buf0SamplesRemaining) <= 128) then
                    buf0LastRead <= '1';
                end if;
                if (unsigned(buf0SamplesRemaining) < 128) then -- last read can be shorter
                    if buf0SamplesRemaining(3 downto 0) = "0000" then
                        buf0Len <= std_logic_vector(unsigned(buf0SamplesRemaining(6 downto 4)) - 1); -- -1 since axi len is 1 less than number of words requested.
                    else
                        buf0Len <= buf0SamplesRemaining(6 downto 4); -- Low bits are non zero, so need to do a read to get those as well, hence no -1.
                    end if;
                    buf0SamplesToRead <= buf0SamplesRemaining(7 downto 0);
                else
                    buf0Len <= "111"; -- 8 beats. 
                    buf0SamplesToRead <= "10000000"; -- 128 samples in a full length (8 x 512 bit words) read.
                end if;
            end if;
            
            if (ar_fsmDel4 = getDelay0ThirdWord) then
                buf0PhaseOffset <= i_delayTableData(31 downto 0);
            end if;
            if (ar_fsmDel4 = getDelay0FourthWord) then
                buf0PhaseStep <= i_delayTableData(31 downto 0);
            end if;
            
            
            if ar_fsmDel4 = getDelay1FirstWord then
                buf1VirtualChannel <= ar_virtualChannelDel4;
                buf1CoarseDelay <= i_delayTableData(15 downto 0);
                buf1HpolDeltaP <= i_delayTableData(31 downto 16);
                buf1FirstRead <= '1';
                buf1LastRead <= '0';
            elsif ar_fsmDel4 = getDelay1SecondWord then -- same calculations as for buf0; see comments above.
                buf1VpolDeltaP <= i_delayTableData(15 downto 0);
                buf1DeltaDeltaP <= i_delayTableData(31 downto 16);
                buf1Buffer <= ar_previousBuffer; -- initial reads are the pre-load data from the previous buffer
                buf1SampleTemp := std_logic_vector((g_LFAA_BLOCKS_PER_FRAME * 2048) - 4928 + unsigned(buf1CoarseDelay));
                buf1SampleTemp8bit := '0' & buf1SampleTemp(6 downto 0);
                buf1Sample <= buf1SampleTemp(15 downto 4) & "0000"; -- This gets multiplied by 4 to get the byte address, so the byte address will be 64 byte aligned.
                buf1SampleRelative_v := std_logic_vector(unsigned(buf1CoarseDelay) - 4928); -- Index of the sample to be read relative to the first sample in the buffer.
                buf1SampleRelative <= buf1SampleRelative_v(15) & buf1SampleRelative_v(15) & buf1SampleRelative_v(15) & buf1SampleRelative_v(15) & buf1SampleRelative_v;
                buf1Len <= not buf1SampleTemp(6 downto 4);  -- buf2Len = number of beats in the AXI memory transaction - 1.
                --buf1SamplesToRead <= std_logic_vector(unsigned((not buf1SampleTemp8bit)) + 1);  -- Number of valid samples that actually get read in the AXI memory transaction.
                buf1SamplesToRead <= std_logic_vector(128 - unsigned(buf1SampleTemp8bit)); 
                buf1SamplesRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME * 2048 + 2880,16)); 
            elsif ar_fsm = getBuf1Data then
                buf1Sample <= std_logic_vector(unsigned(buf1Sample) + unsigned(buf1Len_ext) + 16);
                buf1SamplesToRead16bit := "00000000" & buf1SamplesToRead;
                buf1Lenx16 := "0000000000000" & buf1Len & "0000";
                buf1SampleRelative <= std_logic_vector(signed(buf1SampleRelative) + signed(buf1Lenx16) + 16);
                buf1SamplesRemaining <= std_logic_vector(unsigned(buf1SamplesRemaining) - unsigned(buf1SamplesToRead16bit));
                buf1FirstRead <= '0';
            elsif ar_fsmDel1 = getBuf1Data then  -- Second of two steps to update buf0Sample when we issue a read request
                if (unsigned(buf1Sample) = (g_LFAA_BLOCKS_PER_FRAME * 2048)) then -- i.e. if we have hit the end of the preload buffer, then go to the start of the next buffer.
                    buf1Sample <= (others => '0');
                    buf1Buffer <= ar_currentBuffer;
                end if;
                if (unsigned(buf1SamplesRemaining) <= 128) then
                    buf1LastRead <= '1';
                end if;
                if (unsigned(buf1SamplesRemaining) < 128) then -- The last read can be shorter.
                    if buf1SamplesRemaining(3 downto 0) = "0000" then
                        buf1Len <= std_logic_vector(unsigned(buf1SamplesRemaining(6 downto 4)) - 1); -- -1 since axi len is 1 less than number of words requested.
                    else
                        buf1Len <= buf1SamplesRemaining(6 downto 4); -- Low bits are non zero, so need to do a read to get those as well, hence no -1.
                    end if;
                    buf1SamplesToRead <= buf1SamplesRemaining(7 downto 0);
                else
                    buf1Len <= "111"; -- corresponds to 8 beats in the transaction
                    buf1SamplesToRead <= "10000000"; -- 128 samples in a full length (8 x 512 bit words) read.
                end if;
            end if;
            
            if (ar_fsmDel4 = getDelay1ThirdWord) then
                buf1PhaseOffset <= i_delayTableData(31 downto 0);
            end if;
            if (ar_fsmDel4 = getDelay1FourthWord) then
                buf1PhaseStep <= i_delayTableData(31 downto 0);
            end if;
            
            if ar_fsmDel4 = getDelay2FirstWord then
                buf2VirtualChannel <= ar_virtualChannelDel4;
                buf2CoarseDelay <= i_delayTableData(15 downto 0);
                buf2HpolDeltaP <= i_delayTableData(31 downto 16);
                buf2FirstRead <= '1';
                buf2LastRead <= '0';
            elsif ar_fsmDel4 = getDelay2SecondWord then
                buf2VpolDeltaP <= i_delayTableData(15 downto 0);
                buf2DeltaDeltaP <= i_delayTableData(31 downto 16);
                buf2Buffer <= ar_previousBuffer; -- initial reads are the pre-load data from the previous buffer
                buf2SampleTemp := std_logic_vector((g_LFAA_BLOCKS_PER_FRAME * 2048) - 4928 + unsigned(buf2CoarseDelay));
                buf2SampleTemp8bit := '0' & buf2SampleTemp(6 downto 0);
                buf2Sample <= buf2SampleTemp(15 downto 4) & "0000"; -- This gets multiplied by 4 to get the byte address, so the byte address will be 64 byte aligned.
                buf2SampleRelative_v := std_logic_vector(unsigned(buf2CoarseDelay) - 4928); -- Index of the sample to be read relative to the first sample in the buffer.
                buf2SampleRelative <= buf2SampleRelative_v(15) & buf2SampleRelative_v(15) & buf2SampleRelative_v(15) & buf2SampleRelative_v(15) & buf2SampleRelative_v;
                buf2Len <= not buf2SampleTemp(6 downto 4);  -- buf2Len = number of beats in the AXI memory transaction - 1.
                --buf2SamplesToRead <= std_logic_vector(unsigned((not buf2SampleTemp8bit)) + 1);  -- Number of valid samples that actually get read in the AXI memory transaction.
                buf2SamplesToRead <= std_logic_vector(128 - unsigned(buf2SampleTemp8bit)); 
                buf2SamplesRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME * 2048 + 2880,16));
            elsif ar_fsm = getBuf2Data then
                buf2Sample <= std_logic_vector(unsigned(buf2Sample) + unsigned(buf2Len_ext) + 16);
                buf2SamplesToRead16bit := "00000000" & buf2SamplesToRead;
                buf2Lenx16 := "0000000000000" & buf2Len & "0000";
                buf2SampleRelative <= std_logic_vector(signed(buf2SampleRelative) + signed(buf2Lenx16) + 16);
                buf2SamplesRemaining <= std_logic_vector(unsigned(buf2SamplesRemaining) - unsigned(buf2SamplesToRead16bit));
                buf2FirstRead <= '0';
            elsif ar_fsmDel1 = getBuf2Data then  -- Second of two steps to update buf0Sample when we issue a read request
                if (unsigned(buf2Sample) = (g_LFAA_BLOCKS_PER_FRAME * 2048)) then -- i.e. if we have hit the end of the preload buffer, then go to the start of the next buffer.
                    buf2Sample <= (others => '0');
                    buf2Buffer <= ar_currentBuffer;
                end if;
                if (unsigned(buf2SamplesRemaining) <= 128) then
                    buf2LastRead <= '1';
                end if;
                if (unsigned(buf2SamplesRemaining) < 128) then -- last read can be shorter
                    if buf2SamplesRemaining(3 downto 0) = "0000" then
                        buf2Len <= std_logic_vector(unsigned(buf2SamplesRemaining(6 downto 4)) - 1); -- -1 since axi len is 1 less than number of words requested.
                    else
                        buf2Len <= buf2SamplesRemaining(6 downto 4); -- Low bits are non zero, so need to do a read to get those as well, hence no -1.
                    end if;
                    buf2SamplesToRead <= buf2SamplesRemaining(7 downto 0);
                else
                    buf2Len <= "111"; -- corresponds to 8 beats in the transaction.
                    buf2SamplesToRead <= "10000000"; -- 128 samples in a full length (8 x 512 bit words) read.
                end if;
            end if;
            
            if (ar_fsmDel4 = getDelay2ThirdWord) then
                buf2PhaseOffset <= i_delayTableData(31 downto 0);
            end if;
            if (ar_fsmDel4 = getDelay2FourthWord) then
                buf2PhaseStep <= i_delayTableData(31 downto 0);
            end if;
            
            if (unsigned(buf0SamplesRemaining) > 0) then
                buf0HasMoreSamples <= '1';
            else
                buf0HasMoreSamples <= '0';
            end if;
            
            if (unsigned(buf1SamplesRemaining) > 0) then
                buf1HasMoreSamples <= '1';
            else
                buf1HasMoreSamples <= '0';
            end if;
            
            if (unsigned(buf2SamplesRemaining) > 0) then
                buf2HasMoreSamples <= '1';
            else
                buf2HasMoreSamples <= '0';
            end if;
            
            if i_readStart = '1' and ar_fsm /= done then
                -- Flag an error; we were asked to start reading but we haven't finished reading the previous frame.
                o_readOverflow <= '1';
            else
                o_readOverflow <= '0';
            end if;
        
            if ar_fsm = getBuf0Data then
                ARFIFO_wrEn <= '1';
                ARFIFO_din(1 downto 0) <= buf0Buffer; -- Destination buffer
                ARFIFO_din(2) <= buf0FirstRead; -- first read for a particular virtual channel
                ARFIFO_din(3) <= buf0LastRead; -- Last read for a particular virtual channel
                -- Low 4 bits of the Number of valid samples in this read.
                -- This is only needed for the first and last reads for a given channel.
                ARFIFO_din(7 downto 4) <= buf0SamplesToRead(3 downto 0); 
                ARFIFO_din(10 downto 8) <= buf0Len; -- Number of Beats in this read - 1. Range will be 0 to 7. (Note 8 beats = 8 x 512 bits = maximum size of a burst to the HBM)
                ARFIFO_din(15 downto 11) <= "00000"; -- unused
                ARFIFO_din(31 downto 16) <= buf0HpolDeltaP; -- HpolDeltaP
                ARFIFO_din(47 downto 32) <= buf0VpolDeltaP; -- VpolDeltaP
                ARFIFO_din(63 downto 48) <= buf0DeltaDeltaP; -- DeltaDeltaP
                ARFIFO_din(98 downto 97) <= "00";  -- indicates that this is stream 0 (i.e. the virtual channel loaded in the "getBuf0Data" state)
                ARFIFO_din(130 downto 99) <= buf0PhaseOffset;
                ARFIFO_din(157 downto 131) <= buf0PhaseStep(26 downto 0);
            elsif ar_fsm = getBuf1Data then
                ARFIFO_wrEn <= '1';
                ARFIFO_din(1 downto 0) <= buf1Buffer; -- Destination buffer
                ARFIFO_din(2) <= buf1FirstRead; -- first read for a particular virtual channel
                ARFIFO_din(3) <= buf1LastRead; -- Last read for a particular virtual channel
                ARFIFO_din(7 downto 4) <= buf1SamplesToRead(3 downto 0); 
                ARFIFO_din(10 downto 8) <= buf1Len; -- Number of Beats in this read - 1. Range will be 0 to 7. (Note 8 beats = 8 x 512 bits = maximum size of a burst to the HBM)
                ARFIFO_din(15 downto 11) <= "00000"; -- unused
                ARFIFO_din(31 downto 16) <= buf1HpolDeltaP; -- HpolDeltaP
                ARFIFO_din(47 downto 32) <= buf1VpolDeltaP; -- VpolDeltaP
                ARFIFO_din(63 downto 48) <= buf1DeltaDeltaP; -- DeltaDeltaP
                ARFIFO_din(98 downto 97) <= "01";
                ARFIFO_din(130 downto 99) <= buf1PhaseOffset;
                ARFIFO_din(157 downto 131) <= buf1PhaseStep(26 downto 0);
            elsif ar_fsm = getBuf2Data then -- ar_fsm = get_buf2
                ARFIFO_wrEn <= '1';
                ARFIFO_din(1 downto 0) <= buf2Buffer; -- Destination buffer
                ARFIFO_din(2) <= buf2FirstRead; -- first read for a particular virtual channel
                ARFIFO_din(3) <= buf2LastRead; -- Last read for a particular virtual channel
                ARFIFO_din(7 downto 4) <= buf2SamplesToRead(3 downto 0); -- Low 4 bits of the coarse delay for this virtual channel.
                ARFIFO_din(10 downto 8) <= buf2Len; -- Number of Beats in this read - 1. Range will be 0 to 7. (Note 8 beats = 8 x 512 bits = maximum size of a burst to the HBM)
                ARFIFO_din(15 downto 11) <= "00000"; -- unused            
                ARFIFO_din(31 downto 16) <= buf2HpolDeltaP; -- HpolDeltaP
                ARFIFO_din(47 downto 32) <= buf2VpolDeltaP; -- VpolDeltaP
                ARFIFO_din(63 downto 48) <= buf2DeltaDeltaP; -- DeltaDeltaP
                ARFIFO_din(98 downto 97) <= "10";
                ARFIFO_din(130 downto 99) <= buf2PhaseOffset;
                ARFIFO_din(157 downto 131) <= buf2PhaseStep(26 downto 0);
            else
                ARFIFO_wrEn <= '0';
            end if;
            -- Sample offset from the startpoint sample for the fine delay information 
            -- (i.e. relative to i_startpacket), for the first valid sample in this burst.
            -- 32 bit sample offset means a maximum delay of (2^32 samples) * 1080ns/sample = 4638 seconds
            -- Note this sample offset can be negative.
            --  ar_startPacket is the packet count that the fine delay information is referenced to. 
            --  ar_packetCount is the packet count for the first packet in the current buffer.
            -- So the number we want is 
            --  bufXSampleRelative + ar_packetCount * 2048 - ar_startPacket* 2048;
            fineDelayPacketOffset <= std_logic_vector(unsigned(ar_packetCount) - unsigned(ar_startPacket)); -- the packet count of the first packet in the buffer relative to the packet count that the fine timing is referenced to.
            fineDelaySampleOffset := fineDelayPacketOffset(20 downto 0) & "00000000000"; -- x2048 samples per packet
            if ar_fsm = getBuf0Data then
                sampleRelative := std_logic_vector(resize(signed(buf0SampleRelative),32));
            elsif ar_fsm = getBuf1Data then
                sampleRelative := std_logic_vector(resize(signed(buf1SampleRelative),32));
            else -- ar_fsm = getBuf2Data then
                sampleRelative := std_logic_vector(resize(signed(buf2SampleRelative),32));
            end if;
            ARFIFO_din(95 downto 64) <= std_logic_vector(signed(fineDelaySampleOffset) + signed(sampleRelative));

            -- Keep track of the number of pending read words in the ARFIFO for each buffer
            for i in 0 to 2 loop
                if (i_readStart = '1') then
                    pendingReads(i) <= (others => '0');
                elsif ARFIFO_wrEn = '1' and unsigned(ARFIFO_din(98 downto 97)) = i and (bufFIFO_wrEnDel1(i) = '0') then
                    -- When bufFIFO_wrEnDel1 is high, then the data stops being accounted for in "pendingReads" and is accounted for by bufFIFO_wrDataCount instead. 
                    pendingReads(i) <= std_logic_vector(unsigned(pendingReads(i)) + unsigned(ARFIFO_wrBeats) + 1);  -- ARFIFO_wrBeats is one less than the actual number of beats (as per AXI standard), so add one here.
                elsif (ARFIFO_wrEn = '0' or unsigned(ARFIFO_din(98 downto 97)) /= i) and (bufFIFO_wrEnDel1(i) = '1') then
                    pendingReads(i) <= std_logic_vector(unsigned(pendingReads(i)) - 1);
                elsif (ARFIFO_wrEn = '1' and unsigned(ARFIFO_din(98 downto 97)) = i and bufFIFO_wrEnDel1(i) = '1') then
                    pendingReads(i) <= std_logic_vector(unsigned(pendingReads(i)) + unsigned(ARFIFO_wrBeats) + 1 - 1); -- +1 to make ARFIFO_wrBeats the true number of beats, but -1 because a word got written into the buffer.
                end if;
                
            end loop;
            
            -- Delay writing to the FIFO until the valid data comes back.
            -- Convert the number of samples to read into an offset to start reading from.
            ARFIFO_dinDel1(3 downto 0) <= ARFIFO_din(3 downto 0);
            samplesToRead_v := '0' & ARFIFO_din(7 downto 4);
            readStartAddr_v := std_logic_vector(16 - unsigned(samplesToRead_v)); -- so, e.g. 1 sample to read = start reading from sample 15.
            ARFIFO_dinDel1(7 downto 4) <= readStartAddr_v(3 downto 0);
            ARFIFO_dinDel1(157 downto 8) <= ARFIFO_din(157 downto 8);
            
            ARFIFO_wrEnDel1 <= ARFIFO_wrEn;  -- ARFIFO_wrEn is valid in the same cycle as o_validMemReadAddr
            
            ARFIFO_dinDel2 <= ARFIFO_dinDel1;
            ARFIFO_wrEnDel2 <= ARFIFO_wrEnDel1;
            
            ARFIFO_dinDel3 <= ARFIFO_dinDel2;
            ARFIFO_wrEnDel3 <= ARFIFO_wrEnDel2;
            
            ARFIFO_dinDel4(95 downto 0) <= ARFIFO_dinDel3(95 downto 0);
            ARFIFO_dinDel4(96) <= i_validMemReadData;
            ARFIFO_dinDel4(157 downto 97) <= ARFIFO_dinDel3(157 downto 97);
            ARFIFO_wrEnDel4 <= ARFIFO_wrEnDel3;
            
            if i_validMemReadData = '0' and ARFIFO_wrEnDel3 = '1' then
                o_dataMissing <= '1'; -- we are reading from somewhere in memory that we haven't written data to.
            else
                o_dataMissing <= '0';
            end if;
            
        end if;
    end process;
    
    buf0Len_ext <= "000000000" & buf0Len & "0000";
    buf1Len_ext <= "000000000" & buf1Len & "0000";
    buf2Len_ext <= "000000000" & buf2Len & "0000";
    
    ARFIFO_wrBeats <= "000000" & ARFIFO_din(11 downto 8);
    ARFIFO_rdBeats <= "000000" & ARFIFO_dout(11 downto 8);
    
    -- FIFO for the read requests, so we know which buffer to put the data into when it is returned. (several read requests can be in flight at a time)
    --  Data that goes into this FIFO:  
    --  - bits 1:0   : Selects destination buffer
    --  - bit  2     : First read of a particular virtual channel for this frame (a "frame" is configurable but nominally 50ms) 
    --  - bit  3     : Last read of a particular virtual channel for this frame
    --  - bits 7:4   : number of valid samples (only applies to first or last reads for a channel)
    --  - bits 10:8  : Number of beats in this read (i.e. number of 512 bit data words to expect)
    --  - bits 15:11 : unused.
    --  - bits 31:16 : HPolDeltaP - fine delay phase shift across the band.
    --  - bits 47:32 : VPolDeltaP - fine delay phase shift across the band.
    --  - bits 63:48 : DeltaDeltaP
    --  - bits 95:64 : Sample offset from the starting sample for the fine delay information. 
    --  - bit  96    : invalid - no data was written to the shared memory, so data returned should be flagged invalid.
    --  - bit  98:97 : Which of the three streams that are simultaneously being read is this one ? "00", "01", "10"
    fifo_ar_inst : xpm_fifo_sync
    generic map (
        DOUT_RESET_VALUE => "0",    -- String
        ECC_MODE => "no_ecc",       -- String
        FIFO_MEMORY_TYPE => "distributed", -- String
        FIFO_READ_LATENCY => 1,     -- DECIMAL
        FIFO_WRITE_DEPTH => 32,     -- DECIMAL; Allow up to 32 outstanding read requests.
        FULL_RESET_VALUE => 0,      -- DECIMAL
        PROG_EMPTY_THRESH => 10,    -- DECIMAL
        PROG_FULL_THRESH => 10,     -- DECIMAL
        RD_DATA_COUNT_WIDTH => 6,   -- DECIMAL
        READ_DATA_WIDTH => 158,      -- DECIMAL
        READ_MODE => "fwft",        -- String
        SIM_ASSERT_CHK => 0,        -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        USE_ADV_FEATURES => "0404", -- String  -- bit 2 and bit 10 enables write data count and read data count
        WAKEUP_TIME => 0,           -- DECIMAL
        WRITE_DATA_WIDTH => 158,     -- DECIMAL
        WR_DATA_COUNT_WIDTH => 6    -- DECIMAL
    )
    port map (
        almost_empty => open,     -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
        almost_full => open,      -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
        data_valid => ARFIFO_validOut, -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
        dbiterr => open,          -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
        dout => ARFIFO_dout,      -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
        empty => ARFIFO_empty,    -- 1-bit output: Empty Flag: When asserted, this signal indicates that- the FIFO is empty.
        full => ARFIFO_full,      -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full.
        overflow => open,         -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is full
        prog_empty => open,       -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value.
        prog_full => open,        -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value.
        rd_data_count => ARFIFO_RdDataCount, -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
        rd_rst_busy => open,      -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
        sbiterr => open,          -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
        underflow => open,        -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty.
        wr_ack => open,           -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
        wr_data_count => ARFIFO_WrDataCount, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
        wr_rst_busy => open,      -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
        din => ARFIFO_dinDel4,    -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
        injectdbiterr => '0',     -- 1-bit input: Double Bit Error Injection
        injectsbiterr => '0',     -- 1-bit input: Single Bit Error Injection: 
        rd_en => ARFIFO_rdEn,     -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. 
        rst => ARFIFO_rst,        -- 1-bit input: Reset: Must be synchronous to wr_clk.
        sleep => '0',             -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
        wr_clk => shared_clk,     -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en => ARFIFO_wrEnDel4  -- 1-bit input: Write Enable: 
    );
    
    ARFIFO_rst <= rstFIFOs;
    ARFIFO_rdEn <= '1' when ar_regUsed = '0' and i_axi_rvalid = '1' else '0';  -- 
    
    process(shared_clk)
    begin
        if rising_edge(shared_clk) then
            -- Process data from the ar fifo ("ar_fifo_inst") as the corresponding data comes back from the shared memory
            -- Write to the buffer and the FIFOs associated with the buffer.
            --  Tasks :
            --   - Read from ar fifo
            --   - compute fine delays for each 512 bit word
            --   - Write to the buffer fifos
            --
            --   Buffer FIFO contents :
            --      - bits 15:0  = HDeltaP (HDeltaP and VDeltaP are the fine delay information placed in the meta info for this output data)
            --      - bits 31:16 = VDeltaP
            --      - bit 35:32  = S = Number of samples in the 512 bit word - 1. Note 512 bits = 64 bytes = 16 samples, so this ranges from 0 to 15
            --                     For the first word in a channel, the data will be left aligned, i.e. in bits(511 downto (512 - (S+1)*32))
            --                     while for the last word it will be right aligned, i.e. in bits((S+1)*32 downto 0).
            
            -- We need to calculate the fine delays HDeltaP and VDeltaP for each word we write to the buffer.
            -- This is done according to 
            --  output HDeltaP = HDeltaP + 2^(-15) * deltaDeltaP * (S - S_start)/64
            -- where :
            --   HDeltaP = value in ARFIFO_dout(31:16)      (which originally came from the delay table in the registers)
            --   deltaDeltaP = value in ARFIFO_dout(63:48)  (likewise originally from the delay table in the registers)
            --   S-S_start = derived from the value in ARFIFO_dout(95:64)
            --     The value in ARFIFO_dout(95:64) is the sample offset for the first 16-byte aligned sample in the burst for this read.
            --      - Note: that is 16 byte aligned relative to the coarse delay, not relative to the data in a word from the HBM
            --  
            -- The phase offset is also passed to the fine delay module. This is calculated as :
            --  phase offset = phaseOffset + phaseStep * (S - S_start)/64
            -- where phaseOffset = ARFIFO_dout(130 downto 99)
            --       phaseStep =  ARFIFO_dout(157 downto 131)
            --------------------------------------------------------------------------------------------------
            if i_axi_rvalid = '1' and ar_regUsed = '0' and ARFIFO_validout = '0' then
                -- Error; data returned from memory that we didn't expect
                o_Unexpected_rdata <= '1';
            else
                o_Unexpected_rdata <= '0';
            end if;
            
            if (rstFIFOs = '1' or i_readStart = '1') then
                bufWrAddr0 <= (others => '0');
                bufWrAddr1 <= (others => '0');
                bufWrAddr2 <= (others => '0');
            elsif i_axi_rvalid = '1' then
                if ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "00") or (ar_regUsed = '1' and rdata_stream = "00")) then
                    bufWrAddr0 <= std_logic_vector(unsigned(bufWrAddr0) + 1);
                end if;
                if ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "01") or (ar_regUsed = '1' and rdata_stream = "01")) then
                    bufWrAddr1 <= std_logic_vector(unsigned(bufWrAddr1) + 1);
                end if;
                if ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "10") or (ar_regUsed = '1' and rdata_stream = "10")) then
                    bufWrAddr2 <= std_logic_vector(unsigned(bufWrAddr2) + 1);
                end if;
            end if;
            
            -- As data comes back from the memory, generate the fine delays and write to the buffer fifos.
            -- if this is the first beat in the transaction, then fine delay data comes from ar_fifo, 
            -- otherwise the data is the captured version of the fifo output from the first beat.
            if i_readStart = '1' then  
                ar_regUsed <= '0';
            elsif ar_regUsed = '0' and i_axi_rvalid = '1' then
                --rdata_first <= ARFIFO_dout(2);   -- First read of a particular virtual channel for this frame (a "frame" is configurable but nominally 50ms) 
                --rdata_last <= ARFIFO_dout(3);    -- Last read of a particular virtual channel for this frame
                rdata_rdStartOffset <= ARFIFO_dout(7 downto 4);  -- number of valid samples (only applies to first or last reads for a channel)
                rdata_beats <= ARFIFO_dout(10 downto 8);        -- Number of beats in this read (i.e. number of 512 bit data words to expect); "000" = 1 beat, up to "111" = 8 beats.
                rdata_HDeltaP <= ARFIFO_dout(31 downto 16);     -- HPolDeltaP - fine delay phase shift across the band.
                rdata_VDeltaP <= ARFIFO_dout(47 downto 32);     -- VPolDeltaP - fine delay phase shift across the band.
                rdata_phaseOffset <= ARFIFO_dout(130 downto 99);
                rdata_phaseStep <= ARFIFO_dout(157 downto 131);
                rdata_deltaDeltaP <= ARFIFO_dout(63 downto 48);
                rdata_beatCount <= "001";  -- this value isn't used until the next beat arrives, at which point it matches with the definition of rdata_beats (= total beats - 1).
                if ARFIFO_dout(10 downto 8) = "000" then   -- 10:8 is the number of beats in the read; if it is "000" then there is one beat, so no need to hold over the data in the register.
                    ar_regUsed <= '0';
                else
                    ar_regUsed <= '1';
                end if;
                rdata_sampleOffset <= ARFIFO_dout(95 downto 64);
                rdata_dvalid <= ARFIFO_dout(96);
                rdata_stream <= ARFIFO_dout(98 downto 97);
            elsif ar_regUsed = '1' and i_axi_rvalid = '1' then
                
                rdata_beatCount <= std_logic_vector(unsigned(rdata_beatCount) + 1);
                rdata_sampleOffset <= std_logic_vector(unsigned(rdata_sampleOffset) + 16); -- Advance 16 samples each beat for the purposes of calculating the fine delay. (512 bit bus/32 bits per sample = 16 samples.)
                if rdata_beatCount = rdata_beats then
                    ar_regUsed <= '0';
                end if;
            
            end if;
            axi_rvalid_del1 <= i_axi_rvalid;
            
            -- calculate fine delay for each polarisation :
            --   deltaP final = deltaP + 2^(-21) * deltaDeltaP * sampleOffset
            -- deltaP is 16 bits 
            -- deltaDeltaP is 16 bits.
            -- SampleOffset is 32 bits.
            rdata_deltaDeltaPXsampleOffset <= signed(rdata_deltaDeltaP) * signed(rdata_sampleOffset);
            rdata_HDeltaPDel2 <= rdata_HDeltaP;
            rdata_VDeltaPDel2 <= rdata_VDeltaP;
            rdata_rdStartOffsetDel2 <= rdata_rdStartOffset;
            rdata_streamDel2 <= rdata_stream;
            axi_rvalid_del2 <= axi_rvalid_del1;
            
            rdata_phaseStepXsampleOffset <= signed(rdata_phaseStep) * signed(rdata_sampleOffset);   -- 27 bits x 32 bits = 59 bits
            rdata_HphaseOffsetDel2 <= rdata_phaseOffset(15 downto 0);
            rdata_VphaseOffsetDel2 <= rdata_phaseOffset(31 downto 16);
            
            -- Some pipeline stages are needed to get optimum performance from the multiplier.
            rdata_deltaDeltaPXsampleOffsetDel3 <= std_logic_vector(rdata_deltaDeltaPXsampleOffset);
            rdata_HDeltaPDel3 <= rdata_HDeltaPDel2;
            rdata_VDeltaPDel3 <= rdata_VDeltaPDel2;
            rdata_rdStartOffsetDel3 <= rdata_rdStartOffsetDel2;
            rdata_streamDel3 <= rdata_streamDel2;
            axi_rvalid_del3 <= axi_rvalid_del2;
            
            rdata_phaseStepXsampleOffsetDel3 <= std_logic_vector(rdata_phaseStepXsampleOffset);
            rdata_HphaseOffsetDel3 <= rdata_HphaseOffsetDel2;
            rdata_VphaseOffsetDel3 <= rdata_VphaseOffsetDel2;
            
            --
            rdata_deltaDeltaPXsampleOffsetDel4 <= rdata_deltaDeltaPXsampleOffsetDel3;
            rdata_HDeltaPDel4 <= rdata_HDeltaPDel3;
            rdata_VDeltaPDel4 <= rdata_VDeltaPDel3;
            rdata_rdStartOffsetDel4 <= rdata_rdStartOffsetDel3;
            rdata_streamDel4 <= rdata_streamDel3;
            axi_rvalid_del4 <= axi_rvalid_del3;
            
            rdata_phaseStepXsampleOffsetDel4 <= rdata_phaseStepXsampleOffsetDel3;
            rdata_HphaseOffsetDel4 <= rdata_HphaseOffsetDel3;
            rdata_VphaseOffsetDel4 <= rdata_VphaseOffsetDel3;
            
            -- Scale by 2^-21 and round 
            if (rdata_deltaDeltaPXsampleOffsetDel4(20) = '1' and rdata_deltaDeltaPXsampleOffsetDel4(21 downto 0) /= "0100000000000000000000") then
                -- unbiased rounding (round to nearest even value)
                rdata_roundupDel5 <= '1';
            else
                rdata_roundupDel5 <= '0';
            end if;
            rdata_deltaDeltaPXsampleOffsetDel5 <= rdata_deltaDeltaPXsampleOffsetDel4(47 downto 21);
            rdata_HDeltaPDel5 <= rdata_HDeltaPDel4;
            rdata_VDeltaPDel5 <= rdata_VDeltaPDel4;
            rdata_rdStartOffsetDel5 <= rdata_rdStartOffsetDel4;
            rdata_streamDel5 <= rdata_streamDel4;
            axi_rvalid_del5 <= axi_rvalid_del4;
            
            if (rdata_phaseStepXsampleOffsetDel4(21) = '1' and rdata_phaseStepXsampleOffsetDel4(22 downto 0) /= "01000000000000000000000") then
                -- unbiased rounding (round to nearest even value)
                rdata_phaseStepRoundupDel5 <= '1';
            else
                rdata_phaseStepRoundupDel5 <= '0';
            end if;            
            rdata_phaseStepXsampleOffsetDel5 <= rdata_phaseStepXsampleOffsetDel4(37 downto 22);  -- Drop 22 bits = 6 bit (step is per 64 LFAA samples) + 16 bit (to align to the value in rdata_phaseOffset)
            rdata_HphaseOffsetDel5 <= rdata_HphaseOffsetDel4;
            rdata_VphaseOffsetDel5 <= rdata_VphaseOffsetDel4;
            --
            if rdata_roundupDel5 = '1' then
                rdata_deltaDeltaPXsampleOffsetDel6 <= std_logic_vector(unsigned(rdata_deltaDeltaPXsampleOffsetDel5) + 1);
            else
                rdata_deltaDeltaPXsampleOffsetDel6 <= rdata_deltaDeltaPXsampleOffsetDel5;
            end if;
            rdata_HDeltaPDel6 <= std_logic_vector(resize(signed(rdata_HDeltaPDel5),27));
            rdata_VDeltaPDel6 <= std_logic_vector(resize(signed(rdata_VDeltaPDel5),27));
            rdata_rdStartOffsetDel6 <= rdata_rdStartOffsetDel5;
            rdata_streamDel6 <= rdata_streamDel5;
            axi_rvalid_del6 <= axi_rvalid_del5;
            
            if rdata_phaseStepRoundupDel5 = '1' then
                rdata_phaseStepXsampleOffsetDel6 <= std_logic_vector(unsigned(rdata_phaseStepXsampleOffsetDel5) + 1);
            else
                rdata_phaseStepXsampleOffsetDel6 <= rdata_phaseStepXsampleOffsetDel5;
            end if;
            rdata_HphaseOffsetDel6 <= rdata_HphaseOffsetDel5;
            rdata_VphaseOffsetDel6 <= rdata_VphaseOffsetDel5;
            
            --
            rdata_HDeltaPDel7 <= std_logic_vector(signed(rdata_HDeltaPDel6) + signed(rdata_deltaDeltaPXsampleOffsetDel6));
            rdata_VDeltaPDel7 <= std_logic_vector(signed(rdata_VDeltaPDel6) + signed(rdata_deltaDeltaPXsampleOffsetDel6));
            rdata_rdStartOffsetDel7 <= rdata_rdStartOffsetDel6;
            rdata_streamDel7 <= rdata_streamDel6;
            axi_rvalid_del7 <= axi_rvalid_del6;
            
            rdata_HphaseOffsetDel7 <= std_logic_vector(signed(rdata_HphaseOffsetDel6) + signed(rdata_phaseStepXsampleOffsetDel6));
            rdata_VphaseOffsetDel7 <= std_logic_vector(signed(rdata_VphaseOffsetDel6) + signed(rdata_phaseStepXsampleOffsetDel6));
            
            --
            bufFIFO_din(15 downto 0) <= rdata_HDeltaPDel7(15 downto 0);
            bufFIFO_din(31 downto 16) <= rdata_VDeltaPDel7(15 downto 0);
            
            bufFIFO_din(47 downto 32) <= rdata_HphaseOffsetDel7;
            bufFIFO_din(63 downto 48) <= rdata_VphaseOffsetDel7;
            
            bufFIFO_din(67 downto 64) <= rdata_rdStartOffsetDel7;
            if axi_rvalid_del7 = '1' and rdata_streamDel7 = "00" then
                bufFIFO_wrEn(0) <= '1';
            else
                bufFIFO_wrEn(0) <= '0';
            end if;
            if axi_rvalid_del7 = '1' and rdata_streamDel7 = "01" then
                bufFIFO_wrEn(1) <= '1';
            else
                bufFIFO_wrEn(1) <= '0';
            end if;
            if axi_rvalid_del7 = '1' and rdata_streamDel7 = "10" then
                bufFIFO_wrEn(2) <= '1';
            else
                bufFIFO_wrEn(2) <= '0';
            end if;
            
            bufFIFO_wrEnDel1 <= bufFIFO_wrEn;
        end if;
    end process;

    -- FIFOs for the data in the buffer.
    -- A word is written to one of these fifos every time a word is written to the buffer
    -- The read and write size of the FIFO keeps track of the number of valid words in the main buffer.
    bufFifoGen : for i in 0 to 2 generate
        buffer_fifo_inst : xpm_fifo_async
        generic map (
            CDC_SYNC_STAGES => 2,        -- DECIMAL
            DOUT_RESET_VALUE => "0",     -- String
            ECC_MODE => "no_ecc",        -- String
            FIFO_MEMORY_TYPE => "block", -- String
            FIFO_READ_LATENCY => 0,      -- DECIMAL; has to be zero for first word fall through (READ_MODE => "fwft")
            FIFO_WRITE_DEPTH => 512,     -- DECIMAL
            FULL_RESET_VALUE => 0,       -- DECIMAL
            PROG_EMPTY_THRESH => 10,     -- DECIMAL
            PROG_FULL_THRESH => 10,      -- DECIMAL
            RD_DATA_COUNT_WIDTH => 10,   -- DECIMAL
            READ_DATA_WIDTH => 68,       -- DECIMAL
            READ_MODE => "fwft",         -- String
            RELATED_CLOCKS => 0,         -- DECIMAL
            SIM_ASSERT_CHK => 0,         -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
            USE_ADV_FEATURES => "0404",  -- String "404" includes read and write data counts.
            WAKEUP_TIME => 0,            -- DECIMAL
            WRITE_DATA_WIDTH => 68,      -- DECIMAL
            WR_DATA_COUNT_WIDTH => 10    -- DECIMAL
        )
        port map (
            almost_empty => open,     -- 1-bit output: Almost Empty
            almost_full => open,      -- 1-bit output: Almost Full
            data_valid => open,       -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
            dbiterr => open,          -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
            dout => bufFIFO_dout(i),   -- READ_DATA_WIDTH-bit output: Read Data.
            empty => bufFIFO_empty(i), -- 1-bit output: Empty Flag: When asserted, this signal indicates that the FIFO is empty
            full => open,             -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. 
            overflow => open,         -- 1-bit output: Overflow
            prog_empty => open,       -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value. 
            prog_full => open,        -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value. 
            rd_data_count => bufFIFO_rdDataCount(i), -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count
            rd_rst_busy => open,      -- 1-bit output: Read Reset Busy
            sbiterr => open,          -- 1-bit output: Single Bit Error
            underflow => open,        -- 1-bit output: Underflow
            wr_ack => open,           -- 1-bit output: Write Acknowledge: Iindicates that a write request (wr_en) during the prior clock cycle is succeeded.
            wr_data_count => bufFIFO_wrDataCount(i), -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count
            wr_rst_busy => open,      -- 1-bit output: Write Reset Busy
            din => bufFIFO_din,       -- Same for all FIFOs, since we only write to one fifo at a time. WRITE_DATA_WIDTH-bit input: Write Data; 
            injectdbiterr => '0',     -- 1-bit input: Double Bit Error Injection
            injectsbiterr => '0',     -- 1-bit input: Single Bit Error Injection
            rd_clk => FB_clk,         -- 1-bit input: Read clock: Used for read operation. 
            rd_en => bufFIFO_rdEn(i),  -- 1-bit input: Read Enable.
            rst => rstFIFOsDel1,       -- 1-bit input: Reset: Must be synchronous to wr_clk
            sleep => '0',             -- 1-bit input: Dynamic power saving:
            wr_clk => shared_clk,     -- 1-bit input: Write clock:
            wr_en => bufFIFO_wrEn(i)   -- 1-bit input: Write Enable:
        );
    end generate;
    
    
    --bufWrAddr <= 
    --    "00" & bufWrAddr0 when ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "00") or (ar_regUsed = '1' and rdata_stream = "00")) else
    --    "01" & bufWrAddr1 when ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "01") or (ar_regUsed = '1' and rdata_stream = "01")) else
    --    "10" & bufWrAddr2; --  when ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "10") or (ar_regUsed = '1' and rdata_stream = "10"))
    --bufWE(0) <= i_axi_rvalid;
    --bufWrData <= 
    --    i_axi_rdata   when ((ar_regUsed = '0' and ARFIFO_dout(96) = '1') or (ar_regUsed = '1' and rdata_dvalid = '1')) else 
    --    x"80808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080";
        
    -- improve timing : Register the input to the main buffer memory.
    -- This makes placement easier, since the memory can end up being placed in a different SLR to the HBM
    process(shared_clk)
    begin
        if rising_edge(shared_clk) then
            if ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "00") or (ar_regUsed = '1' and rdata_stream = "00")) then
                bufWrAddr <= "00" & bufWrAddr0;
            elsif ((ar_regUsed = '0' and ARFIFO_dout(98 downto 97) = "01") or (ar_regUsed = '1' and rdata_stream = "01")) then
                bufWrAddr <= "01" & bufWrAddr1;
            else
                bufWrAddr <= "10" & bufWrAddr2;
            end if;
            bufWE(0) <= i_axi_rvalid;
            axi_rdataDel1 <= i_axi_rdata;
            if ((ar_regUsed = '0' and ARFIFO_dout(96) = '1') or (ar_regUsed = '1' and rdata_dvalid = '1')) then
                selRFI <= '0';
            else
                selRFI <= '1';
            end if;
        end if;
    end process;
    
    bufWrData <= axi_rdataDel1 when selRFI = '0' else x"80808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080808080";
    
    -- Memory to buffer data coming back from the shared memory.
    -- Write side :
    --   512 deep by 512 wide
    -- Read side :
    --   2048 deep by 128 wide
    main_buffer_inst : xpm_memory_sdpram
    generic map (    
        -- Common module generics
        MEMORY_SIZE             => 262144,          -- Total memory size in bits; 512 x 512 = 262144
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
        WRITE_DATA_WIDTH_A      => 512,             --positive integer
        BYTE_WRITE_WIDTH_A      => 512,             --integer; 8, 9, or WRITE_DATA_WIDTH_A value
        ADDR_WIDTH_A            => 9,               --positive integer
    
        -- Port B module generics
        READ_DATA_WIDTH_B       => 128,            --positive integer
        ADDR_WIDTH_B            => 11,              --positive integer
        READ_RESET_VALUE_B      => "0",            --string
        READ_LATENCY_B          => 3,              --non-negative integer
        WRITE_MODE_B            => "no_change")    --string; "write_first", "read_first", "no_change" 
    port map (
        -- Common module ports
        sleep                   => '0',
        -- Port A (Write side)
        clka                    => shared_clk,  -- clock for the shared memory, 300 MHz
        ena                     => '1',
        wea                     => bufWE,
        addra                   => bufWrAddr,
        dina                    => bufWrData,
        injectsbiterra          => '0',
        injectdbiterra          => '0',
        -- Port B (read side)
        clkb                    => FB_clk,  -- Filterbank clock, 450 MHz.
        rstb                    => '0',
        enb                     => '1',
        regceb                  => '1',
        addrb                   => bufRdAddr,
        doutb                   => bufDout,
        sbiterrb                => open,
        dbiterrb                => open
    );
    
    --------------------------------------------------------------------------------------------
    -- Signals that cross the clock domain from shared_clk to FB_clk
    --   - Via buffer (dual port memory) 
    --               - sample data
    --   - Via FIFOs (one word for every word in the buffer)
    --               - fine delays (VDeltaP, HDeltaP)
    --               - Number of valid samples in each word in the memory
    --   - Via cdc macro, at the start of every frame (i.e. when reading out a new buffer)
    --               - 32 bit timestamp for the first packet output
    --               - Number of clocks per 64 sample output packet
    --               - Number of virtual channels
    --   (- Generic : g_LFAA_BLOCKS_PER_FRAME - There are 2048 samples per LFAA block, 
    --    so the total number of 64 sample output packets in a buffer is (2048/64) * g_LFAA_BLOCKS_PER_FRAME = 32 * g_LFAA_BLOCKS_PER_FRAME.)
    -- 
    -- Readout of the data is triggered by data being passed across the cdc macro.
    -- Notes:
    --   - Notation:
    --        - "Frame", all the data in a single 256 Mbyte buffer, about 60 ms worth for all virtual channels
    --        - "burst", all frame data for a set of 3 virtual channels, since 3 virtual channels are output at a time.
    --            * There are ceil(virtual_channels/3) bursts per frame.
    --        - "packet", a block of 64 samples, for 3 virtual channels (or less in the final burst of the frame, if the number of virtual channels is not a multiple of 3).
    --            * Total number of packets per burst is g_LFAA_BLOCKS_PER_FRAME*32 + 45 
    --              (45*64 = 2880 = the number of preload samples)
    --   - There are 16 samples in a single buffer entry, so the number of entries in the buffer per burst per virtual channel is (at the input side of the memory) either:
    --         packets * 64/16 = g_LFAA_BLOCKS_PER_FRAME*128 + 180 (for the case where the first sample is aligned to a 64 byte boundary)
    --     or  g_LFAA_BLOCKS_PER_FRAME*128 + 180 + 1,              (for the case where the first sample is not aligned to a 64 byte boundary)
    --
    
    cdc_dataIn(15 downto 0) <= "0000" & ar_NChannels; -- 12 bit
    cdc_dataIn(31 downto 16) <= x"0056" when (unsigned(ar_clocksPerPacket) < 86) else ar_clocksPerPacket;   -- 16 bit; minimum possible value is 86.
    cdc_dataIn(63 downto 32) <= ar_packetCount;       -- 32 bit
    
    process(shared_clk)
    begin
        if rising_edge(shared_clk) then
            if readStartDel1 = '1' and readStartDel2 = '0' then
                shared_to_FB_send <= '1';
            elsif shared_to_FB_rcv = '1' then
                shared_to_FB_send <= '0';
            end if;
        end if;
    end process;
    
    xpm_cdc_handshake_inst : xpm_cdc_handshake
    generic map (
        DEST_EXT_HSK => 0,   -- DECIMAL; 0=internal handshake, 1=external handshake
        DEST_SYNC_FF => 4,   -- DECIMAL; range: 2-10
        INIT_SYNC_FF => 1,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_SYNC_FF => 4,    -- DECIMAL; range: 2-10
        WIDTH => 64         -- DECIMAL; range: 1-1024
    )
    port map (
        dest_out => cdc_dataOut, -- WIDTH-bit output. Input bus (src_in) synchronized to destination clock domain. Registered output.
        dest_req => shared_to_FB_valid, -- 1-bit output. Indicates dest_out is valid.
        dest_ack => '1',      -- 1-bit input: optional; required when DEST_EXT_HSK = 1
        dest_clk => FB_clk, -- 1-bit input: Destination clock.
        --        
        src_rcv => shared_to_FB_rcv,   -- 1-bit output: Acknowledgement from destination logic that src_in has been received. 
                              -- This signal will be deasserted once destination handshake has fully completed.
        src_clk => shared_clk,   -- 1-bit input: Source clock.
        src_in => cdc_dataIn,     -- WIDTH-bit input: Input bus that will be synchronized to the destination clock domain.
        src_send => shared_to_FB_send  -- 1-bit input: Only assert when src_rcv is deasserted, Deassert once src_rcv is asserted,
    );
    
    
    -- Memory readout 
    process(FB_clk)
    begin
        if rising_edge(FB_clk) then
            if shared_to_FB_valid = '1' then
                FBpacketCount <= cdc_dataOut(63 downto 32) & "00000";     -- Packet count at the start of the frame, output as meta data.
                FBClocksPerPacket <= cdc_dataOut(31 downto 16); -- Number of FB clock cycles per output packet
                FBNChannels <= cdc_dataOut(15 downto 0);         -- Number of virtual channels to read for the frame
            end if;
            
            shared_to_FB_valid_del1 <= shared_to_FB_valid;
            
            if shared_to_FB_valid_del1 = '1' then
                -- Start reading out the data from the buffer.
                -- This occurs once per frame (typically 60 ms).
                -- Buffers are always emptied at the end of a frame, so we always start from 0.
                bufReadAddr0 <= (others => '0');
                bufReadAddr1 <= (others => '0');
                bufReadAddr2 <= (others => '0');
                channelCount <= (others => '0');
                --rd_fsm <= rd_start;
                rd_fsm <= reset_output_fifos_start;
                buf0RdEnable <= '0';
                buf1RdEnable <= '0';
                buf2RdEnable <= '0';
                bufFIFO_rdEn(0) <= '0';
                bufFIFO_rdEn(1) <= '0';
                bufFIFO_rdEn(2) <= '0';
                sofFull <= '1';
            else
                case rd_fsm is
                    when idle =>
                        rd_fsm <= idle;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                        sof <= '0';
                        sofFull <= '0';
                    
                    when rd_start => -- start of reading for a particular group of 3 channels.
                        -- wait until data is available in the buffer, and get the start address from the FIFOs
                        if bufFIFOHalfFull = "111" then -- all three fifos have plenty of data; so readout won't result in underflow.
                            sof <= '1';
                            -- Write side of the buffer is 64 bytes wide, read side is 16 bytes wide, so to align the data 
                            -- we have to choose which of the 4 16byte words to start at, and which of the 4 samples to start at within that 16 byte word.
                            bufReadAddr0(1 downto 0) <= bufFIFO_dout(0)(67 downto 66);  
                            bufReadAddr1(1 downto 0) <= bufFIFO_dout(1)(67 downto 66);
                            bufReadAddr2(1 downto 0) <= bufFIFO_dout(2)(67 downto 66);
                            rdOffset(0) <= bufFIFO_dout(0)(65 downto 64);
                            rdOffset(1) <= bufFIFO_dout(1)(65 downto 64);
                            rdOffset(2) <= bufFIFO_dout(2)(65 downto 64);
                            bufFIFO_doutDel(0) <= bufFIFO_dout(0);
                            bufFIFO_doutDel(1) <= bufFIFO_dout(1);
                            bufFIFO_doutDel(2) <= bufFIFO_dout(2);
                            -- the number 16-byte words that we have to read from the buffer for each channel is
                            --    4*(g_LFAA_BLOCKS_PER_FRAME*128 + 180)     = g_LFAA_BLOCKS_PER_FRAME * 512 + 720
                            -- or 4*(g_LFAA_BLOCKS_PER_FRAME*128 + 180) + 1 = g_LFAA_BLOCKS_PER_FRAME * 512 + 721, depending on the alignment of the data.
                            if bufFIFO_dout(0)(65 downto 64) = "00" then
                                buf0WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 720,16));
                            else
                                buf0WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 721,16));
                            end if;
                            if bufFIFO_dout(1)(65 downto 64) = "00" then
                                buf1WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 720,16));
                            else
                                buf1WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 721,16));
                            end if;
                            if bufFIFO_dout(2)(65 downto 64) = "00" then
                                buf2WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 720,16));
                            else
                                buf2WordsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME*512 + 721,16));
                            end if;
                            rd_fsm <= rd_buf0;
                        else
                            sof <= '0';
                        end if;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                    
                    when rd_buf0 =>
                        rd_fsm <= rd_buf1;
                        sof <= '0';
                        sofFull <= '0';
                        bufRdAddr <= "00" & bufReadAddr0;  -- buffer 0 is the first 1/4 of the buffer, 128 x 64 byte words on the write side, 512x16 byte words on the read side.
                        if (rdStop(0) = '0' and buf0ReadDone = '0') then
                            bufReadAddr0 <= std_logic_vector(unsigned(bufReadAddr0) + 1);
                            buf0WordsRemaining <= std_logic_vector(unsigned(buf0WordsRemaining) - 1);
                            buf0RdEnable <= '1';
                            bufFIFO_doutDel(0) <= bufFIFO_dout(0);
                        else
                            buf0RdEnable <= '0';
                        end if;
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                        
                    when rd_buf1 =>
                        rd_fsm <= rd_buf2;
                        sof <= '0';
                        sofFull <= '0';
                        bufRdAddr <= "01" & bufReadAddr1;
                        if (rdStop(1) = '0' and buf1ReadDone = '0') then
                            bufReadAddr1 <= std_logic_vector(unsigned(bufReadAddr1) + 1);
                            buf1WordsRemaining <= std_logic_vector(unsigned(buf1WordsRemaining) - 1);
                            buf1RdEnable <= '1';
                            bufFIFO_doutDel(1) <= bufFIFO_dout(1);
                        else
                            buf1RdEnable <= '0';
                        end if;
                        buf0RdEnable <= '0';
                        buf2RdEnable <= '0';
                        
                    when rd_buf2 =>
                        rd_fsm <= rd_wait;
                        sof <= '0';
                        sofFull <= '0';
                        bufRdAddr <= "10" & bufReadAddr2;
                        if (rdStop(2) = '0' and buf2ReadDone = '0') then
                            bufReadAddr2 <= std_logic_vector(unsigned(bufReadAddr2) + 1);
                            buf2WordsRemaining <= std_logic_vector(unsigned(buf2WordsRemaining) - 1);
                            buf2RdEnable <= '1';
                            bufFIFO_doutDel(2) <= bufFIFO_dout(2);
                        else
                            buf2RdEnable <= '0';
                        end if;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                    
                    when rd_wait => -- tightest loop involves rd_buf0 -> rd_buf1 -> rd_buf2 -> rd_wait -> rd_buf0 ... . The rd_wait state is needed to ensure we don't send data to the output fifos more than 1 in every 4 clocks.
                        sof <= '0';
                        sofFull <= '0';
                        if (buf0ReadDone = '1' and buf1ReadDone = '1' and buf2ReadDone = '1' and allPacketsSent = '1') then 
                            -- Finished a full coarse channel (actually 3 coarse channels, since 3 channels at sent at a time).
                            -- Wait here until all the output packets have been sent so we can reset the output FIFOs before starting the next coarse channel.
                            rd_fsm <= reset_output_fifos;
                        elsif ((rdStop(0) = '0' and buf0ReadDone = '0') or 
                               (rdStop(1) = '0' and buf1ReadDone = '0') or
                               (rdStop(2) = '0' and buf2ReadDone = '0')) then  -- space is available in at least one of the output FIFOs
                            rd_fsm <= rd_buf0;
                        end if;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                    
                    when reset_output_fifos =>
                        sof <= '0';
                        sofFull <= '0';
                        rd_fsm <= reset_output_fifos_wait1;
                        -- depending on the coarse delay, we may have finished a channel not on a 64 byte boundary in the buffer.
                        -- If this is the case, then round up the read address to the next 64 byte boundary.
                        if bufReadAddr0(1 downto 0) /= "00" then
                            bufReadAddr0 <= std_logic_vector(unsigned(bufReadAddr0) + 4);
                        end if;
                        bufReadAddr0(1 downto 0) <= "00";
                        if bufReadAddr1(1 downto 0) /= "00" then
                            bufReadAddr1 <= std_logic_vector(unsigned(bufReadAddr1) + 4);
                        end if;
                        bufReadAddr1(1 downto 0) <= "00";
                        if bufReadAddr2(1 downto 0) /= "00" then
                            bufReadAddr2 <= std_logic_vector(unsigned(bufReadAddr2) + 4);
                        end if;
                        channelCount <= std_logic_vector(unsigned(channelCount) + 3);
                        bufReadAddr2(1 downto 0) <= "00";
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                    
                    when reset_output_fifos_start => -- this is just for the first group of 3 channels that are read out from the buffer. 
                        rd_fsm <= reset_output_fifos_wait1;
                    
                    when reset_output_fifos_wait1 =>
                        rd_fsm <= reset_output_fifos_wait2;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                        sof <= '0';
                        
                    when reset_output_fifos_wait2 =>
                        rd_fsm <= reset_output_fifos_wait;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                        sof <= '0';
                                            
                    when reset_output_fifos_wait =>
                        -- wait until the output fifos have finished reset.
                        if rstBusy = "000" then
                            if (unsigned(channelCount) >= unsigned(FBNChannels)) then
                                rd_fsm <= idle;
                            else
                                rd_fsm <= rd_start;
                            end if;
                        end if;
                        buf0RdEnable <= '0';
                        buf1RdEnable <= '0';
                        buf2RdEnable <= '0';
                        sof <= '0';
                        
                    when others =>
                        rd_fsm <= idle;
                end case;
                
                if (buf0RdEnable = '1' and bufRdAddr(1 downto 0) = "11") or (rd_fsm = reset_output_fifos and bufReadAddr0(1 downto 0) /= "00") then  
                    -- The read side of the buffer is 128 bits, write side is 512 bits.
                    -- So every 4th read (bufRdAddr(1:0) = "11") needs a new word from the FIFO.
                    -- Also read a new word at the end of the frame if we didn't use all the 4 pieces, since then the read addres skips up by 4 in the state rd_fsm.
                    bufFIFO_rdEn(0) <= '1';
                else
                    bufFIFO_rdEn(0) <= '0';
                end if;
                if (buf1RdEnable = '1' and bufRdAddr(1 downto 0) = "11") or (rd_fsm = reset_output_fifos and bufReadAddr1(1 downto 0) /= "00") then
                    bufFIFO_rdEn(1) <= '1';
                else
                    bufFIFO_rdEn(1) <= '0';
                end if;
                if (buf2RdEnable = '1' and bufRdAddr(1 downto 0) = "11") or (rd_fsm = reset_output_fifos and bufReadAddr2(1 downto 0) /= "00") then
                    bufFIFO_rdEn(2) <= '1';
                else
                    bufFIFO_rdEn(2) <= '0';
                end if;
                
            end if;
            for i in 0 to 2 loop
                if (unsigned(bufFIFO_rdDataCount(i)) > 64) then
                    bufFIFOHalfFull(i) <= '1';
                else
                    bufFIFOHalfFull(i) <= '0';
                end if;
            end loop;
            
            if (unsigned(buf0WordsRemaining) = 0) and (rd_fsm /= rd_start) then
                buf0ReadDone <= '1';
            else
                buf0ReadDone <= '0';
            end if;
            
            if (unsigned(buf1WordsRemaining) = 0) and (rd_fsm /= rd_start) then
                buf1ReadDone <= '1';
            else
                buf1ReadDone <= '0';
            end if;
            
            if (unsigned(buf2WordsRemaining) = 0) and (rd_fsm /= rd_start) then
                buf2ReadDone <= '1';
            else
                buf2ReadDone <= '0';
            end if;
            
            buf0RdEnableDel1 <= buf0RdEnable;
            buf1RdEnableDel1 <= buf1RdEnable;
            buf2RdEnableDel1 <= buf2RdEnable;
            
            buf0RdEnableDel2 <= buf0RdEnableDel1;
            buf1RdEnableDel2 <= buf1RdEnableDel1;
            buf2RdEnableDel2 <= buf2RdEnableDel1;
            
            bufRdValid(0) <= buf0RdEnableDel2;
            bufRdValid(1) <= buf1RdEnableDel2;
            bufRdValid(2) <= buf2RdEnableDel2;
            
            if rd_fsm = reset_output_fifos or rd_fsm = reset_output_fifos_start then
                readOutRst <= '1';
            else
                readOutRst <= '0';
            end if;
            
            
            -- Wait until data has got into the final fifo and then start the readout to the filterbanks
            -- There are 
            --  (g_LFAA_BLOCKS_PER_FRAME * 512 + 720) 16-byte clocks per frame
            -- = (g_LFAA_BLOCKS_PER_FRAME * 2048 + 2880) samples per frame
            -- = (g_LFAA_BLOCKS_PER_FRAME * 32 + 45) 64-sample packets per frame (per channel)
            if (rd_fsm = rd_start and bufFIFOHalfFull = "111") then
                readoutStart <= '1';
            else
                readoutStart <= '0';
            end if;
            
            readoutStartDel(0) <= readoutStart;
            readoutStartDel(15 downto 1) <= readoutStartDel(14 downto 0);
            
            FBClocksPerPacketMinusTwo <= std_logic_vector(unsigned(FBClocksPerPacket) - 2);
            if (unsigned(clockCount) < (unsigned(FBClocksPerPacketMinusTwo))) then
                clockCountIncrement <= '1';
            else
                clockCountIncrement <= '0';
            end if;
            
            if readoutStartDel(15) = '1' then
                packetsRemaining <= std_logic_vector(to_unsigned(g_LFAA_BLOCKS_PER_FRAME * 32 + 45,16));
                packetCount <= FBpacketCount;  -- packet count output in the meta data
                clockCount <= (others => '0');
                clockCountZero <= '1';
            elsif (unsigned(packetsRemaining) > 0) then
                -- Changed to improve timing, was : if (unsigned(clockCount) < (unsigned(FBClocksPerPacketMinusOne))) then
                if clockCountIncrement = '1' or clockCountZero = '1' then
                    clockCount <= std_logic_vector(unsigned(clockCount) + 1);
                    clockCountZero <= '0';  -- This signal is needed because of the extra cycle latency before clockCountIncrement becomes valid when clockCount is set to zero. 
                else
                    clockCount <= (others => '0');
                    clockCountZero <= '1';
                    packetsRemaining <= std_logic_vector(unsigned(packetsRemaining) - 1);
                    packetCount <= std_logic_vector(unsigned(packetCount) + 1);
                end if;
            end if;
            
            if ((unsigned(packetsRemaining) > 0) and (unsigned(clockCount) < 64)) then
                readPacket <= '1';
            else
                readPacket <= '0';
            end if;
            
            if (unsigned(packetsRemaining) = 0) then
                allPacketsSent <= '1';
            else
                allPacketsSent <= '0';
            end if;
            
            meta0VirtualChannel <= channelCount;
            meta1VirtualChannel <= std_logic_vector(unsigned(channelCount) + 1);
            meta2VirtualChannel <= std_logic_vector(unsigned(channelCount) + 2);
            
            if (unsigned(meta0VirtualChannel) < unsigned(FBNChannels)) then
                o_meta0.valid <= '1';
            else
                o_meta0.valid <= '0';
            end if;
            if (unsigned(meta1VirtualChannel) < unsigned(FBNChannels)) then
                o_meta1.valid <= '1';
            else
                o_meta1.valid <= '0';
            end if;
            if (unsigned(meta2VirtualChannel) < unsigned(FBNChannels)) then
                o_meta2.valid <= '1';
            else
                o_meta2.valid <= '0';
            end if;
            
            o_sofFull <= sof and sofFull;
            
        end if;
    end process;
    
    o_sof <= sof;
    
    outputFifoGen : for i in 0 to 2 generate
        outfifoInst: entity HBM_PktController_lib.pst_readout_32bit
        Port map(
            i_clk => FB_clk,
            i_rst => readOutRst, -- in std_logic;  -- Drive this high for one clock between each virtual channel.
            o_rstBusy => rstBusy(i), --  out std_logic;
            -- Data in from the buffer
            i_data => bufDout, -- in std_logic_vector(127 downto 0); --
            -- data in from the FIFO that shadows the buffer
            i_rdOffset => rdOffset(i), -- in std_logic_vector(1 downto 0);  -- Sample offset in the 128 bit word; 0 = use all 4 samples, "01" = Skip first sample, "10" = skip 2 samples, "11" = skip 3 samples; Only used on the first 128 bit word after i_rst.
            i_HDeltaP  => bufFIFO_doutDel(i)(15 downto 0), -- in std_logic_vector(15 downto 0);  -- use every 16th input for the meta data (each word in = 128 bits = 4 samples, so 16 inputs = 64 samples = 1 packet)
            i_VDeltaP  => bufFIFO_doutDel(i)(31 downto 16), -- in std_logic_vector(15 downto 0);
            i_HoffsetP => bufFIFO_doutDel(i)(47 downto 32), -- in (15:0);
            i_VoffsetP => bufFIFO_doutDel(i)(63 downto 48), -- in (15:0);
            i_valid    => bufRdValid(i), -- in std_logic; -- should go high no more than once every 4 clocks
            o_stop     => rdStop(i), -- out std_logic;
            -- data out
            o_data    => readoutData(i),    -- out std_logic_vector(31 downto 0);
            o_HDeltaP => readoutHDeltaP(i), -- out std_logic_vector(15 downto 0);
            o_VDeltaP => readoutVDeltaP(i), -- out std_logic_vector(15 downto 0); 
            o_HoffsetP => readoutHOffsetP(i), -- out (15:0);
            o_VoffsetP => readoutVOffsetP(i), -- out (15:0);
            i_run     => readPacket,        -- in std_logic -- should go high for a burst of 64 clocks to output a packet.
            o_valid   => validOut(i)        -- out std_logic;
        );
    end generate;
    
    o_valid <= validOut(0);
    
    o_HPol0(0) <= readoutData(0)(7 downto 0);  -- 8 bit real part
    o_HPol0(1) <= readoutData(0)(15 downto 8); -- 8 bit imaginary part
    o_VPol0(0) <= readoutData(0)(23 downto 16); -- 8 bit real part
    o_VPol0(1) <= readoutData(0)(31 downto 24); -- 8 bit imaginary part
    o_meta0.HDeltaP <= readoutHDeltaP(0);
    o_meta0.VDeltaP <= readoutVDeltaP(0);
    o_meta0.HoffsetP <= readoutHoffsetP(0);
    o_meta0.VoffsetP <= readoutVoffsetP(0);
    o_meta0.frameCount <= packetCount;         -- frameCount(36:0), = high 32 bits is the LFAA frame count, low 5 bits is the 64 sample block within the frame. 
    o_meta0.virtualChannel <= meta0VirtualChannel;     -- virtualChannel(15:0) = Virtual channels are processed in order, so this just counts.
    
    o_HPol1(0) <= readoutData(1)(7 downto 0);  -- 8 bit real part
    o_HPol1(1) <= readoutData(1)(15 downto 8); -- 8 bit imaginary part
    o_VPol1(0) <= readoutData(1)(23 downto 16); -- 8 bit real part
    o_VPol1(1) <= readoutData(1)(31 downto 24); -- 8 bit imaginary part
    o_meta1.HDeltaP <= readoutHDeltaP(1);
    o_meta1.VDeltaP <= readoutVDeltaP(1);
    o_meta1.HoffsetP <= readoutHoffsetP(1);
    o_meta1.VoffsetP <= readoutVoffsetP(1);
    o_meta1.frameCount <= packetCount;
    o_meta1.virtualChannel <= meta1VirtualChannel;
    
    o_HPol2(0) <= readoutData(2)(7 downto 0);  -- 8 bit real part
    o_HPol2(1) <= readoutData(2)(15 downto 8); -- 8 bit imaginary part
    o_VPol2(0) <= readoutData(2)(23 downto 16); -- 8 bit real part
    o_VPol2(1) <= readoutData(2)(31 downto 24); -- 8 bit imaginary part
    o_meta2.HDeltaP <= readoutHDeltaP(2);
    o_meta2.VDeltaP <= readoutVDeltaP(2);
    o_meta2.HoffsetP <= readoutHoffsetP(2);
    o_meta2.VoffsetP <= readoutVoffsetP(2);
    o_meta2.frameCount <= packetCount;
    o_meta2.virtualChannel <= meta2VirtualChannel;
    
    
    
    -----------------------------------------------------------------------------------------------
--    u_readoutshared_ila : ila_beamData
--    port map (
--        clk => shared_clk,
--        probe0(0) => '0',
--        probe0(6 downto 1) => ARFIFO_RdDataCount, -- 6 bit
--        probe0(12 downto 7) => ARFIFO_WrDataCount, -- 6 bit
--        probe0(21 downto 13) => bufWrAddr,  -- 9 bit
--        probe0(31 downto 22) => bufFIFO_wrDataCount(0), -- 10 bit
--        probe0(47 downto 32) => buf0SamplesRemaining,  -- 16 bit
        
--        probe0(48) => axi_arvalid,
--        probe0(49) => i_axi_arready,
--        probe0(79 downto 50) => axi_araddr,
--        probe0(82 downto 80) => axi_arlen,
        
--        probe0(83) => i_axi_rvalid,
--        probe0(84) => i_axi_rlast,
--        probe0(100 downto 85) => i_axi_rdata(15 downto 0),
        
--        probe0(119 downto 101) => (others => '0') 
--    );
    
--    u_readoutFBCLK_ila : ila_2
--    port map (
--        clk => FB_clk,
--        probe0(0) => validOut(0),
--        probe0(9 downto 1) => bufReadAddr0(8 downto 0),
--        probe0(19 downto 10) => bufFIFO_rdDataCount(0),
--        probe0(20) =>  bufFIFO_empty(0),
--        probe0(23 downto 21) => bufFIFOHalfFull,
--        probe0(55 downto 24) => packetCount(31 downto 0),
--        probe0(63 downto 56) => (others => '0')
--    );
    
    
end Behavioral;


