----------------------------------------------------------------------------------
-- Company:  CSIRO
-- Engineer: David Humphrey (dave.humphrey@csiro.au)
-- 
-- Create Date: 15.01.2020 16:58:24
-- Module Name: IC_FBInput - Behavioral
-- Project Name: SKA Perentie
-- Description: 
--  * Takes packets from the correlator filterbank signal processing chain, 
--  * Chops the packets into pieces, with a smaller number of fine channels in each packet.
--     - This is done so that the destination can get data for all stations for a smaller set of fine channels.
--     - The number of pieces the packets need to be broken into depends on the number of stations the system 
--       is configured for. When there are more stations, there are more correlators, each of which processes a 
--       smaller number of fine channels.
--  * Adds the header words.
--  * Sends to an interconnect input buffer. 
-- 
--  Because multiple packets can come out for every packet that comes in, the output gets 
--  progressively further behind the input as headers have to be inserted into all the output packets.
--  The input packets go into a FIFO to cater for this.
-- 
-- Data Input
--  Input packets have 3456 fine channels, corresponding to the output of the correlator filterbank.
--  Input packets consist of 4 data complex streams - 2 stations x 2 polarisations x 2 bytes/sample (re+im) = 8 bytes per sample.
-- 
--  Input packets must be fragmented to fit into jumbo frames. Input packets are longer than the original LFAA frames because:
--    * Packets contain data for two stations
--    * The correlator filterbank operates on 4096 sample blocks, double the size of LFAA packets, which have 2048 samples.

-- Data Output
--  Each input packet is broken into a set of smaller output packets, with :
--    PISA    : 3456/6 = 576 fine channels. For PISA, these will need to be reassembled into 3456 fine channels at the destination.
--  Note: Other potential array releases would need different splits, as below :
--    AA1     : 3456/6 = 576 fine channels.
--    AA2     : 3456/18 = 192 fine channels.
--    AA3-ITF : 3456/12 = 288 fine channels.
--    AA3-CPF : 3456/18 = 192 fine channels.
--    AA4     : 3456/36 = 96 fine channels.
--  However, fine splits such as AA4 would result in more than 25Gb/sec of output bandwidth due to the header overhead.
--  So it may be prefereable to do the finer split after the first hop. Since all splits are multiples of 6, the initial version
--  of this module just implements a /6 split.
--  
--
--  Each output packet is a stream of 64 bit words, consisting of :
--    Word      Contents
--     1        Header address word, used for routing within and between FPGAs. Bit fields are:
--                 (63:52) <= myX & myY & ZDest; -- destination XYZ
--                 (51:40) <= myX & myY & myZ;   -- SRC1 - address of this FPGA
--                 (39:28) <= x"fff";            -- SRC2 - unused - only a single hop on the Z network is required
--                 (27:16) <= x"fff";            -- SRC3 - unused
--                 (15:8)  <= "00000001";        -- 0x01 identifies this as a LFAA ingest --> CTC packet.
--                 (7:0)   <= x"00";             -- Used as the SOF indicator when sent over the optics.
--     2        First word of packet meta data header. 
--              The header is of type t_fd_output_header, defined in dsp_top_pkg
--     3        Second word of the packet meta data header.
--     4-579    Data for each fine channel. 576 words, corresponds to 3456/6 = 576 fine channels.
--              Bit fields are :
--                 (7:0)   = station ID0, V pol, real
--                 (15:8)  = station ID0, V pol, imag
--                 (23:16) = station ID0, H pol, real
--                 (31:24) = station ID0, H pol, imag
--                 (39:32) = station ID1, V pol, real
--                 (47:40) = station ID1, V pol, imag
--                 (55:48) = station ID1, H pol, real
--                 (63:56) = station ID1, H pol, imag
--
--  For the 3456 input words, there are (576 + 3) * 6 = 3474 output words. As
--  As the data comes from the 4096 point correlator filterbank FFT,
--  packets will be spaced by at least 4096 clocks, so there is plenty of time to 
--  attach the header to each of the 6 output packets for each input packet.
--                
-- -------------------------------------------------------------------------------
-- Structure
--  data in ---> header clock crossing --> output_fsm (partitions packets and inserts headers) -> output packets.
--           \-> data FIFO             -/
-- 
--  The output_fsm waits for the header to come through the clock crossing, then waits until there are 128 words in the FIFO.
--  Then it starts sending packets.
-- The FIFO is dual clock to support different clocks for the interconnect and signal chains.
--
-- Clock rates
--  The data FIFO is 512 deep x 66 bits. Incoming packets are 3456 data words, outgoing packets are
--  576 data words. 
--  We start reading the FIFO when it has 128 words in it. This means we have 384 words space before overflow occurs.
--  To prevent FIFO overflow, the read clock should be (approximately) > (write clock(1 - 384/3456)), i.e. > 90% of the write clock. 
--  To prevent FIFO underflow, the read clock should be  < (1 + 128/576), i.e. < 1.22 * the write clock.
--  e.g. for a write clock of 400 MHz, the read clock should be between about 360 and 488 MHz.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library dsp_top_lib;
use dsp_top_lib.dsp_top_pkg.all;
Library xpm;
use xpm.vcomponents.all;

entity IC_FBInput is
    generic(
        ARRAYRELEASE : integer range 0 to 5 := 0 -- 0 = PISA = no splitting of packets.
    );
    port(
        -- Input data.
        i_clk        : in std_logic;
        i_rst        : in std_logic;    -- on i_clk.
        i_corHeader  : in t_FD_output_header;              -- meta data belonging to the data coming out of the fine Delay (FD). Assumed valid in the first clock of i_corDataValid
        i_corData    : in t_ctc_output_data_a(1 downto 0); -- The actual output data; 2 stations, 2 polarisations, complex 8 bit data.
        i_corValid   : in std_logic;
        -- Configuration (on i_IC_clk)
        i_myAddr : in std_logic_vector(11 downto 0); -- X,Y and Z coordinates of this FPGA in the array (needed for routing).
        -- Packets output.
        i_IC_clk : in std_logic;     -- Interconnect clock (about 400 MHz). (i_clk * 0.9) < i_IC_clk < (i_clk * 1.2). See notes on clock rates above.
        o_data   : out std_logic_vector(63 downto 0);
        o_valid  : out std_logic;
        o_sof    : out std_logic;
        o_eof    : out std_logic;
        -- Error conditions (all on i_IC_clk)
        i_errorClear     : in std_logic;   -- clear error flags.
        o_overflow       : out std_logic;  -- FIFO overflow
        o_underflow      : out std_logic;  -- FIFO underflow (read when empty).
        o_dataNotAligned : out std_logic   -- Data FIFO output should have first word bit set at the start of the frame.
    );
end IC_FBInput;

architecture Behavioral of IC_FBInput is

    signal fifoDin   : std_logic_vector(65 downto 0);
    signal validDel1 : std_logic;
    signal rstDel1   : std_logic;

    signal hdrIn, hdrOut : std_logic_vector(127 downto 0);
    signal hdrInValid, hdrOutValid : std_logic;
    signal hdrInrcv : std_logic;
    
    signal fifoDout : std_logic_vector(65 downto 0);
    signal fifoRdEn : std_logic;
    signal fifoEmpty, fifoFull, fifo_rd_rst_busy, fifo_wr_rst_busy : std_logic;
    signal fifoRdDataCount : std_logic_vector(9 downto 0);
    signal fifoWrDataCount : std_logic_vector(9 downto 0);    

    type rd_fsm_type is (idle, waitFIFO, wrAddrWord, wrHdr1, wrHdr2, wrRestOfPacket, finishPacket);
    signal rd_fsm : rd_fsm_type := idle;
    signal fineChannel : std_logic_vector(15 downto 0);
    signal hdr : t_FD_output_header;
    signal hdr_slv : std_logic_vector(127 downto 0);
    signal sof, eof : std_logic;
    signal myX, myY, myZ : std_logic_vector(3 downto 0);
    signal fineChannelsRemaining : std_logic_vector(11 downto 0);
    signal packetsSent : std_logic_vector(3 downto 0);
    signal bufDin : std_logic_vector(63 downto 0);
    signal bufValid : std_logic;
    signal hdrOutAck : std_logic;
    signal setNotAligned : std_logic;
    signal fifoOverflow : std_logic;
    signal fifoOverflowICclk : std_logic;

begin

    -----------------------------------------------------------
    -- Transfer the header information to the i_IC_clk domain
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_corValid = '1' and validDel1 = '0' then
                hdrInValid <= '1';
                hdrIn <= header_to_slv(i_corHeader);
            elsif hdrInrcv = '1' then
                hdrInValid <= '0';
            end if;
        end if;
    end process;
    
    
    xpm_cdc_handshake1i : xpm_cdc_handshake
    generic map (
        -- Common module generics
        DEST_EXT_HSK   => 1, -- integer; 0=internal handshake, 1=external handshake
        DEST_SYNC_FF   => 2, -- integer; range: 2-10
        INIT_SYNC_FF   => 0, -- integer; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 1, -- integer; 0=disable simulation messages, 1=enable simulation messages. Turn this off so it doesn't complain about violating recommended behaviour or src_send.
        SRC_SYNC_FF    => 2, -- integer; range: 2-10
        WIDTH          => 128 -- integer; range: 1-1024
    )
    port map (
        src_clk  => i_clk,
        src_in   => hdrIn, -- src_in is captured by internal registers on the rising edge of src_send (i.e. in the first src_clk where src_send = '1')
        src_send => hdrInValid,
        src_rcv  => hdrInrcv,
        dest_clk => i_IC_clk,
        dest_req => hdrOutValid,
        dest_ack => hdrOutAck, -- optional; required when DEST_EXT_HSK = 1
        dest_out => hdrOut
    );
    
    --------------------------------------------------------------------------
    -- Packet data goes to a FIFO to get to the i_iC_clk domain.
    -- Fifo is 512 x 66 bits.
    -- On the write side of the FIFO, packets are 3456 x 66 bits
    -- On the read side, packets are 576 x 66 bits. 
    -- The read side should be at least as fast as the write side.
    process(i_clk)
    begin
        if rising_edge(i_clk) then
        
            validDel1 <= i_corValid;
            rstDel1 <= i_rst;
            fifoDin(7 downto 0) <= i_corData(0).data.vpol.re;
            fifoDin(15 downto 8) <= i_corData(0).data.vpol.im;
            fifoDin(23 downto 16) <= i_corData(0).data.hpol.re;
            fifoDin(31 downto 24) <= i_corData(0).data.hpol.im;
            fifoDin(39 downto 32) <= i_corData(1).data.vpol.re;
            fifoDin(47 downto 40) <= i_corData(1).data.vpol.im;
            fifoDin(55 downto 48) <= i_corData(1).data.hpol.re;
            fifoDin(63 downto 56) <= i_corData(1).data.hpol.im;
            fifoDin(64) <= i_corValid and (not validDel1); -- First word of the packet
            
        end if;
    end process;
    fifoDin(65) <= validDel1 and (not i_corValid);  -- Last word of the packet. 

    xpm_fifo_async_inst : xpm_fifo_async
    generic map (
        CDC_SYNC_STAGES => 2,       -- Integer, Range: 2 - 8. Specifies the number of synchronization stages on the CDC path.
        DOUT_RESET_VALUE => "0",    -- String, Reset value of read data path.
        ECC_MODE => "no_ecc",       -- String, Allowed values: no_ecc, en_ecc.
        FIFO_MEMORY_TYPE => "block", -- String, Allowed values: auto, block, distributed. 
        FIFO_READ_LATENCY => 2,     -- Integer, Range: 0 - 10. Must be 0 for first READ_MODE = "fwft" (first word fall through).    
        FIFO_WRITE_DEPTH => 512,    -- Integer, Range: 16 - 4194304. Defines the FIFO Write Depth. Must be power of two.
        FULL_RESET_VALUE => 0,      -- Integer, Range: 0 - 1. Sets full, almost_full and prog_full to FULL_RESET_VALUE during reset
        PROG_EMPTY_THRESH => 10,    -- Integer, Range: 3 - 4194301.Specifies the minimum number of read words in the FIFO at or below which prog_empty is asserted.
        PROG_FULL_THRESH => 10,     -- Integer, Range: 5 - 4194301. Specifies the maximum number of write words in the FIFO at or above which prog_full is asserted.
        RD_DATA_COUNT_WIDTH => 10,  -- Integer, Range: 1 - 23. Specifies the width of rd_data_count. To reflect the correct value, the width should be log2(FIFO_READ_DEPTH)+1. FIFO_READ_DEPTH = FIFO_WRITE_DEPTH*WRITE_DATA_WIDTH/READ_DATA_WIDTH         
        READ_DATA_WIDTH => 66,      -- Integer, Range: 1 - 4096. Defines the width of the read data port, dout
        READ_MODE => "std",         -- String, Allowed values: std, fwft. Default value = std.
        RELATED_CLOCKS => 0,        -- Integer, Range: 0 - 1. Specifies if the wr_clk and rd_clk are related having the same source but different clock ratios                    |
        --SIM_ASSERT_CHK => 0,        -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        USE_ADV_FEATURES => "0404", -- String
        -- |---------------------------------------------------------------------------------------------------------------------|
        -- | Enables data_valid, almost_empty, rd_data_count, prog_empty, underflow, wr_ack, almost_full, wr_data_count,         |
        -- | prog_full, overflow features.                                                                                       |
        -- |                                                                                                                     |
        -- |   Setting USE_ADV_FEATURES[0] to 1 enables overflow flag;     Default value of this bit is 1                        |
        -- |   Setting USE_ADV_FEATURES[1]  to 1 enables prog_full flag;    Default value of this bit is 1                       |
        -- |   Setting USE_ADV_FEATURES[2]  to 1 enables wr_data_count;     Default value of this bit is 1                       |
        -- |   Setting USE_ADV_FEATURES[3]  to 1 enables almost_full flag;  Default value of this bit is 0                       |
        -- |   Setting USE_ADV_FEATURES[4]  to 1 enables wr_ack flag;       Default value of this bit is 0                       |
        -- |   Setting USE_ADV_FEATURES[8]  to 1 enables underflow flag;    Default value of this bit is 1                       |
        -- |   Setting USE_ADV_FEATURES[9]  to 1 enables prog_empty flag;   Default value of this bit is 1                       |
        -- |   Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count;     Default value of this bit is 1                       |
        -- |   Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0                       |
        -- |   Setting USE_ADV_FEATURES[12] to 1 enables data_valid flag;   Default value of this bit is 0                       |
        WAKEUP_TIME => 0,           -- Integer, Range: 0 - 2. 0 = Disable sleep 
        WRITE_DATA_WIDTH => 66,     -- Integer, Range: 1 - 4096. Defines the width of the write data port, din             
        WR_DATA_COUNT_WIDTH => 10   -- Integer, Range: 1 - 23. Specifies the width of wr_data_count. To reflect the correct value, the width should be log2(FIFO_WRITE_DEPTH)+1.   |
    )
    port map (
        almost_empty => open, -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
        almost_full => open,  -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
        data_valid => open,   -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
        dbiterr => open,      -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
        dout => fifoDout,     -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
        empty => fifoEmpty,   -- 1-bit output: Empty Flag: When asserted, this signal indicates that
                              -- the FIFO is empty. Read requests are ignored when the FIFO is empty, initiating a read while empty is not destructive to the FIFO.
        full => fifoFull,     -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full. Write requests are ignored when the FIFO is full,
                              -- initiating a write when the FIFO is full is not destructive to the contents of the FIFO.
        overflow => open,     -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is
                              -- full. Overflowing the FIFO is not destructive to the contents of the FIFO.
        prog_empty => open,   -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable
                              -- empty threshold value. It is de-asserted when the number of words in the FIFO exceeds the programmable empty threshold value.
        prog_full => open,    -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the
                              -- programmable full threshold value. It is de-asserted when the number of words in the FIFO is less than the programmable full threshold value.
        rd_data_count => fifoRdDataCount, -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
        rd_rst_busy => fifo_rd_rst_busy,  -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
        sbiterr => open,                  -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
        underflow => open,         -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty. Under flowing the FIFO is not destructive to the FIFO.
        wr_ack => open,            -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
        wr_data_count => fifoWrDataCount,    -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
        wr_rst_busy => fifo_wr_rst_busy, -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
        din => fifoDin,       -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
        injectdbiterr => '0', -- 1-bit input: Double Bit Error Injection: Injects a double bit error if the ECC feature is used on block RAMs or UltraRAM macros.
        injectsbiterr => '0', -- 1-bit input: Single Bit Error Injection: Injects a single bit error if the ECC feature is used on block RAMs or UltraRAM macros.
        rd_clk => i_IC_clk,   -- 1-bit input: Read clock: Used for read operation. rd_clk must be a free running clock.
        rd_en => fifoRdEn,    -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. Must be held active-low when rd_rst_busy is active high.
        rst => rstDel1,       -- 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be unstable at the time of applying reset, but reset must be released only after the clock(s) is/are stable.
        sleep => '0',         -- 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo block is in power saving mode.
        wr_clk => i_clk,      -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en => validDel1    -- bit input: Write Enable: If the FIFO is not full, asserting this signal causes data (on din) to be written to the FIFO. Must be held active-low when rst or wr_rst_busy is active high.
    );
    
    
    -- detect FIFO overflow, and pass the notification to the i_IC_clk clock domain
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            fifoOverflow <= fifoFull;
        end if;
    end process;
    
    xpm_cdc_pulse_inst : xpm_cdc_pulse
    generic map (
        DEST_SYNC_FF => 2,
        RST_USED     => 0,
        SIM_ASSERT_CHK => 0)
    port map (
        src_clk => i_clk,
        src_rst => i_rst,
        src_pulse => fifoOverflow,
        dest_clk => i_IC_clk,
        dest_rst => '0',
        dest_pulse => fifoOverflowICclk
    );
    
    --------------------------------------------------------------------------
    -- State machine to read the header information and the data from the FIFO
    -- and construct the output packets
    
    hdr_slv <= header_to_slv(hdr);
    
    myZ <= i_myAddr(3 downto 0);
    myY <= i_myAddr(7 downto 4);
    myX <= i_myAddr(11 downto 8);
    
    process(i_IC_clk)
    begin
        if rising_edge(i_IC_clk) then
            
            ----------------------------------------------------
            -- Error conditions
            if i_errorClear = '1' then
                o_underflow <= '0';
            elsif fifoRdEn = '1' and fifoEmpty = '1' then
                o_underflow <= '1';
            end if;
            
            if i_errorClear = '1' then
                o_dataNotAligned <= '0';
            elsif setNotAligned = '1' then
                o_dataNotAligned <= '1';
            end if;
            
            if i_errorClear = '1' then
                o_overflow <= '0';
            elsif fifoOverflowICClk = '1' then
                o_overflow <= '1';
            end if;
            
            -----------------------------------------------------
            -- Acknowledge the clock crossing.
            if rd_fsm = idle and hdrOutValid = '1' then
                hdrOutAck <= '1';
            elsif hdrOutValid = '0' then
                hdrOutAck <= '0';
            end if;
            
            -- State machine
            --  - Get the first word from the FIFO
            --  - Generate the address word and send to the URAM
            --  - Send the rest of the data to the URAM
            case rd_fsm is
                when idle =>
                    if hdrOutValid = '1' then -- Capture the header from the clock crossing
                        rd_fsm <= waitFIFO;
                        hdr <= slv_to_header(hdrOut);
                    end if;
                    hdr.fine_channel <= (others => '0');
                    bufValid <= '0';
                    fifoRdEn <= '0';
                    sof <= '0';
                    eof <= '0';
                    setNotAligned <= '0';
                    packetsSent <= "0000";  -- Count the 6 output packets per input packet. 
                
                when waitFIFO =>
                    if (unsigned(fifoRdDataCount) > 127) then  -- Wait until we have some data in the FIFO, so we don't cause underrun. 
                        rd_fsm <= wrAddrWord;
                    end if;
                    sof <= '0';
                    eof <= '0';
                    bufValid <= '0';
                    fifoRdEn <= '0';
                    setNotAligned <= '0';
                    
                when wrAddrWord =>
                    rd_fsm <= wrHdr1;
                    -- Address word at the front of the packet contains DEST, SRC1, SRC2, SRC3, TYPE, SOF
                    bufDin(63 downto 52) <= myX & myY & myZ; -- destination XYZ; Destination is currently the same as the source.
                    bufDin(51 downto 40) <= myX & myY & myZ; -- SRC1 - address of this FPGA
                    bufDin(39 downto 28) <= x"fff"; -- SRC2 - unused - only a single hop on the Z network is required
                    bufDin(27 downto 16) <= x"fff"; -- SRC3 - unused
                    bufDin(15 downto 8) <= t_FD_output_header_ID; -- Identifies this as a correlator fine delay output packet. Constant is defined in dsp_top_pkg.
                    bufDin(7 downto 0) <= x"00";   -- Used as the SOF indicator when sent over the optics. 
                    bufValid <= '1';
                    fineChannelsRemaining <= x"23F"; -- 0x23F = 575; 576 fine channels per packet.
                    fifoRdEn <= '1';  -- FIFO has a 2 cycle latency; FIFO read data is used in the state wrRestOfPacket. 
                    sof <= '1';
                    eof <= '0';
                    setNotAligned <= '0';
                
                when wrHdr1 =>
                    rd_fsm <= wrHdr2;
                    bufDin <= hdr_slv(63 downto 0);
                    bufValid <= '1';
                    fifoRdEn <= '1';
                    sof <= '0';
                    eof <= '0';
                    setNotAligned <= '0';
                
                when wrHdr2 =>
                    rd_fsm <= wrRestOfPacket;
                    bufDin <= hdr_slv(127 downto 64);
                    bufValid <= '1';
                    fifoRdEn <= '1';
                    sof <= '0';
                    eof <= '0';
                    setNotAligned <= '0';
                    hdr.fine_channel <= std_logic_vector(unsigned(hdr.fine_channel) + 576);
                    packetsSent <= std_logic_vector(unsigned(packetsSent) + 1);
                
                when wrRestOfPacket =>
                    bufDin <= fifoDout(63 downto 0);
                    bufValid <= '1';
                    fineChannelsRemaining <= std_logic_vector(unsigned(fineChannelsRemaining) - 1);
                    if (unsigned(fineChannelsRemaining) > 2) then   -- 2 cycle read latency for the FIFO
                        fifoRdEn <= '1';
                    else
                        fifoRdEn <= '0';
                    end if;
                    if (unsigned(fineChannelsRemaining) = 1) then
                        rd_fsm <= finishPacket;
                    end if;
                    if (fifoDout(64) = '0' and (unsigned(fineChannelsRemaining) = 575) and (packetsSent = "0001")) then
                        -- start of data not set, and this is the first fine channel of the first output packet for this input packet. 
                        setNotAligned <= '1';
                    else
                        setNotAligned <= '0';
                    end if;
                    sof <= '0';
                    eof <= '0';
                
                when finishPacket => 
                    -- 
                    bufDin <= fifoDout(63 downto 0);
                    bufValid <= '1';
                    sof <= '0';
                    eof <= '1';
                    setNotAligned <= '0';
                    if (unsigned(packetsSent) = 6) then
                        rd_fsm <= idle;
                    else
                        rd_fsm <= waitFIFO;
                    end if;
                
                when others =>
                    rd_fsm <= idle;
            end case;
            
            
        end if;
    end process;
    
    o_data <= bufDin;
    o_valid <= bufValid;
    o_sof <= sof;
    o_eof <= eof;
    
end Behavioral;
