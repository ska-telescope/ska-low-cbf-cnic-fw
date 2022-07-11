----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.03.2021 15:00:34
-- Design Name: 
-- Module Name: highLatencyRamModel - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
--  Model of the HBM to use in the testbench.
--  Includes a high read latency, to mimic the real HBM.
--  The memory is 1 MByte in size, using the low 20 bits of the address.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library xpm;
use xpm.vcomponents.all;

entity highLatencyRamModel is
    generic (
        AXI_ADDR_WIDTH : integer := 64;  -- ! Warning - only the low 20 bits are used.
        AXI_ID_WIDTH : integer := 1;
        AXI_DATA_WIDTH : integer := 256;
        READ_QUEUE_SIZE : integer := 16;
        MIN_LAG : integer := 80   
    );
    Port (
        i_clk : in std_logic;
        i_rst_n : in std_logic;
        --
        axi_awvalid : in std_logic;
        axi_awready : out std_logic;
        axi_awaddr  : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        axi_awid    : in std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
        axi_awlen   : in std_logic_vector(7 downto 0);
        axi_awsize  : in std_logic_vector(2 downto 0);
        axi_awburst : in std_logic_vector(1 downto 0);
        axi_awlock  : in std_logic_vector(1 downto 0);
        axi_awcache : in std_logic_vector(3 downto 0);
        axi_awprot  : in std_logic_vector(2 downto 0);
        axi_awqos   : in std_logic_vector(3 downto 0);
        axi_awregion : in std_logic_vector(3 downto 0);
        axi_wvalid   : in std_logic;
        axi_wready   : out std_logic;
        axi_wdata    : in std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        axi_wstrb    : in std_logic_vector(AXI_DATA_WIDTH/8-1 downto 0);
        axi_wlast    : in std_logic;
        axi_bvalid   : out std_logic;
        axi_bready   : in std_logic;
        axi_bresp    : out std_logic_vector(1 downto 0);
        axi_bid      : out std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
        axi_arvalid  : in std_logic;
        axi_arready  : out std_logic;
        axi_araddr   : in std_logic_vector(AXI_ADDR_WIDTH-1 downto 0);
        axi_arid     : in std_logic_vector(AXI_ID_WIDTH-1 downto 0);
        axi_arlen    : in std_logic_vector(7 downto 0);
        axi_arsize   : in std_logic_vector(2 downto 0);
        axi_arburst  : in std_logic_vector(1 downto 0);
        axi_arlock   : in std_logic_vector(1 downto 0);
        axi_arcache  : in std_logic_vector(3 downto 0);
        axi_arprot   : in std_logic_Vector(2 downto 0);
        axi_arqos    : in std_logic_vector(3 downto 0);
        axi_arregion : in std_logic_vector(3 downto 0);
        axi_rvalid   : out std_logic;
        axi_rready   : in std_logic;
        axi_rdata    : out std_logic_vector(AXI_DATA_WIDTH-1 downto 0);
        axi_rlast    : out std_logic;
        axi_rid      : out std_logic_vector(AXI_ID_WIDTH - 1 downto 0);
        axi_rresp    : out std_logic_vector(1 downto 0)
    );
end highLatencyRamModel;

architecture Behavioral of highLatencyRamModel is

    signal nowCount : integer := 0;
    signal now32bit : std_logic_vector(31 downto 0);
    signal axi_araddr_20bit : std_logic_vector(19 downto 0);
    signal axi_awaddr_20bit : std_logic_vector(19 downto 0);
    signal axi_arFIFO_din : std_logic_vector(63 downto 0);
    signal axi_arFIFO_wren : std_logic;
    signal axi_arFIFO_WrDataCount : std_logic_vector(5 downto 0);
    signal axi_arFIFO_dout : std_logic_vector(63 downto 0);
    signal axi_arFIFO_empty : std_logic;
    signal axi_arFIFO_rdEn : std_logic;

    signal axi_araddr_delayed : std_logic_vector(19 downto 0);
    signal axi_arlen_delayed : std_logic_vector(7 downto 0);
    signal axi_reqTime : std_logic_vector(31 downto 0);
    
    signal axi_arvalid_delayed, axi_arready_delayed : std_logic;
    signal axi_arsize_delayed : std_logic_vector(2 downto 0);   -- 5 = 32 bytes per beat = 256 bit wide bus. -- out std_logic_vector(2 downto 0);
    signal axi_arburst_delayed : std_logic_vector(1 downto 0);   -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
    signal axi_arcache_delayed : std_logic_vector(3 downto 0);  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    signal axi_arprot_delayed : std_logic_vector(2 downto 0);   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    signal axi_arqos_delayed : std_logic_vector(3 downto 0); -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    signal axi_arregion_delayed : std_logic_vector(3 downto 0);

    COMPONENT axi_bram_ctrl_1Mbyte256bit
    PORT (
        s_axi_aclk : IN STD_LOGIC;
        s_axi_aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awlock : IN STD_LOGIC;
        s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awvalid : IN STD_LOGIC;
        s_axi_awready : OUT STD_LOGIC;
        s_axi_wdata : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
        s_axi_wstrb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axi_wlast : IN STD_LOGIC;
        s_axi_wvalid : IN STD_LOGIC;
        s_axi_wready : OUT STD_LOGIC;
        s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid : OUT STD_LOGIC;
        s_axi_bready : IN STD_LOGIC;
        s_axi_araddr : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arlock : IN STD_LOGIC;
        s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC);
    END COMPONENT;

    signal rcount : std_logic_vector(31 downto 0) := x"00000000";
    signal axi_rdataTemp : std_logic_vector(255 downto 0);

begin

    -- Address bits selected for the second stage corner turn
    --     Given F = Fine Channel  (0 to 215)
    --           V = virtual channel (0 to up to 1023)
    --           T = Time within the block (0 to 288, assuming the first stage corner turn is 27 LFAA blocks)
    --     Then the sample address =  V*2^16*2 + T*216*2 + F
    --        and the byte address = 4 * (V*2^16*2 + T*216*2 + F)
    
    -- So to allow enough space for 32 timestamps (the smallest corner turn allowed), we need T = 32,
    -- 32*216*2*4 = 55296, so we need the low 16 bits.
    -- V*2^16*2*4 = 524288, so bits 28:19 select the virtual channel.
 
    axi_araddr_20bit(19 downto 16) <= axi_araddr(22 downto 19);
    axi_araddr_20bit(15 downto 0) <= axi_araddr(15 downto 0); 
    
    axi_awaddr_20bit(19 downto 16) <= axi_awaddr(22 downto 19);
    axi_awaddr_20bit(15 downto 0) <= axi_awaddr(15 downto 0);  -- 2 buffers
    
    -- Alternative : Allow space for 64 timestamps, 8 channels
    
    axi_araddr_20bit(19 downto 16) <= axi_araddr(22 downto 19);
    axi_araddr_20bit(15 downto 0) <= axi_araddr(15 downto 0); 
    
    axi_awaddr_20bit(19 downto 16) <= axi_awaddr(22 downto 19);
    axi_awaddr_20bit(15 downto 0) <= axi_awaddr(15 downto 0);  -- 2 buffers
    
    
    ----
    --m02_araddr_20bit(19 downto 18) <= m02_araddr(29 downto 28);  -- 4 buffers
    --m02_araddr_20bit(17 downto 15) <= m02_araddr(20 downto 18);  -- up to 8 virtual channels 
    --m02_araddr_20bit(14 downto 0) <= m02_araddr(14 downto 0);  -- 15 bits allocated = 32768 bytes, for packed time samples from the PST filterbank, so T*216 * 4 = 32768 => T = up to 37. This means this will work for a corner turn with 3 LFAA packets.
    
    --m02_awaddr_20bit(19 downto 18) <= m02_awaddr(29 downto 28);  -- 4 buffers
    --m02_awaddr_20bit(17 downto 15) <= m02_awaddr(20 downto 18);  -- up to 8 virtual channels 
    --m02_awaddr_20bit(14 downto 0) <= m02_awaddr(14 downto 0);  -- corresponds to space for up to 32 PST time samples (=output from 3 LFAA packets)
    
    -- FIFO for AR commands, to emulate the large latency of the HBM.
    -- Data stored in the fifo is the ar bus:
    --   m02_araddr_20bit - 20 bits
    --   m02_arlen        - 8 bits
    --   m02_arsize = "101"
    --   m02_arburst = "01"
    --   m02_arcache = "0011"
    --   m02_arprot = "000"
    --   
    process(i_clk)
    begin
        if rising_edge(i_clk) then
            nowCount <= nowCount + 1;
            
            assert not ((axi_araddr(18 downto 16) /= "000" or axi_araddr(31 downto 23) /= "000000000") and axi_arvalid = '1') report "ignored address bits are non-zero" severity failure;
            assert not ((axi_awaddr(18 downto 16) /= "000" or axi_awaddr(31 downto 23) /= "000000000") and axi_awvalid = '1') report "ignored address bits are non-zero" severity failure;
            
        end if;
    end process;
    
    now32bit <= std_logic_vector(to_unsigned(nowCount,32));
    
    axi_arFIFO_din(19 downto 0) <= axi_araddr_20bit;
    axi_arFIFO_din(27 downto 20) <= axi_arlen;
    axi_arFIFO_din(63 downto 32) <= now32bit;
    axi_arFIFO_wren <= axi_arvalid and axi_arready;
    axi_arready <= '1' when (unsigned(axi_arFIFO_wrDataCount) < READ_QUEUE_SIZE) else '0';
    
    fifo_m02_ar_inst : xpm_fifo_sync
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
        READ_DATA_WIDTH => 64,      -- DECIMAL
        READ_MODE => "fwft",        -- String
        SIM_ASSERT_CHK => 0,        -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        USE_ADV_FEATURES => "0404", -- String  -- bit 2 and bit 10 enables write data count and read data count
        WAKEUP_TIME => 0,           -- DECIMAL
        WRITE_DATA_WIDTH => 64,     -- DECIMAL
        WR_DATA_COUNT_WIDTH => 6    -- DECIMAL
    )
    port map (
        almost_empty => open,      -- 1-bit output: Almost Empty : When asserted, this signal indicates that only one more read can be performed before the FIFO goes to empty.
        almost_full => open,       -- 1-bit output: Almost Full: When asserted, this signal indicates that only one more write can be performed before the FIFO is full.
        data_valid => open,        -- 1-bit output: Read Data Valid: When asserted, this signal indicates that valid data is available on the output bus (dout).
        dbiterr => open,           -- 1-bit output: Double Bit Error: Indicates that the ECC decoder detected a double-bit error and data in the FIFO core is corrupted.
        dout => axi_arFIFO_dout,   -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven when reading the FIFO.
        empty => axi_arFIFO_empty, -- 1-bit output: Empty Flag: When asserted, this signal indicates that- the FIFO is empty.
        full => open,              -- 1-bit output: Full Flag: When asserted, this signal indicates that the FIFO is full.
        overflow => open,          -- 1-bit output: Overflow: This signal indicates that a write request (wren) during the prior clock cycle was rejected, because the FIFO is full
        prog_empty => open,        -- 1-bit output: Programmable Empty: This signal is asserted when the number of words in the FIFO is less than or equal to the programmable empty threshold value.
        prog_full => open,         -- 1-bit output: Programmable Full: This signal is asserted when the number of words in the FIFO is greater than or equal to the programmable full threshold value.
        rd_data_count => open,     -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the number of words read from the FIFO.
        rd_rst_busy => open,       -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read domain is currently in a reset state.
        sbiterr => open,           -- 1-bit output: Single Bit Error: Indicates that the ECC decoder detected and fixed a single-bit error.
        underflow => open,         -- 1-bit output: Underflow: Indicates that the read request (rd_en) during the previous clock cycle was rejected because the FIFO is empty.
        wr_ack => open,            -- 1-bit output: Write Acknowledge: This signal indicates that a write request (wr_en) during the prior clock cycle is succeeded.
        wr_data_count => axi_arFIFO_WrDataCount, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates the number of words written into the FIFO.
        wr_rst_busy => open,       -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO write domain is currently in a reset state.
        din => axi_arFIFO_din,     -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when writing the FIFO.
        injectdbiterr => '0',      -- 1-bit input: Double Bit Error Injection
        injectsbiterr => '0',      -- 1-bit input: Single Bit Error Injection: 
        rd_en => axi_arFIFO_rdEn,  -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this signal causes data (on dout) to be read from the FIFO. 
        rst => '0',                -- 1-bit input: Reset: Must be synchronous to wr_clk.
        sleep => '0',              -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo block is in power saving mode.
        wr_clk => i_clk,          -- 1-bit input: Write clock: Used for write operation. wr_clk must be a free running clock.
        wr_en => axi_arFIFO_wrEn   -- 1-bit input: Write Enable: 
    );
    
    axi_araddr_delayed <= axi_arFIFO_dout(19 downto 0);
    axi_arlen_delayed <= axi_arFIFO_dout(27 downto 20);
    axi_reqTime <= axi_arFIFO_dout(63 downto 32);
    
    axi_arvalid_delayed <= '1' when axi_arFIFO_empty = '0' and ((unsigned(axi_reqTime) + MIN_LAG) < nowCount) else '0';
    axi_arFIFO_rden <= axi_arvalid_delayed and axi_arready_delayed;
    
    axi_arsize_delayed   <= "101";   -- 5 = 32 bytes per beat = 256 bit wide bus. -- out std_logic_vector(2 downto 0);
    axi_arburst_delayed  <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
    axi_arcache_delayed  <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    axi_arprot_delayed   <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    axi_arqos_delayed    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    axi_arregion_delayed <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    
    -- The memory:
    second_ct_hbm : axi_bram_ctrl_1Mbyte256bit
    PORT MAP (
        s_axi_aclk => i_clk,
        s_axi_aresetn => i_rst_n,
        s_axi_awaddr => axi_awaddr_20bit,
        s_axi_awlen => axi_awlen,
        s_axi_awsize => axi_awsize,
        s_axi_awburst => axi_awburst,
        s_axi_awlock => '0',
        s_axi_awcache => axi_awcache,
        s_axi_awprot => axi_awprot,
        s_axi_awvalid => axi_awvalid,
        s_axi_awready => axi_awready,
        s_axi_wdata => axi_wdata,
        s_axi_wstrb => axi_wstrb,
        s_axi_wlast => axi_wlast,
        s_axi_wvalid => axi_wvalid,
        s_axi_wready => axi_wready,
        s_axi_bresp => axi_bresp,
        s_axi_bvalid => axi_bvalid,
        s_axi_bready => axi_bready,
        s_axi_araddr => axi_araddr_delayed,
        s_axi_arlen => axi_arlen_delayed,
        s_axi_arsize => axi_arsize_delayed,
        s_axi_arburst => axi_arburst_delayed,
        s_axi_arlock => '0',
        s_axi_arcache => axi_arcache_delayed,
        s_axi_arprot => axi_arprot_delayed,
        s_axi_arvalid => axi_arvalid_delayed,
        s_axi_arready => axi_arready_delayed,
        s_axi_rdata => axi_rdataTemp,
        s_axi_rresp => axi_rresp,
        s_axi_rlast => axi_rlast,
        s_axi_rvalid => axi_rvalid,
        s_axi_rready => axi_rready
    );

    
    axi_rdata <= axi_rdataTemp;
    -- replace rdata with a read count for debugging
--    axi_rdata <= rcount & rcount & rcount & rcount & rcount & rcount & rcount & rcount;

--    process(i_clk)
--    begin
--        if rising_Edge(i_clk) then
--            if axi_rvalid = '1' and axi_rready = '1' then
--                rcount <= std_logic_vector(unsigned(rcount) + 1);
--            end if;
--        end if;
--    end process;
    

end Behavioral;
