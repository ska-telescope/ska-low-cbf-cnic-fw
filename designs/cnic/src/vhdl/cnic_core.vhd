-------------------------------------------------------------------------------
--
-- File Name: cnicCore.vhd
-- Contributing Authors:  Jason van Aardt,  David Humphreys, Giles Babich
-- Template Rev: 1.0
--
-- Title: Top Level for vitis compatible acceleration core
--
--  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
--  See the file LICENSE for more info.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, UNISIM, common_lib, axi4_lib, technology_lib, util_lib, dsp_top_lib, cnic_lib, signal_processing_common, Timeslave_CMAC_lib, DRP_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_lib.common_pkg.ALL;
USE common_lib.common_mem_pkg.ALL;
USE axi4_lib.axi4_lite_pkg.ALL;
USE axi4_lib.axi4_stream_pkg.ALL;
USE axi4_lib.axi4_full_pkg.ALL;
USE technology_lib.tech_mac_100g_pkg.ALL;
USE technology_lib.technology_pkg.ALL;
USE technology_lib.technology_select_pkg.all;

USE work.cnic_bus_pkg.ALL;
USE work.cnic_system_reg_pkg.ALL;
USE UNISIM.vcomponents.all;
Library xpm;
use xpm.vcomponents.all;

-------------------------------------------------------------------------------
ENTITY cnic_core IS
    generic (
        -- GLOBAL GENERICS for PERENTIE LOGIC
        g_ALVEO_TARGET                  : INTEGER := 50;
        g_ALVEO_U50                     : BOOLEAN := FALSE;
        g_ALVEO_U55                     : BOOLEAN := FALSE;

        g_DEBUG_ILA                     : BOOLEAN := FALSE;
        
        g_PTP_ENABLE                    : BOOLEAN := TRUE;
        
        g_FIRMWARE_MAJOR_VERSION        : std_logic_vector(15 downto 0) := x"0000";
        g_FIRMWARE_MINOR_VERSION        : std_logic_vector(15 downto 0) := x"0000";
        g_FIRMWARE_PATCH_VERSION        : std_logic_vector(15 downto 0) := x"0000";
        g_FIRMWARE_LABEL                : std_logic_vector(31 downto 0) := x"00000000";
        g_FIRMWARE_PERSONALITY          : std_logic_vector(31 downto 0) := x"00000000";
        g_FIRMWARE_BUILD_DATE           : std_logic_vector(31 downto 0) := x"01011970";
        -- GENERICS for SHELL INTERACTION
        C_S_AXI_CONTROL_ADDR_WIDTH : integer := 7;
        C_S_AXI_CONTROL_DATA_WIDTH : integer := 32;
        C_M_AXI_ADDR_WIDTH : integer := 64;
        C_M_AXI_DATA_WIDTH : integer := 32;
        C_M_AXI_ID_WIDTH   : integer := 1;
        M01_AXI_ADDR_WIDTH : integer := 64;  
        M01_AXI_DATA_WIDTH : integer := 512; 
        M01_AXI_ID_WIDTH   : integer := 1;
        M02_AXI_ADDR_WIDTH : integer := 64;   
        M02_AXI_DATA_WIDTH : integer := 512;  
        M02_AXI_ID_WIDTH   : integer := 1;    
        M03_AXI_ADDR_WIDTH : integer := 64;  
        M03_AXI_DATA_WIDTH : integer := 512; 
        M03_AXI_ID_WIDTH   : integer := 1;    
        M04_AXI_ADDR_WIDTH : integer := 64;   
        M04_AXI_DATA_WIDTH : integer := 512;   
        M04_AXI_ID_WIDTH   : integer := 1
        
    );
    PORT (
        ap_clk : in std_logic;
        ap_rst_n : in std_logic;
        
        -----------------------------------------------------------------------
        -- Ports used for simulation only.
        --
        -- Received data from 100GE
        i_eth100_rx_sosi : in t_lbus_sosi;
        -- Data to be transmitted on 100GE
        o_eth100_tx_sosi : out t_lbus_sosi;
        i_eth100_tx_siso : in t_lbus_siso;
        i_clk_100GE    : in std_logic;
        -- reset of the valid memory is in progress.
        o_validMemRstActive : out std_logic;
        --------------------------------------------------------------------------------------
        --  Note: A minimum subset of AXI4 memory mapped signals are declared.  AXI
        --  signals omitted from these interfaces are automatically inferred with the
        -- optimal values for Xilinx SDx systems.  This allows Xilinx AXI4 Interconnects
        -- within the system to be optimized by removing logic for AXI4 protocol
        -- features that are not necessary. When adapting AXI4 masters within the RTL
        -- kernel that have signals not declared below, it is suitable to add the
        -- signals to the declarations below to connect them to the AXI4 Master.
        --
        -- List of ommited signals - effect
        -- -------------------------------
        -- ID     - Transaction ID are used for multithreading and out of order transactions.  This increases complexity. This saves logic and increases Fmax in the system when ommited.
        -- SIZE   - Default value is log2(data width in bytes). Needed for subsize bursts. This saves logic and increases Fmax in the system when ommited.
        -- BURST  - Default value (0b01) is incremental.  Wrap and fixed bursts are not recommended. This saves logic and increases Fmax in the system when ommited.
        -- LOCK   - Not supported in AXI4
        -- CACHE  - Default value (0b0011) allows modifiable transactions. No benefit to changing this.
        -- PROT   - Has no effect in SDx systems.
        -- QOS    - Has no effect in SDx systems.
        -- REGION - Has no effect in SDx systems.
        -- USER   - Has no effect in SDx systems.
        -- RESP   - Not useful in most SDx systems.
        --------------------------------------------------------------------------------------
        --  AXI4-Lite slave interface
        s_axi_control_awvalid : in std_logic;
        s_axi_control_awready : out std_logic;
        s_axi_control_awaddr : in std_logic_vector(C_S_AXI_CONTROL_ADDR_WIDTH-1 downto 0);
        s_axi_control_wvalid : in std_logic;
        s_axi_control_wready : out std_logic;
        s_axi_control_wdata  : in std_logic_vector(C_S_AXI_CONTROL_DATA_WIDTH-1 downto 0);
        s_axi_control_wstrb  : in std_logic_vector(C_S_AXI_CONTROL_DATA_WIDTH/8-1 downto 0);
        s_axi_control_arvalid : in std_logic;
        s_axi_control_arready : out std_logic;
        s_axi_control_araddr : in std_logic_vector(C_S_AXI_CONTROL_ADDR_WIDTH-1 downto 0);
        s_axi_control_rvalid : out std_logic;
        s_axi_control_rready : in std_logic;
        s_axi_control_rdata  : out std_logic_vector(C_S_AXI_CONTROL_DATA_WIDTH-1 downto 0);
        s_axi_control_rresp  : out std_logic_vector(1 downto 0);
        s_axi_control_bvalid : out std_logic;
        s_axi_control_bready : in std_logic;
        s_axi_control_bresp  : out std_logic_vector(1 downto 0);
  
        -- AXI4 master interface for accessing registers : m00_axi
        m00_axi_awvalid : out std_logic;
        m00_axi_awready : in std_logic;
        m00_axi_awaddr : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_awid   : out std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
        m00_axi_awlen   : out std_logic_vector(7 downto 0);
        m00_axi_awsize   : out std_logic_vector(2 downto 0);
        m00_axi_awburst  : out std_logic_vector(1 downto 0);
        m00_axi_awlock   : out std_logic_vector(1 downto 0);
        m00_axi_awcache  : out std_logic_vector(3 downto 0);
        m00_axi_awprot   : out std_logic_vector(2 downto 0);
        m00_axi_awqos    : out std_logic_vector(3 downto 0);
        m00_axi_awregion : out std_logic_vector(3 downto 0);
    
        m00_axi_wvalid    : out std_logic;
        m00_axi_wready    : in std_logic;
        m00_axi_wdata     : out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_wstrb     : out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
        m00_axi_wlast     : out std_logic;
        m00_axi_bvalid    : in std_logic;
        m00_axi_bready    : out std_logic;
        m00_axi_bresp     : in std_logic_vector(1 downto 0);
        m00_axi_bid       : in std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
        m00_axi_arvalid   : out std_logic;
        m00_axi_arready   : in std_logic;
        m00_axi_araddr    : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_arid      : out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
        m00_axi_arlen     : out std_logic_vector(7 downto 0);
        m00_axi_arsize    : out std_logic_vector(2 downto 0);
        m00_axi_arburst   : out std_logic_vector(1 downto 0);
        m00_axi_arlock    : out std_logic_vector(1 downto 0);
        m00_axi_arcache   : out std_logic_vector(3 downto 0);
        m00_axi_arprot    : out std_logic_Vector(2 downto 0);
        m00_axi_arqos     : out std_logic_vector(3 downto 0);
        m00_axi_arregion  : out std_logic_vector(3 downto 0);
        m00_axi_rvalid    : in std_logic;
        m00_axi_rready    : out std_logic;
        m00_axi_rdata     : in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_rlast     : in std_logic;
        m00_axi_rid       : in std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
        m00_axi_rresp     : in std_logic_vector(1 downto 0);
        ---------------------------------------------------------------------------------------

        m01_axi_awvalid : out std_logic;
        m01_axi_awready : in std_logic;
        m01_axi_awaddr : out std_logic_vector(M01_AXI_ADDR_WIDTH-1 downto 0);
        m01_axi_awid   : out std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
        m01_axi_awlen   : out std_logic_vector(7 downto 0);
        m01_axi_awsize   : out std_logic_vector(2 downto 0);
        m01_axi_awburst  : out std_logic_vector(1 downto 0);
        m01_axi_awlock   : out std_logic_vector(1 downto 0);
        m01_axi_awcache  : out std_logic_vector(3 downto 0);
        m01_axi_awprot   : out std_logic_vector(2 downto 0);
        m01_axi_awqos    : out std_logic_vector(3 downto 0);
        m01_axi_awregion : out std_logic_vector(3 downto 0);
    
        m01_axi_wvalid    : out std_logic;
        m01_axi_wready    : in std_logic;
        m01_axi_wdata     : out std_logic_vector(M01_AXI_DATA_WIDTH-1 downto 0);
        m01_axi_wstrb     : out std_logic_vector(M01_AXI_DATA_WIDTH/8-1 downto 0);
        m01_axi_wlast     : out std_logic;
        m01_axi_bvalid    : in std_logic;
        m01_axi_bready    : out std_logic;
        m01_axi_bresp     : in std_logic_vector(1 downto 0);
        m01_axi_bid       : in std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
        m01_axi_arvalid   : out std_logic;
        m01_axi_arready   : in std_logic;
        m01_axi_araddr    : out std_logic_vector(M01_AXI_ADDR_WIDTH-1 downto 0);
        m01_axi_arid      : out std_logic_vector(M01_AXI_ID_WIDTH-1 downto 0);
        m01_axi_arlen     : out std_logic_vector(7 downto 0);
        m01_axi_arsize    : out std_logic_vector(2 downto 0);
        m01_axi_arburst   : out std_logic_vector(1 downto 0);
        m01_axi_arlock    : out std_logic_vector(1 downto 0);
        m01_axi_arcache   : out std_logic_vector(3 downto 0);
        m01_axi_arprot    : out std_logic_Vector(2 downto 0);
        m01_axi_arqos     : out std_logic_vector(3 downto 0);
        m01_axi_arregion  : out std_logic_vector(3 downto 0);
        m01_axi_rvalid    : in std_logic;
        m01_axi_rready    : out std_logic;
        m01_axi_rdata     : in std_logic_vector(M01_AXI_DATA_WIDTH-1 downto 0);
        m01_axi_rlast     : in std_logic;
        m01_axi_rid       : in std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
        m01_axi_rresp     : in std_logic_vector(1 downto 0);

        ---------------------------------------------------------------------------------------

        m02_axi_awvalid : out std_logic;
        m02_axi_awready : in std_logic;
        m02_axi_awaddr : out std_logic_vector(M02_AXI_ADDR_WIDTH-1 downto 0);
        m02_axi_awid   : out std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);
        m02_axi_awlen   : out std_logic_vector(7 downto 0);
        m02_axi_awsize   : out std_logic_vector(2 downto 0);
        m02_axi_awburst  : out std_logic_vector(1 downto 0);
        m02_axi_awlock   : out std_logic_vector(1 downto 0);
        m02_axi_awcache  : out std_logic_vector(3 downto 0);
        m02_axi_awprot   : out std_logic_vector(2 downto 0);
        m02_axi_awqos    : out std_logic_vector(3 downto 0);
        m02_axi_awregion : out std_logic_vector(3 downto 0);
    
        m02_axi_wvalid    : out std_logic;
        m02_axi_wready    : in std_logic;
        m02_axi_wdata     : out std_logic_vector(M02_AXI_DATA_WIDTH-1 downto 0);
        m02_axi_wstrb     : out std_logic_vector(M02_AXI_DATA_WIDTH/8-1 downto 0);
        m02_axi_wlast     : out std_logic;
        m02_axi_bvalid    : in std_logic;
        m02_axi_bready    : out std_logic;
        m02_axi_bresp     : in std_logic_vector(1 downto 0);
        m02_axi_bid       : in std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);
        m02_axi_arvalid   : out std_logic;
        m02_axi_arready   : in std_logic;
        m02_axi_araddr    : out std_logic_vector(M02_AXI_ADDR_WIDTH-1 downto 0);
        m02_axi_arid      : out std_logic_vector(M02_AXI_ID_WIDTH-1 downto 0);
        m02_axi_arlen     : out std_logic_vector(7 downto 0);
        m02_axi_arsize    : out std_logic_vector(2 downto 0);
        m02_axi_arburst   : out std_logic_vector(1 downto 0);
        m02_axi_arlock    : out std_logic_vector(1 downto 0);
        m02_axi_arcache   : out std_logic_vector(3 downto 0);
        m02_axi_arprot    : out std_logic_Vector(2 downto 0);
        m02_axi_arqos     : out std_logic_vector(3 downto 0);
        m02_axi_arregion  : out std_logic_vector(3 downto 0);
        m02_axi_rvalid    : in std_logic;
        m02_axi_rready    : out std_logic;
        m02_axi_rdata     : in std_logic_vector(M02_AXI_DATA_WIDTH-1 downto 0);
        m02_axi_rlast     : in std_logic;
        m02_axi_rid       : in std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);
        m02_axi_rresp     : in std_logic_vector(1 downto 0);        

        -- AXI4 master interface for accessing HBM for the Filterbank corner turn : m03_axi
        m03_axi_awvalid : out std_logic;
        m03_axi_awready : in std_logic;
        m03_axi_awaddr : out std_logic_vector(M03_AXI_ADDR_WIDTH-1 downto 0);
        m03_axi_awid   : out std_logic_vector(M03_AXI_ID_WIDTH - 1 downto 0);
        m03_axi_awlen   : out std_logic_vector(7 downto 0);
        m03_axi_awsize   : out std_logic_vector(2 downto 0);
        m03_axi_awburst  : out std_logic_vector(1 downto 0);
        m03_axi_awlock   : out std_logic_vector(1 downto 0);
        m03_axi_awcache  : out std_logic_vector(3 downto 0);
        m03_axi_awprot   : out std_logic_vector(2 downto 0);
        m03_axi_awqos    : out std_logic_vector(3 downto 0);
        m03_axi_awregion : out std_logic_vector(3 downto 0);
    
        m03_axi_wvalid    : out std_logic;
        m03_axi_wready    : in std_logic;
        m03_axi_wdata     : out std_logic_vector(M03_AXI_DATA_WIDTH-1 downto 0);
        m03_axi_wstrb     : out std_logic_vector(M03_AXI_DATA_WIDTH/8-1 downto 0);
        m03_axi_wlast     : out std_logic;
        m03_axi_bvalid    : in std_logic;
        m03_axi_bready    : out std_logic;
        m03_axi_bresp     : in std_logic_vector(1 downto 0);
        m03_axi_bid       : in std_logic_vector(M03_AXI_ID_WIDTH - 1 downto 0);
        m03_axi_arvalid   : out std_logic;
        m03_axi_arready   : in std_logic;
        m03_axi_araddr    : out std_logic_vector(M03_AXI_ADDR_WIDTH-1 downto 0);
        m03_axi_arid      : out std_logic_vector(M03_AXI_ID_WIDTH-1 downto 0);
        m03_axi_arlen     : out std_logic_vector(7 downto 0);
        m03_axi_arsize    : out std_logic_vector(2 downto 0);
        m03_axi_arburst   : out std_logic_vector(1 downto 0);
        m03_axi_arlock    : out std_logic_vector(1 downto 0);
        m03_axi_arcache   : out std_logic_vector(3 downto 0);
        m03_axi_arprot    : out std_logic_Vector(2 downto 0);
        m03_axi_arqos     : out std_logic_vector(3 downto 0);
        m03_axi_arregion  : out std_logic_vector(3 downto 0);
        m03_axi_rvalid    : in std_logic;
        m03_axi_rready    : out std_logic;
        m03_axi_rdata     : in std_logic_vector(M03_AXI_DATA_WIDTH-1 downto 0);
        m03_axi_rlast     : in std_logic;
        m03_axi_rid       : in std_logic_vector(M03_AXI_ID_WIDTH - 1 downto 0);
        m03_axi_rresp     : in std_logic_vector(1 downto 0);       

        -- AXI4 master interface for accessing HBM for the Filterbank corner turn : m04_axi
        m04_axi_awvalid : out std_logic;
        m04_axi_awready : in std_logic;
        m04_axi_awaddr : out std_logic_vector(M04_AXI_ADDR_WIDTH-1 downto 0);
        m04_axi_awid   : out std_logic_vector(M04_AXI_ID_WIDTH - 1 downto 0);
        m04_axi_awlen   : out std_logic_vector(7 downto 0);
        m04_axi_awsize   : out std_logic_vector(2 downto 0);
        m04_axi_awburst  : out std_logic_vector(1 downto 0);
        m04_axi_awlock   : out std_logic_vector(1 downto 0);
        m04_axi_awcache  : out std_logic_vector(3 downto 0);
        m04_axi_awprot   : out std_logic_vector(2 downto 0);
        m04_axi_awqos    : out std_logic_vector(3 downto 0);
        m04_axi_awregion : out std_logic_vector(3 downto 0);
    
        m04_axi_wvalid    : out std_logic;
        m04_axi_wready    : in std_logic;
        m04_axi_wdata     : out std_logic_vector(M04_AXI_DATA_WIDTH-1 downto 0);
        m04_axi_wstrb     : out std_logic_vector(M04_AXI_DATA_WIDTH/8-1 downto 0);
        m04_axi_wlast     : out std_logic;
        m04_axi_bvalid    : in std_logic;
        m04_axi_bready    : out std_logic;
        m04_axi_bresp     : in std_logic_vector(1 downto 0);
        m04_axi_bid       : in std_logic_vector(M04_AXI_ID_WIDTH - 1 downto 0);
        m04_axi_arvalid   : out std_logic;
        m04_axi_arready   : in std_logic;
        m04_axi_araddr    : out std_logic_vector(M04_AXI_ADDR_WIDTH-1 downto 0);
        m04_axi_arid      : out std_logic_vector(M04_AXI_ID_WIDTH-1 downto 0);
        m04_axi_arlen     : out std_logic_vector(7 downto 0);
        m04_axi_arsize    : out std_logic_vector(2 downto 0);
        m04_axi_arburst   : out std_logic_vector(1 downto 0);
        m04_axi_arlock    : out std_logic_vector(1 downto 0);
        m04_axi_arcache   : out std_logic_vector(3 downto 0);
        m04_axi_arprot    : out std_logic_Vector(2 downto 0);
        m04_axi_arqos     : out std_logic_vector(3 downto 0);
        m04_axi_arregion  : out std_logic_vector(3 downto 0);
        m04_axi_rvalid    : in std_logic;
        m04_axi_rready    : out std_logic;
        m04_axi_rdata     : in std_logic_vector(M04_AXI_DATA_WIDTH-1 downto 0);
        m04_axi_rlast     : in std_logic;
        m04_axi_rid       : in std_logic_vector(M04_AXI_ID_WIDTH - 1 downto 0);
        m04_axi_rresp     : in std_logic_vector(1 downto 0);       

        -- GT pins
        -- clk_freerun is a 100MHz free running clock.
        clk_freerun    : in std_logic; 
        
        -- PORT A - QSFP cage furthest to PCIe connector.
        gt_rxp_in      : in std_logic_vector(3 downto 0);
        gt_rxn_in      : in std_logic_vector(3 downto 0);
        gt_txp_out     : out std_logic_vector(3 downto 0);
        gt_txn_out     : out std_logic_vector(3 downto 0);
        gt_refclk_p    : in std_logic;
        gt_refclk_n    : in std_logic;
        
        -- PORT B - QSFP cage closest to PCIe connector.
        gt_b_rxp_in    : in std_logic_vector(3 downto 0);
        gt_b_rxn_in    : in std_logic_vector(3 downto 0);
        gt_b_txp_out   : out std_logic_vector(3 downto 0);
        gt_b_txn_out   : out std_logic_vector(3 downto 0);
        gt_refclk_b_p  : in std_logic;
        gt_refclk_b_n  : in std_logic

    );
END cnic_core;

-------------------------------------------------------------------------------
ARCHITECTURE RTL OF cnic_core IS

     -- 300MHz in, 100 MHz and 450 MHz out.
     component clk_gen100MHz
     port (
         clk100_out : out std_logic;
         clk250_out : out std_logic;       
         clk_in1    : in  std_logic);
     end component;

     component clk_gen400MHz
     port (
         clk400_out : out std_logic;
         clk_in1    : in  std_logic);
     end component;
    
    COMPONENT ila_0
    PORT (
   	    clk : IN STD_LOGIC;
   	    probe0 : IN STD_LOGIC_VECTOR(191 DOWNTO 0));
    END COMPONENT;

    COMPONENT ila_1
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(575 DOWNTO 0)
        );
    END COMPONENT;

    signal U55_TOP_QSFP         : BOOLEAN;
    signal U55_BOTTOM_QSFP      : BOOLEAN;  
    
    signal ap_rst               : std_logic;
    signal ap_idle, idle_int    : std_logic;
    signal mc_master_mosi       : t_axi4_full_mosi;
    signal mc_master_miso       : t_axi4_full_miso;
    
    
    signal mc_lite_miso   : t_axi4_lite_miso_arr(0 TO c_nof_lite_slaves-1);
    signal mc_lite_mosi   : t_axi4_lite_mosi_arr(0 TO c_nof_lite_slaves-1);
    signal mc_full_miso   : t_axi4_full_miso_arr(0 TO c_nof_full_slaves-1);
    signal mc_full_mosi   : t_axi4_full_mosi_arr(0 TO c_nof_full_slaves-1);
    
    signal cdma_status : std_logic_vector(14 downto 0);
    
    signal ap_start, ap_done : std_logic;
    signal DMA_src_addr, DMA_dest_addr : std_logic_vector(31 downto 0);
    signal DMA_size : std_logic_vector(31 downto 0);
    signal DMASharedMemAddr : std_logic_vector(63 downto 0);
    
    signal system_fields_rw : t_system_rw;
    signal system_fields_ro : t_system_ro;
    signal uptime : std_logic_vector(31 downto 0) := x"00000000";

    signal eth100_rx_sosi : t_lbus_sosi;
    signal eth100_tx_sosi : t_lbus_sosi;
    signal eth100_tx_siso : t_lbus_siso;
    signal eth100_reset : std_logic := '0';
    signal dest_req : std_logic;
    signal eth100G_status_ap_clk : std_logic_vector(128 downto 0);
    signal eth100G_status_eth_clk : std_logic_vector(128 downto 0);
    signal eth100G_send, eth100G_rcv, eth100G_clk, eth100G_locked : std_logic;
    
    signal eth100G_rx_total_packets : std_logic_vector(31 downto 0);
    signal eth100G_rx_bad_fcs : std_logic_vector(31 downto 0);
    signal eth100G_rx_bad_code : std_logic_vector(31 downto 0);
    signal eth100G_tx_total_packets : std_logic_vector(31 downto 0);
    signal eth100G_rx_reset : std_logic;
    signal eth100G_tx_reset : std_logic;
    
    signal eth100G_reset    : std_logic;
    
    signal ap_clk_count : std_logic_vector(31 downto 0) := (others => '0');
    
    signal freerunCount : std_logic_vector(31 downto 0) := x"00000000";
    signal freerunSecCount : std_logic_vector(31 downto 0) := x"00000000";

    signal GTY_startup_rst, eth100_reset_final : std_logic := '0';
    signal clk100 : std_logic;
    signal clk400 : std_logic;
    signal clk250 : std_logic;
    signal clk_gt_freerun_use : std_logic;
    
    signal eth100G_uptime : std_logic_vector(31 downto 0) := (others => '0');
    signal eth100G_seconds : std_logic_vector(31 downto 0) := (others => '0');
    
    signal araddr64bit, awaddr64bit : std_logic_vector(63 downto 0);
    signal m01_shared : std_logic_vector(63 downto 0);
    signal m02_shared : std_logic_vector(63 downto 0);
    signal m03_shared : std_logic_vector(63 downto 0);
    signal m04_shared : std_logic_vector(63 downto 0);
    signal m05_shared : std_logic_vector(63 downto 0);
    
    signal fec_enable_322m          : std_logic;
    signal fec_enable_100m          : std_logic;
    signal fec_enable_cache         : std_logic;
    
    signal fec_enable_reset_count   : integer := 0;
    signal fec_enable_reset         : std_logic := '0';
    
            -- PTP Data
    signal PTP_time_CMAC_clk       : std_logic_vector(79 downto 0);
    signal PTP_pps_CMAC_clk        : std_logic;
        
    signal PTP_time_ARGs_clk       : std_logic_vector(79 downto 0);
    signal PTP_pps_ARGs_clk        : std_logic;
    
    signal tx_axis_tdata            : STD_LOGIC_VECTOR(511 downto 0);
    signal tx_axis_tkeep            : STD_LOGIC_VECTOR(63 downto 0);
    signal tx_axis_tvalid           : STD_LOGIC;
    signal tx_axis_tlast            : STD_LOGIC;
    signal tx_axis_tuser            : STD_LOGIC;
    signal tx_axis_tready           : STD_LOGIC;
        
    signal rx_axis_tdata     : STD_LOGIC_VECTOR ( 511 downto 0 );
    signal rx_axis_tkeep     : STD_LOGIC_VECTOR ( 63 downto 0 );
    signal rx_axis_tlast     : STD_LOGIC;
    signal rx_axis_tready    : STD_LOGIC;
    signal rx_axis_tuser     : STD_LOGIC_VECTOR ( 79 downto 0 );
    signal rx_axis_tvalid    : STD_LOGIC;
    
    -- 2nd CMAC instance
    signal eth100G_clk_b, eth100G_locked_b : std_logic;
    signal tx_axis_tdata_b          : STD_LOGIC_VECTOR(511 downto 0);
    signal tx_axis_tkeep_b          : STD_LOGIC_VECTOR(63 downto 0);
    signal tx_axis_tvalid_b         : STD_LOGIC;
    signal tx_axis_tlast_b          : STD_LOGIC;
    signal tx_axis_tuser_b          : STD_LOGIC;
    signal tx_axis_tready_b         : STD_LOGIC;
    
    signal m01_axi_awvalidi  : std_logic;
    signal m01_axi_awreadyi  : std_logic;
    signal m01_axi_awaddri   : std_logic_vector(M01_AXI_ADDR_WIDTH-1 downto 0);
    signal m01_axi_awidi     : std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
    signal m01_axi_awleni    : std_logic_vector(7 downto 0);
    signal m01_axi_awsizei   : std_logic_vector(2 downto 0);
    signal m01_axi_awbursti  : std_logic_vector(1 downto 0);
    signal m01_axi_wvalidi   : std_logic;
    signal m01_axi_wreadyi   : std_logic;
    signal m01_axi_wdatai    : std_logic_vector(M01_AXI_DATA_WIDTH-1 downto 0);
    signal m01_axi_wstrbi    : std_logic_vector(M01_AXI_DATA_WIDTH/8-1 downto 0);
    signal m01_axi_wlasti    : std_logic;
    signal m01_axi_bvalidi   : std_logic;
    signal m01_axi_breadyi   : std_logic;
    signal m01_axi_brespi    : std_logic_vector(1 downto 0);
    signal m01_axi_bidi      : std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
    signal m01_axi_arvalidi  : std_logic;
    signal m01_axi_arreadyi  : std_logic;
    signal m01_axi_araddri   : std_logic_vector(M01_AXI_ADDR_WIDTH-1 downto 0);
    signal m01_axi_aridi     : std_logic_vector(M01_AXI_ID_WIDTH-1 downto 0);
    signal m01_axi_arleni    : std_logic_vector(7 downto 0);
    signal m01_axi_arsizei   : std_logic_vector(2 downto 0);
    signal m01_axi_arbursti  : std_logic_vector(1 downto 0);
    signal m01_axi_rvalidi   : std_logic;
    signal m01_axi_rreadyi   : std_logic;
    signal m01_axi_rdatai    : std_logic_vector(M01_AXI_DATA_WIDTH-1 downto 0);
    signal m01_axi_rlasti    : std_logic;
    signal m01_axi_ridi      : std_logic_vector(M01_AXI_ID_WIDTH - 1 downto 0);
    signal m01_axi_rrespi    : std_logic_vector(1 downto 0);
    
     signal m02_axi_awvalidi, m03_axi_awvalidi, m04_axi_awvalidi, m05_axi_awvalidi  : std_logic;                                        
     signal m02_axi_awreadyi, m03_axi_awreadyi, m04_axi_awreadyi, m05_axi_awreadyi  : std_logic;                                        
     signal m02_axi_awaddri , m03_axi_awaddri , m04_axi_awaddri , m05_axi_awaddri   : std_logic_vector(M02_AXI_ADDR_WIDTH-1 downto 0);  
     signal m02_axi_awidi   , m03_axi_awidi   , m04_axi_awidi   , m05_axi_awidi     : std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);  
     signal m02_axi_awleni  , m03_axi_awleni  , m04_axi_awleni  , m05_axi_awleni    : std_logic_vector(7 downto 0);                     
     signal m02_axi_awsizei , m03_axi_awsizei , m04_axi_awsizei , m05_axi_awsizei   : std_logic_vector(2 downto 0);                     
     signal m02_axi_awbursti, m03_axi_awbursti, m04_axi_awbursti, m05_axi_awbursti  : std_logic_vector(1 downto 0);                     
     signal m02_axi_wvalidi , m03_axi_wvalidi , m04_axi_wvalidi , m05_axi_wvalidi   : std_logic;                                        
     signal m02_axi_wreadyi , m03_axi_wreadyi , m04_axi_wreadyi , m05_axi_wreadyi   : std_logic;                                        
     signal m02_axi_wdatai  , m03_axi_wdatai  , m04_axi_wdatai  , m05_axi_wdatai    : std_logic_vector(M02_AXI_DATA_WIDTH-1 downto 0);  
     signal m02_axi_wstrbi  , m03_axi_wstrbi  , m04_axi_wstrbi  , m05_axi_wstrbi    : std_logic_vector(M02_AXI_DATA_WIDTH/8-1 downto 0);
     signal m02_axi_wlasti  , m03_axi_wlasti  , m04_axi_wlasti  , m05_axi_wlasti    : std_logic;                                        
     signal m02_axi_bvalidi , m03_axi_bvalidi , m04_axi_bvalidi , m05_axi_bvalidi   : std_logic;                                        
     signal m02_axi_breadyi , m03_axi_breadyi , m04_axi_breadyi , m05_axi_breadyi   : std_logic;                                        
     signal m02_axi_brespi  , m03_axi_brespi  , m04_axi_brespi  , m05_axi_brespi    : std_logic_vector(1 downto 0);                     
     signal m02_axi_bidi    , m03_axi_bidi    , m04_axi_bidi    , m05_axi_bidi      : std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);  
     signal m02_axi_arvalidi, m03_axi_arvalidi, m04_axi_arvalidi, m05_axi_arvalidi  : std_logic;                                        
     signal m02_axi_arreadyi, m03_axi_arreadyi, m04_axi_arreadyi, m05_axi_arreadyi  : std_logic;                                        
     signal m02_axi_araddri , m03_axi_araddri , m04_axi_araddri , m05_axi_araddri   : std_logic_vector(M02_AXI_ADDR_WIDTH-1 downto 0);  
     signal m02_axi_aridi   , m03_axi_aridi   , m04_axi_aridi   , m05_axi_aridi     : std_logic_vector(M02_AXI_ID_WIDTH-1 downto 0);    
     signal m02_axi_arleni  , m03_axi_arleni  , m04_axi_arleni  , m05_axi_arleni    : std_logic_vector(7 downto 0);                     
     signal m02_axi_arsizei , m03_axi_arsizei , m04_axi_arsizei , m05_axi_arsizei   : std_logic_vector(2 downto 0);                     
     signal m02_axi_arbursti, m03_axi_arbursti, m04_axi_arbursti, m05_axi_arbursti  : std_logic_vector(1 downto 0);                     
     signal m02_axi_rvalidi , m03_axi_rvalidi , m04_axi_rvalidi , m05_axi_rvalidi   : std_logic;                                        
     signal m02_axi_rreadyi , m03_axi_rreadyi , m04_axi_rreadyi , m05_axi_rreadyi   : std_logic;                                        
     signal m02_axi_rdatai  , m03_axi_rdatai  , m04_axi_rdatai  , m05_axi_rdatai    : std_logic_vector(M02_AXI_DATA_WIDTH-1 downto 0);  
     signal m02_axi_rlasti  , m03_axi_rlasti  , m04_axi_rlasti  , m05_axi_rlasti    : std_logic;                                        
     signal m02_axi_ridi    , m03_axi_ridi    , m04_axi_ridi    , m05_axi_ridi      : std_logic_vector(M02_AXI_ID_WIDTH - 1 downto 0);  
     signal m02_axi_rrespi  , m03_axi_rrespi  , m04_axi_rrespi  , m05_axi_rrespi    : std_logic_vector(1 downto 0);                     
    
    -- create_ip -name axi_register_slice -vendor xilinx.com -library ip -version 2.1 -module_name axi_reg_slice512_LLFFL
    -- set_property -dict [list CONFIG.ADDR_WIDTH {64} CONFIG.DATA_WIDTH {512} CONFIG.REG_W {1} CONFIG.Component_Name {axi_reg_slice512_LLFFL}] [get_ips axi_reg_slice512_LLFFL]
    COMPONENT axi_reg_slice512_LLFFL
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awvalid : IN STD_LOGIC;
        s_axi_awready : OUT STD_LOGIC;
        s_axi_wdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast : IN STD_LOGIC;
        s_axi_wvalid : IN STD_LOGIC;
        s_axi_wready : OUT STD_LOGIC;
        s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid : OUT STD_LOGIC;
        s_axi_bready : IN STD_LOGIC;
        s_axi_araddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC;
        m_axi_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid : OUT STD_LOGIC;
        m_axi_awready : IN STD_LOGIC;
        m_axi_wdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_wstrb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_wlast : OUT STD_LOGIC;
        m_axi_wvalid : OUT STD_LOGIC;
        m_axi_wready : IN STD_LOGIC;
        m_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid : IN STD_LOGIC;
        m_axi_bready : OUT STD_LOGIC;
        m_axi_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_arvalid : OUT STD_LOGIC;
        m_axi_arready : IN STD_LOGIC;
        m_axi_rdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast : IN STD_LOGIC;
        m_axi_rvalid : IN STD_LOGIC;
        m_axi_rready : OUT STD_LOGIC);
    END COMPONENT;    
    
    COMPONENT axi_reg_slice256_LLFFL
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
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
        s_axi_araddr : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC;
        m_axi_awaddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid : OUT STD_LOGIC;
        m_axi_awready : IN STD_LOGIC;
        m_axi_wdata : OUT STD_LOGIC_VECTOR(255 DOWNTO 0);
        m_axi_wstrb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axi_wlast : OUT STD_LOGIC;
        m_axi_wvalid : OUT STD_LOGIC;
        m_axi_wready : IN STD_LOGIC;
        m_axi_bresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid : IN STD_LOGIC;
        m_axi_bready : OUT STD_LOGIC;
        m_axi_araddr : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_arvalid : OUT STD_LOGIC;
        m_axi_arready : IN STD_LOGIC;
        m_axi_rdata : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
        m_axi_rresp : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast : IN STD_LOGIC;
        m_axi_rvalid : IN STD_LOGIC;
        m_axi_rready : OUT STD_LOGIC);
    END COMPONENT;    
    
    signal bytes_transmitted_last_hsec      : std_logic_vector(31 downto 0);

    signal time_between_packets_largest     : std_logic_vector(15 downto 0);
    
    constant    packetiser_CDC_paths        : integer := 2;
    signal      packetiser_stats_crossed    : t_slv_32_arr(0 to (packetiser_CDC_paths-1));
    signal      packetiser_stats            : t_slv_32_arr(0 to (packetiser_CDC_paths-1));
    
    signal schedule_action                  : std_logic_vector(7 downto 0);
    
begin

    
    ---------------------------------------------------------------------------
    -- CLOCKING & RESETS  --
    ---------------------------------------------------------------------------

    u_get100 : clk_gen100MHz
    port map ( 
        clk100_out => clk100,       -- 100 MHz 
        clk250_out => clk250,       -- 450 MHz clock, used for some signal processing.
        clk_in1 => clk_freerun  
    );
    
     
    clk_gt_freerun_use <= clk_freerun; -- 100 MHz non-scalable clock from the platform. 
    
    u_get400 : clk_gen400MHz
    port map (
        clk400_out => clk400,  
        clk_in1    => clk_freerun
    );
    
    ---------------------------------------------------------------------------
    -- AXI-lite control interface
    -- Complies with requirements for a vitis accelerator
    
    u_krnl_ctrl: entity cnic_lib.krnl_control_axi
    generic map(
        C_S_AXI_ADDR_WIDTH => C_S_AXI_CONTROL_ADDR_WIDTH,
        C_S_AXI_DATA_WIDTH => C_S_AXI_CONTROL_DATA_WIDTH
    ) PORT MAP (
        -- axi4 lite slave signals
        ACLK => ap_clk,   -- input
        ARESET => ap_rst, -- input  wire
        --ACLK_EN => '1',   -- input  wire
        AWADDR => s_axi_control_awaddr,   -- input  wire [C_S_AXI_ADDR_WIDTH-1:0] 
        AWVALID => s_axi_control_awvalid, -- input  wire                          
        AWREADY => s_axi_control_awready, -- output wire                          
        WDATA   => s_axi_control_wdata,   -- input  wire [C_S_AXI_DATA_WIDTH-1:0] 
        WSTRB   => s_axi_control_wstrb,   -- input  wire [C_S_AXI_DATA_WIDTH/8-1:0] 
        WVALID  => s_axi_control_wvalid,  -- input  wire
        WREADY  => s_axi_control_wready,  -- output wire
        BRESP   => s_axi_control_bresp,   -- output wire [1:0]
        BVALID  => s_axi_control_bvalid,  -- output wire 
        BREADY  => s_axi_control_bready,  -- input  wire 
        ARADDR  => s_axi_control_araddr,  -- input  wire [C_S_AXI_ADDR_WIDTH-1:0]
        ARVALID => s_axi_control_arvalid, -- input  wire
        ARREADY => s_axi_control_arready, -- output wire 
        RDATA   => s_axi_control_rdata,   -- output wire [C_S_AXI_DATA_WIDTH-1:0]
        RRESP   => s_axi_control_rresp,   -- output wire [1:0]
        RVALID  => s_axi_control_rvalid,  -- output wire 
        RREADY  => s_axi_control_rready,  -- input  wire 
        interrupt => open,                -- output wire 
        -- // user signals
        ap_start => ap_start, -- output wire; bit 0 of register 0, indicates kernel should start processing
        ap_done  => ap_done,  -- input  wire; bit 1 of register 0, indicates processing is complete. This is registered internally. It should be pulsed high when processing is done. 
        ap_ready => ap_done,  -- input  wire; bit 3 of register 0. Undocumented in UG1393; multiple use cases described in vitis documentation, e.g. www.xilinx.com/html_docs/xilinx2020_1/vitis_doc/programmingvitishls.html
        ap_idle  => ap_idle,  -- input  wire; Idle should go low on ap_start, and stay low until the cycle after ap_done.
        dma_src  => DMA_src_addr,  -- output wire [31:0]
        dma_dest => DMA_dest_addr, -- output wire [31:0]
        dma_shared => DMASharedMemAddr, -- output wire [63:0]  -- Base Address of the shared memory block.
        dma_size => DMA_size,      -- output wire [31:0]
        m01_shared => m01_shared,  -- out(63:0)
        m02_shared => m02_shared,  -- out(63:0)
        m03_shared => m03_shared,  -- out(63:0)
        m04_shared => m04_shared  -- out(63:0)
        -- m05_shared => m05_shared   -- out(63:0)
    );
    
    ap_idle <= '0' when (idle_int = '0' or (idle_int = '1' and ap_start = '1')) else '1';
    
    -- state machine and cdma block to copy registers on command from krnl_control
    -- This uses 32 bit addresses; the high 32 bits are 0 for ARGs slaves, and fixed to the high order bits from DMA_src_addr or DMA_dest_addr for connection to the output AXI bus to shared memory.
    u_cdma : entity cnic_lib.cdma_wrapper
    port map(
        i_clk      => ap_clk,
        i_rst      => ap_rst,
        i_srcAddr  => DMA_src_addr(31 downto 0),  -- in(31:0);
        i_destAddr => DMA_dest_addr(31 downto 0), -- in(31:0);
        i_size     => DMA_size,                   -- in(31:0);
        i_start    => ap_start,                   -- in std_logic;
        o_idle     => idle_int,                   -- out std_logic; -- High whenever not busy.
        o_done     => ap_done,                    -- out std_logic; -- Pulses high to indicate transaction is complete.
        o_status   => cdma_status,                -- out(14:0) -- cdma status register, read after a transaction is complete (register address 0x4)
        -- AXI master 
        o_AXI_mosi => mc_master_mosi, -- t_axi4_full_mosi;
        i_AXI_miso => mc_master_miso  -- t_axi4_full_miso
    );

	
    ---------------------------------------------------------------------------
    -- Bus Interconnect  --
    ---------------------------------------------------------------------------
    
    process(ap_clk)
    begin
        if rising_edge(ap_clk) then
            ap_rst <= not ap_rst_n;
        end if;
    end process;

    u_interconnect: ENTITY work.cnic_bus_top
    PORT MAP (
        CLK            => ap_clk,
        RST            => ap_rst, -- axi_rst,
        SLA_IN         => mc_master_mosi,
        SLA_OUT        => mc_master_miso,
        MSTR_IN_LITE   => mc_lite_miso,
        MSTR_OUT_LITE  => mc_lite_mosi,
        MSTR_IN_FULL   => mc_full_miso,
        MSTR_OUT_FULL  => mc_full_mosi
    );
    
    -- Map the connection to shared memory for register reads and writes.
    m00_axi_awvalid <= mc_full_mosi(c_vitis_shared_full_index).awvalid; -- out std_logic;
    
    awaddr64bit(16 downto 0) <= mc_full_mosi(c_vitis_shared_full_index).awaddr(16 downto 0);
    awaddr64bit(63 downto 17) <= (others => '0');
    m00_axi_awaddr  <= std_logic_vector(unsigned(DMASharedMemAddr) + unsigned(awaddr64bit)); 
    
    m00_axi_awid    <= mc_full_mosi(c_vitis_shared_full_index).awid(C_M_AXI_ID_WIDTH - 1 downto 0); -- out std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
    m00_axi_awlen   <= mc_full_mosi(c_vitis_shared_full_index).awlen(7 downto 0); -- out std_logic_vector(7 downto 0);
    m00_axi_awsize  <= mc_full_mosi(c_vitis_shared_full_index).awsize(2 downto 0); -- out std_logic_vector(2 downto 0);
    m00_axi_awburst <= mc_full_mosi(c_vitis_shared_full_index).awburst(1 downto 0); -- out std_logic_vector(1 downto 0);
    m00_axi_awlock  <= "00"; -- mc_full_mosi(c_vitis_shared_full_index).awlock(1 downto 0);  -- out std_logic_vector(1 downto 0);
    m00_axi_awcache <= mc_full_mosi(c_vitis_shared_full_index).awcache(3 downto 0); -- out std_logic_vector(3 downto 0);
    m00_axi_awprot  <= mc_full_mosi(c_vitis_shared_full_index).awprot(2 downto 0);  -- out std_logic_vector(2 downto 0);
    m00_axi_awqos   <= mc_full_mosi(c_vitis_shared_full_index).awqos(3 downto 0);   -- out std_logic_vector(3 downto 0);
    m00_axi_awregion <= mc_full_mosi(c_vitis_shared_full_index).awregion(3 downto 0); -- out std_logic_vector(3 downto 0);
    mc_full_miso(c_vitis_shared_full_index).awready <= m00_axi_awready; --in std_logic;
    
    m00_axi_wvalid <= mc_full_mosi(c_vitis_shared_full_index).wvalid; -- out std_logic;
    mc_full_miso(c_vitis_shared_full_index).wready <= m00_axi_wready; -- in std_logic;
    m00_axi_wdata <= mc_full_mosi(c_vitis_shared_full_index).wdata(C_M_AXI_DATA_WIDTH-1 downto 0);   -- out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    m00_axi_wstrb <= mc_full_mosi(c_vitis_shared_full_index).wstrb(C_M_AXI_DATA_WIDTH/8-1 downto 0); -- out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
    m00_axi_wlast <= mc_full_mosi(c_vitis_shared_full_index).wlast; -- out std_logic;
    
    mc_full_miso(c_vitis_shared_full_index).bvalid <= m00_axi_bvalid; -- in std_logic;
    m00_axi_bready <= mc_full_mosi(c_vitis_shared_full_index).bready; -- out std_logic;
    mc_full_miso(c_vitis_shared_full_index).bresp(1 downto 0) <= m00_axi_bresp; -- in std_logic_vector(1 downto 0);
    mc_full_miso(c_vitis_shared_full_index).bid(C_M_AXI_ID_WIDTH - 1 downto 0) <= m00_axi_bid; -- in std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
    
    m00_axi_arvalid <= mc_full_mosi(c_vitis_shared_full_index).arvalid; -- out std_logic;
    mc_full_miso(c_vitis_shared_full_index).arready <= m00_axi_arready; -- in std_logic;
    
    
    araddr64bit(16 downto 0) <= mc_full_mosi(c_vitis_shared_full_index).araddr(16 downto 0);
    araddr64bit(63 downto 17) <= (others => '0');
    m00_axi_araddr <= std_logic_vector(unsigned(DMASharedMemAddr) + unsigned(araddr64bit));
    m00_axi_arid <= mc_full_mosi(c_vitis_shared_full_index).arid(C_M_AXI_ID_WIDTH-1 downto 0); -- out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
    m00_axi_arlen <= mc_full_mosi(c_vitis_shared_full_index).arlen(7 downto 0); -- out std_logic_vector(7 downto 0);
    m00_axi_arsize <= mc_full_mosi(c_vitis_shared_full_index).arsize(2 downto 0); -- out std_logic_vector(2 downto 0);
    m00_axi_arburst <= mc_full_mosi(c_vitis_shared_full_index).arburst(1 downto 0); -- out std_logic_vector(1 downto 0);
    m00_axi_arlock <= "00"; -- out std_logic_vector(1 downto 0);
    m00_axi_arcache <= mc_full_mosi(c_vitis_shared_full_index).arcache(3 downto 0); -- out std_logic_vector(3 downto 0);
    m00_axi_arprot <= mc_full_mosi(c_vitis_shared_full_index).arprot(2 downto 0); -- out std_logic_Vector(2 downto 0);
    m00_axi_arqos <= mc_full_mosi(c_vitis_shared_full_index).arqos(3 downto 0);   -- out std_logic_vector(3 downto 0);
    m00_axi_arregion <= mc_full_mosi(c_vitis_shared_full_index).arregion(3 downto 0); -- out std_logic_vector(3 downto 0);
    
    mc_full_miso(c_vitis_shared_full_index).rvalid <= m00_axi_rvalid; -- in std_logic;
    m00_axi_rready <= mc_full_mosi(c_vitis_shared_full_index).rready; -- out std_logic;
    mc_full_miso(c_vitis_shared_full_index).rdata(C_M_AXI_DATA_WIDTH-1 downto 0) <= m00_axi_rdata; -- in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    mc_full_miso(c_vitis_shared_full_index).rlast <= m00_axi_rlast; -- in std_logic;
    mc_full_miso(c_vitis_shared_full_index).rid(C_M_AXI_ID_WIDTH - 1 downto 0) <= m00_axi_rid; -- in std_logic_vector(C_M_AXI_ID_WIDTH - 1 downto 0);
    mc_full_miso(c_vitis_shared_full_index).rresp(1 downto 0) <= m00_axi_rresp; -- in std_logic_vector(1 downto 0)    
    
    
    ---------------------------------------------------------------------------
    -- TOP Level Registers  --
    ---------------------------------------------------------------------------

    fpga_regs: ENTITY cnic_lib.cnic_system_reg
    GENERIC MAP (
        g_technology      => c_tech_alveo)
    PORT MAP (
        mm_clk            => ap_clk,
        mm_rst            => ap_rst,
        sla_in            => mc_lite_mosi(c_system_lite_index),
        sla_out           => mc_lite_miso(c_system_lite_index),
        system_fields_rw  => system_fields_rw,
        system_fields_ro  => system_fields_ro);
    
    
    system_fields_ro.firmware_major_version	<= g_FIRMWARE_MAJOR_VERSION;
    system_fields_ro.firmware_minor_version	<= g_FIRMWARE_MINOR_VERSION;
    system_fields_ro.firmware_patch_version	<= g_FIRMWARE_PATCH_VERSION;
    system_fields_ro.firmware_label			<= g_FIRMWARE_LABEL;
    system_fields_ro.firmware_personality	<= g_FIRMWARE_PERSONALITY;
    system_fields_ro.build_date             <= g_FIRMWARE_BUILD_DATE;
    
   
    -- Uptime counter
    process(ap_clk)
    begin
        if rising_edge(ap_clk) then
            -- Assume 300 MHz for ap_clk, 
            if (unsigned(ap_clk_count) < 299999999) then
                ap_clk_count <= std_logic_vector(unsigned(ap_clk_count) + 1);
            else
                ap_clk_count <= (others => '0');
                uptime <= std_logic_vector(unsigned(uptime) + 1);
            end if;
        end if;
    end process;
    system_fields_ro.time_uptime <= uptime;
    system_fields_ro.status_clocks_locked <= '1';
    
    -- clock domain conversions :
    --  From ap_clk to clk_gt_freerun_use
    --    t_system_rw.qsfpgty_resets -> eth100_reset
    -- xpm_cdc_single: Single-bit Synchronizer, Xilinx Parameterized Macro, version 2019.1
    xpm_cdc_single_inst : xpm_cdc_single
    generic map (
        DEST_SYNC_FF => 2,   -- DECIMAL; range: 2-10
        INIT_SYNC_FF => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_INPUT_REG => 1   -- DECIMAL; 0=do not register input, 1=register input
    )
    port map (
        dest_out => eth100_reset, -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        dest_clk => clk_gt_freerun_use, -- 1-bit input: Clock signal for the destination clock domain.
        src_clk => ap_clk,   -- 1-bit input: optional; required when SRC_INPUT_REG = 1
        src_in => system_fields_rw.qsfpgty_resets     -- 1-bit input: Input signal to be synchronized to dest_clk domain.
    );

    fec_enable_cdc_ethernet_322m_domain : xpm_cdc_single
    generic map (
        DEST_SYNC_FF => 2,   -- DECIMAL; range: 2-10
        INIT_SYNC_FF => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_INPUT_REG => 1   -- DECIMAL; 0=do not register input, 1=register input
    )
    port map (
        dest_out => fec_enable_322m, -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        dest_clk => eth100G_clk, -- 1-bit input: Clock signal for the destination clock domain.
        src_clk => ap_clk,   -- 1-bit input: optional; required when SRC_INPUT_REG = 1
        src_in => system_fields_rw.eth100g_fec_enable     -- 1-bit input: Input signal to be synchronized to dest_clk domain.
    );
    
    fec_enable_cdc_gt_input_100m_domain : xpm_cdc_single
    generic map (
        DEST_SYNC_FF => 2,   -- DECIMAL; range: 2-10
        INIT_SYNC_FF => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_INPUT_REG => 1   -- DECIMAL; 0=do not register input, 1=register input
    )
    port map (
        dest_out => fec_enable_100m, -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
        dest_clk => clk_gt_freerun_use, -- 1-bit input: Clock signal for the destination clock domain.
        src_clk => ap_clk,   -- 1-bit input: optional; required when SRC_INPUT_REG = 1
        src_in => system_fields_rw.eth100g_fec_enable     -- 1-bit input: Input signal to be synchronized to dest_clk domain.
    );
    
    --  From eth100G_clk -> ap_clk
    --    eth100G_locked, eth100G_rx_total_packets, eth100G_rx_bad_fcs, eth100G_rx_bad_code, eth100G_tx_total_packets
    xpm_cdc_handshake_inst : xpm_cdc_handshake
    generic map (
        DEST_EXT_HSK => 0,   -- DECIMAL; 0=internal handshake, 1=external handshake
        DEST_SYNC_FF => 2,   -- DECIMAL; range: 2-10
        INIT_SYNC_FF => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
        SIM_ASSERT_CHK => 0, -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        SRC_SYNC_FF => 2,    -- DECIMAL; range: 2-10
        WIDTH => 129         -- DECIMAL; range: 1-1024
    )
    port map (
        dest_out => eth100G_status_ap_clk, -- WIDTH-bit output: Input bus (src_in) synchronized to destination clock domain. This output is registered.
        dest_req => dest_req, -- 1-bit output: '1' indicates that new dest_out data is valid, will pulse high if DEST_EXT_HSK = 0 
        src_rcv => eth100G_rcv,   -- 1-bit output: Acknowledgement from destination logic that src_in has been received. This signal will be deasserted once destination handshake has fully completed
        dest_ack => '1', -- 1-bit input: optional; required when DEST_EXT_HSK = 1
        dest_clk => ap_clk,     -- 1-bit input: Destination clock.
        src_clk  => eth100G_clk, -- 1-bit input: Source clock.
        src_in => eth100G_status_eth_clk,     -- WIDTH-bit input: Input bus that will be synchronized to the destination clock domain.
        src_send => eth100G_send  -- 1-bit input: Assertion of this signal allows the src_in bus to be synchronized to the destination clock domain. 
    );

    process(ap_clk)
    begin
        if rising_edge(ap_clk) then
            if dest_req = '1' then
                system_fields_ro.eth100G_locked <= eth100G_status_ap_clk(128);
                system_fields_ro.eth100G_rx_total_packets <= eth100G_status_ap_clk(127 downto 96);
                system_fields_ro.eth100G_rx_bad_fcs <= eth100G_status_ap_clk(95 downto 64);  
                system_fields_ro.eth100G_rx_bad_code <= eth100G_status_ap_clk(63 downto 32);
                system_fields_ro.eth100G_tx_total_packets <= eth100G_status_ap_clk(31 downto 0);
            end if;
        end if;
    end process;
    
    process(eth100G_clk)
    begin
        if rising_edge(eth100G_clk) then
            eth100G_status_eth_clk(128) <= eth100G_locked;
            eth100G_status_eth_clk(127 downto 96) <= eth100G_rx_total_packets;
            eth100G_status_eth_clk(95 downto 64) <= eth100G_rx_bad_fcs;
            eth100G_status_eth_clk(63 downto 32) <= eth100G_rx_bad_code;
            eth100G_status_eth_clk(31 downto 0) <= eth100G_tx_total_packets;
            if eth100G_rcv = '0' then
                eth100G_send <= '1'; -- just send across the clock domain whenever the clock crossing module is ready.
            else
                eth100G_send <= '0';
            end if;
        end if;
    end process;
    
    
    sync_stats_to_Host: FOR i IN 0 TO (packetiser_CDC_paths - 1) GENERATE
        stats_crossing : entity signal_processing_common.sync_vector
            generic map (
                WIDTH => 32
            )
            Port Map ( 
                clock_a_rst => NOT eth100G_locked,
                Clock_a     => eth100G_clk,
                data_in     => packetiser_stats(i),
                
                Clock_b     => ap_clk,
                data_out    => packetiser_stats_crossed(i)
            );  

    END GENERATE;

    

    
    -------------------------------------------------------------------------------------------
    -- 100G ethernet
    -------------------------------------------------------------------------------------------

NO_PTP_GEN : IF (NOT g_PTP_ENABLE) GENERATE
    u_100G : entity cnic_lib.mac_100g_wrapper
    Port map(
        gt_rxp_in   => gt_rxp_in, -- in(3:0);
        gt_rxn_in   => gt_rxn_in, -- in(3:0);
        gt_txp_out  => gt_txp_out, -- out(3:0);
        gt_txn_out  => gt_txn_out, -- out(3:0);
        gt_refclk_p => gt_refclk_p, -- IN STD_LOGIC;
        gt_refclk_n => gt_refclk_n, -- IN STD_LOGIC;
        sys_reset   => eth100_reset_final,   -- IN STD_LOGIC;   -- sys_reset, clocked by dclk.
        i_dclk_100  => clk_gt_freerun_use, --  IN STD_LOGIC;   -- stable clock for the core; The frequency is specified in the wizard. See comments above about the actual frequency supplied by the Alveo platform.        
        -- loopback for the GTYs
        -- "000" = normal operation, "001" = near-end PCS loopback, "010" = near-end PMA loopback
        -- "100" = far-end PMA loopback, "110" = far-end PCS loopback.
        -- See GTY user guid (Xilinx doc UG578) for details.
        loopback  => "000", -- in(2:0);  
        tx_enable => '1',   -- in std_logic;
        rx_enable => '1',   -- in std_logic;
        i_fec_enable    => fec_enable_322m,
        -- All remaining signals are clocked on tx_clk_out
        tx_clk_out => eth100G_clk, -- out std_logic; This is the clock used by the data in and out of the core. 322 MHz.
        
        -- User Interface Signals
        rx_locked  => eth100G_locked, -- out std_logic; 

        user_rx_reset => eth100G_rx_reset, -- out std_logic;
        user_tx_reset => eth100G_tx_reset, -- out std_logic;

        -- Statistics Interface, on eth100_clk
        rx_total_packets => eth100G_rx_total_packets, -- out(31:0);
        rx_bad_fcs       => eth100G_rx_bad_fcs,       -- out(31:0);
        rx_bad_code      => eth100G_rx_bad_code,      -- out(31:0);
        tx_total_packets => eth100G_tx_total_packets, -- out(31:0);
        
        -- Received data from optics
        data_rx_sosi => eth100_rx_sosi, -- out t_lbus_sosi;

        -- Data to be transmitted to optics
        data_tx_sosi => eth100_tx_sosi, -- IN t_lbus_sosi;
        data_tx_siso => eth100_tx_siso,  -- OUT t_lbus_siso
        
        -- ARGs Interface
        i_MACE_clk  => ap_clk, -- in std_logic;
        i_MACE_rst  => ap_rst, -- in std_logic;
        i_DRP_Lite_axi_mosi => mc_lite_mosi(c_cmac_lite_index),
        o_DRP_Lite_axi_miso => mc_lite_miso(c_cmac_lite_index)
    );
END GENERATE;

WITH_PTP_GEN : IF g_PTP_ENABLE GENERATE


u_100G_port_a : entity Timeslave_CMAC_lib.CMAC_100G_wrap_w_timeslave
    Generic map (
        U55_TOP_QSFP        => g_ALVEO_U55,
        U55_BOTTOM_QSFP     => g_ALVEO_U50         -- THIS CONFIG IS VALID FOR U50 as well.
    )
    Port map(
        gt_rxp_in   => gt_rxp_in, -- in(3:0);
        gt_rxn_in   => gt_rxn_in, -- in(3:0);
        gt_txp_out  => gt_txp_out, -- out(3:0);
        gt_txn_out  => gt_txn_out, -- out(3:0);
        gt_refclk_p => gt_refclk_p, -- IN STD_LOGIC;
        gt_refclk_n => gt_refclk_n, -- IN STD_LOGIC;
        sys_reset   => eth100_reset_final,   -- IN STD_LOGIC;   -- sys_reset, clocked by dclk.
        i_dclk_100  => clk_gt_freerun_use, --  IN STD_LOGIC;   -- stable clock for the core; The frequency is specified in the wizard. See comments above about the actual frequency supplied by the Alveo platform.       
        clk250      => clk100, 
        
        i_fec_enable    => fec_enable_322m,
        -- All remaining signals are clocked on tx_clk_out
        tx_clk_out                  => eth100G_clk, -- out std_logic; This is the clock used by the data in and out of the core. 322 MHz.
        
        -- User Interface Signals
        rx_locked                   => eth100G_locked, -- out std_logic; 

        user_rx_reset               => open,
        user_tx_reset               => open,

        -- Statistics Interface, on eth100_clk
        rx_total_packets => eth100G_rx_total_packets, -- out(31:0);
        rx_bad_fcs       => eth100G_rx_bad_fcs,       -- out(31:0);
        rx_bad_code      => eth100G_rx_bad_code,      -- out(31:0);
        tx_total_packets => eth100G_tx_total_packets, -- out(31:0);
        
        -----------------------------------------------------------------------
        -- streaming AXI to CMAC
        i_tx_axis_tdata     => tx_axis_tdata,
        i_tx_axis_tkeep     => tx_axis_tkeep,
        i_tx_axis_tvalid    => tx_axis_tvalid,
        i_tx_axis_tlast     => tx_axis_tlast,
        i_tx_axis_tuser     => tx_axis_tuser,
        o_tx_axis_tready    => tx_axis_tready,
        
        -- RX
        o_rx_axis_tdata     => rx_axis_tdata,
        o_rx_axis_tkeep     => rx_axis_tkeep,
        o_rx_axis_tlast     => rx_axis_tlast,
        i_rx_axis_tready    => rx_axis_tready,
        o_rx_axis_tuser     => rx_axis_tuser,
        o_rx_axis_tvalid    => rx_axis_tvalid,
        
        -----------------------------------------------------------------------
        
        -- PTP Data
        PTP_time_CMAC_clk           => PTP_time_CMAC_clk,
        PTP_pps_CMAC_clk            => PTP_pps_CMAC_clk,
        
        PTP_time_ARGs_clk           => PTP_time_ARGs_clk,
        PTP_pps_ARGs_clk            => PTP_pps_ARGs_clk,
        
        -- ARGs Interface
        i_ARGs_clk                  => ap_clk, -- in std_logic;
        i_ARGs_rst                  => ap_rst, -- in std_logic;
        
        i_CMAC_Lite_axi_mosi        => mc_lite_mosi(c_cmac_lite_index),
        o_CMAC_Lite_axi_miso        => mc_lite_miso(c_cmac_lite_index),
        
        i_Timeslave_Full_axi_mosi   => mc_full_mosi(c_timeslave_full_index),
        o_Timeslave_Full_axi_miso   => mc_full_miso(c_timeslave_full_index)
    );
    
-- not used
--    U55_2nd_port : IF g_ALVEO_U55 GENERATE
--        u_100G_port_b : entity Timeslave_CMAC_lib.CMAC_100G_wrap_w_timeslave
--        Generic map (
--            U55_TOP_QSFP        => FALSE,
--            U55_BOTTOM_QSFP     => g_ALVEO_U55         -- THIS CONFIG IS VALID FOR U50 as well.
--        )
--        Port map(
--            gt_rxp_in   => gt_b_rxp_in, -- in(3:0);
--            gt_rxn_in   => gt_b_rxn_in, -- in(3:0);
--            gt_txp_out  => gt_b_txp_out, -- out(3:0);
--            gt_txn_out  => gt_b_txn_out, -- out(3:0);
--            gt_refclk_p => gt_refclk_b_p, -- IN STD_LOGIC;
--            gt_refclk_n => gt_refclk_b_n, -- IN STD_LOGIC;
--            sys_reset   => eth100_reset_final,   -- IN STD_LOGIC;   -- sys_reset, clocked by dclk.
--            i_dclk_100  => clk_gt_freerun_use, --  IN STD_LOGIC;   -- stable clock for the core; The frequency is specified in the wizard. See comments above about the actual frequency supplied by the Alveo platform.       
--            clk250      => clk100, 
            
--            i_fec_enable                => fec_enable_322m,
--            -- All remaining signals are clocked on tx_clk_out
--            tx_clk_out                  => eth100G_clk_b, -- out std_logic; This is the clock used by the data in and out of the core. 322 MHz.
            
--            -- User Interface Signals
--            rx_locked                   => eth100G_locked_b, -- out std_logic; 
    
--            user_rx_reset               => open,
--            user_tx_reset               => open,
    
--            -- Statistics Interface, on eth100_clk
--            rx_total_packets => open, -- out(31:0);
--            rx_bad_fcs       => open,       -- out(31:0);
--            rx_bad_code      => open,      -- out(31:0);
--            tx_total_packets => open, -- out(31:0);
            
--            -----------------------------------------------------------------------
--            -- streaming AXI to CMAC
--            i_tx_axis_tdata     => tx_axis_tdata_b,
--            i_tx_axis_tkeep     => tx_axis_tkeep_b,
--            i_tx_axis_tvalid    => tx_axis_tvalid_b,
--            i_tx_axis_tlast     => tx_axis_tlast_b,
--            i_tx_axis_tuser     => tx_axis_tuser_b,
--            o_tx_axis_tready    => tx_axis_tready_b,
            
--            -- RX
--            o_rx_axis_tdata     => open,
--            o_rx_axis_tkeep     => open,
--            o_rx_axis_tlast     => open,
--            i_rx_axis_tready    => '1',
--            o_rx_axis_tuser     => open,
--            o_rx_axis_tvalid    => open,
            
--            -----------------------------------------------------------------------
            
--            -- PTP Data
--            PTP_time_CMAC_clk           => open,
--            PTP_pps_CMAC_clk            => open,
            
--            PTP_time_ARGs_clk           => open,
--            PTP_pps_ARGs_clk            => open,
            
--            -- ARGs Interface
--            i_ARGs_clk                  => ap_clk, -- in std_logic;
--            i_ARGs_rst                  => ap_rst, -- in std_logic;
            
--            i_CMAC_Lite_axi_mosi        => mc_lite_mosi(c_cmac_b_lite_index),
--            o_CMAC_Lite_axi_miso        => mc_lite_miso(c_cmac_b_lite_index),
            
--            i_Timeslave_Full_axi_mosi   => mc_full_mosi(c_timeslave_b_full_index),
--            o_Timeslave_Full_axi_miso   => mc_full_miso(c_timeslave_b_full_index)
--        );
--    END GENERATE;
    

    CMAC_reset_proc : process(eth100G_clk)
    begin
        if rising_edge(eth100G_clk) then
            eth100G_reset <= NOT eth100G_locked;
    
        end if;
    end process;

    PTP_hardware_scheduler : entity Timeslave_CMAC_lib.timeslave_scheduler 
    Generic map (
        DEBUG_ILA                   => FALSE
    )
    Port map ( 
        i_CMAC_clk                  => eth100G_clk,
        i_cmac_reset                => eth100G_reset,
        
        i_ARGs_clk                  => ap_clk,
        i_ARGs_rst                  => ap_rst,
        
        o_schedule                  => schedule_action, 
        
        -- PTP Data
        i_PTP_time_CMAC_clk         => PTP_time_CMAC_clk,
        i_PTP_pps_CMAC_clk          => PTP_pps_CMAC_clk,
    
        i_PTP_time_ARGs_clk         => PTP_time_ARGs_clk,
        i_PTP_pps_ARGs_clk          => PTP_pps_ARGs_clk,
        
        i_Timeslave_Lite_axi_mosi   => mc_lite_mosi(c_timeslave_lite_index), 
        o_Timeslave_Lite_axi_miso   => mc_lite_miso(c_timeslave_lite_index)
    
    );

END GENERATE;



    process(clk_gt_freerun_use)
    begin
        if rising_edge(clk_gt_freerun_use) then
            if (unsigned(freerunCount) < 100000000) then
                freerunCount <= std_logic_vector(unsigned(freerunCount) + 1);
            else
                freerunCount <= (others => '0');
                freerunSecCount <= std_logic_vector(unsigned(freerunSecCount) + 1);
            end if;
            
            if (unsigned(freerunSecCount) < 2) then   -- document for the 100G core just says that reset needs to be asserted until the clocks are stable.
                GTY_startup_rst <= '1';
            else
                GTY_startup_rst <= '0';
            end if;
            
            eth100_reset_final <= eth100_reset or GTY_startup_rst or fec_enable_reset;
            
        end if;
    end process;
    
    load_new_fec_state_proc : process(clk_gt_freerun_use)
    begin
        if rising_edge(clk_gt_freerun_use) then
        
            fec_enable_cache <= fec_enable_100m;
            
            if fec_enable_cache /= fec_enable_100m then
                fec_enable_reset_count <= 0;
                fec_enable_reset <= '1';
            elsif fec_enable_reset_count < 100 then
                fec_enable_reset_count <= fec_enable_reset_count + 1;
            else
                fec_enable_reset <= '0';
            end if;
            
        end if;
    end process;
    
    
    process(eth100G_clk)
    begin
        if rising_edge(eth100G_clk) then
            if (unsigned(eth100G_uptime) < 322000000) then
                eth100G_uptime <= std_logic_vector(unsigned(eth100G_uptime) + 1);
            else
                eth100G_uptime <= (others => '0');
                eth100G_seconds <= std_logic_vector(unsigned(eth100G_seconds) + 1);
            end if;
            
        end if;
    end process;



    i_cnic_top : entity cnic_lib.cnic_top
    generic map (
        g_DEBUG_ILA                     => g_DEBUG_ILA
    ) port map (
        clk_freerun => clk_freerun, 
        -----------------------------------------------------------------------

        -- TX
        -- streaming AXI to CMAC
        o_tx_axis_tdata     => tx_axis_tdata,
        o_tx_axis_tkeep     => tx_axis_tkeep,
        o_tx_axis_tvalid    => tx_axis_tvalid,
        o_tx_axis_tlast     => tx_axis_tlast,
        o_tx_axis_tuser     => tx_axis_tuser,
        i_tx_axis_tready    => tx_axis_tready,

        -- CMAC LBUS        
        -- Received data from 100GE
        i_data_rx_sosi      => eth100_rx_sosi, -- in t_lbus_sosi;
        -- Data to be transmitted on 100GE
        o_data_tx_sosi      => eth100_tx_sosi, -- out t_lbus_sosi;
        i_data_tx_siso      => eth100_tx_siso, -- in t_lbus_siso;
        
        -- RX
        i_rx_axis_tdata     => rx_axis_tdata,
        i_rx_axis_tkeep     => rx_axis_tkeep,
        i_rx_axis_tlast     => rx_axis_tlast,
        o_rx_axis_tready    => rx_axis_tready,
        i_rx_axis_tuser     => rx_axis_tuser,
        i_rx_axis_tvalid    => rx_axis_tvalid,
        
        
        i_clk_100GE         => eth100G_clk,      -- in std_logic;
        i_eth100G_locked    => eth100G_locked,
        -----------------------------------------------------------------------
        i_clk_100GE_b       => eth100G_clk_b,
        i_eth100G_locked_b  => eth100G_locked_b,
         
        o_tx_axis_tdata_b   => tx_axis_tdata_b,
        o_tx_axis_tkeep_b   => tx_axis_tkeep_b,
        o_tx_axis_tvalid_b  => tx_axis_tvalid_b,
        o_tx_axis_tlast_b   => tx_axis_tlast_b,
        o_tx_axis_tuser_b   => tx_axis_tuser_b,
        i_tx_axis_tready_b  => tx_axis_tready_b,
        -----------------------------------------------------------------------
        -- reset of the valid memory is in progress.
        o_validMemRstActive => o_validMemRstActive,
        -----------------------------------------------------------------------
        -- AXI slave interfaces for modules
        i_MACE_clk  => ap_clk, -- in std_logic;
        i_MACE_rst  => ap_rst, -- in std_logic;

        -- HBM_Pktcontroller interface
        i_HBM_Pktcontroller_Lite_axi_mosi  => mc_lite_mosi(c_hbm_pktcontroller_lite_index),
        o_HBM_Pktcontroller_Lite_axi_miso  => mc_lite_miso(c_hbm_pktcontroller_lite_index),
        
        
        -----------------------------------------------------------------------
        i_schedule_action       => schedule_action,
        -----------------------------------------------------------------------
        -- AXI interfaces to shared memory

	-- M01
        m01_axi_awvalid => m01_axi_awvalidi,   -- out std_logic;
        m01_axi_awready => m01_axi_awreadyi,   -- in std_logic;
        m01_axi_awaddr  => m01_axi_awaddri(31 downto 0),    -- out std_logic_vector(29 downto 0);
        m01_axi_awlen   => m01_axi_awleni,     -- out std_logic_vector(7 downto 0); Number of beats in each burst is this value + 1.
        -- w bus - write data.
        m01_axi_wvalid   => m01_axi_wvalidi,   -- out std_logic;
        m01_axi_wready   => m01_axi_wreadyi,   -- in std_logic;
        m01_axi_wdata    => m01_axi_wdatai,    -- out std_logic_vector(511 downto 0);
        m01_axi_wlast    => m01_axi_wlasti,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m01_axi_bvalid   => m01_axi_bvalidi,   -- in std_logic;
        m01_axi_bresp    => m01_axi_brespi,    -- in std_logic_vector(1 downto 0);
        -- ar - read address
        m01_axi_arvalid  => m01_axi_arvalidi,  -- out std_logic;
        m01_axi_arready  => m01_axi_arreadyi,  -- in std_logic;
        m01_axi_araddr   => m01_axi_araddri(31 downto 0),   -- out std_logic_vector(29 downto 0);
        m01_axi_arlen    => m01_axi_arleni,    -- out std_logic_vector(7 downto 0); --  Number of beats in each burst is this value + 1.
        -- r - read data
        m01_axi_rvalid   => m01_axi_rvalidi,   -- in std_logic;
        m01_axi_rready   => m01_axi_rreadyi,   -- out std_logic;
        m01_axi_rdata    => m01_axi_rdatai,    -- in std_logic_vector(511 downto 0);
        m01_axi_rlast    => m01_axi_rlasti,    -- in std_logic;        
        m01_axi_rresp    => m01_axi_rrespi,    -- in std_logic_vector(1 downto 0); -- read response; "00" and "01 are ok, "10" and "11" indicate an error.

	-- m02
        m02_axi_awvalid => m02_axi_awvalidi,   -- out std_logic;
        m02_axi_awready => m02_axi_awreadyi,   -- in std_logic;
        m02_axi_awaddr  => m02_axi_awaddri(31 downto 0),    -- out std_logic_vector(29 downto 0);
        m02_axi_awlen   => m02_axi_awleni,     -- out std_logic_vector(7 downto 0); Number of beats in each burst is this value + 1.
        -- w bus - write data.
        m02_axi_wvalid   => m02_axi_wvalidi,   -- out std_logic;
        m02_axi_wready   => m02_axi_wreadyi,   -- in std_logic;
        m02_axi_wdata    => m02_axi_wdatai,    -- out std_logic_vector(511 downto 0);
        m02_axi_wlast    => m02_axi_wlasti,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m02_axi_bvalid   => m02_axi_bvalidi,   -- in std_logic;
        m02_axi_bresp    => m02_axi_brespi,    -- in std_logic_vector(1 downto 0);
        -- ar - read address
        m02_axi_arvalid  => m02_axi_arvalidi,  -- out std_logic;
        m02_axi_arready  => m02_axi_arreadyi,  -- in std_logic;
        m02_axi_araddr   => m02_axi_araddri(31 downto 0),   -- out std_logic_vector(29 downto 0);
        m02_axi_arlen    => m02_axi_arleni,    -- out std_logic_vector(7 downto 0); --  Number of beats in each burst is this value + 1.
        -- r - read data
        m02_axi_rvalid   => m02_axi_rvalidi,   -- in std_logic;
        m02_axi_rready   => m02_axi_rreadyi,   -- out std_logic;
        m02_axi_rdata    => m02_axi_rdatai,    -- in std_logic_vector(511 downto 0);
        m02_axi_rlast    => m02_axi_rlasti,    -- in std_logic;        
        m02_axi_rresp    => m02_axi_rrespi,    -- in std_logic_vector(1 downto 0); -- read response; "00" and "01 are ok, "10" and "11" indicate an error.

	-- m03
        m03_axi_awvalid => m03_axi_awvalidi,   -- out std_logic;
        m03_axi_awready => m03_axi_awreadyi,   -- in std_logic;
        m03_axi_awaddr  => m03_axi_awaddri(31 downto 0),    -- out std_logic_vector(29 downto 0);
        m03_axi_awlen   => m03_axi_awleni,     -- out std_logic_vector(7 downto 0); Number of beats in each burst is this value + 1.
        -- w bus - write data.
        m03_axi_wvalid   => m03_axi_wvalidi,   -- out std_logic;
        m03_axi_wready   => m03_axi_wreadyi,   -- in std_logic;
        m03_axi_wdata    => m03_axi_wdatai,    -- out std_logic_vector(511 downto 0);
        m03_axi_wlast    => m03_axi_wlasti,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m03_axi_bvalid   => m03_axi_bvalidi,   -- in std_logic;
        m03_axi_bresp    => m03_axi_brespi,    -- in std_logic_vector(1 downto 0);
        -- ar - read address
        m03_axi_arvalid  => m03_axi_arvalidi,  -- out std_logic;
        m03_axi_arready  => m03_axi_arreadyi,  -- in std_logic;
        m03_axi_araddr   => m03_axi_araddri(31 downto 0),   -- out std_logic_vector(29 downto 0);
        m03_axi_arlen    => m03_axi_arleni,    -- out std_logic_vector(7 downto 0); --  Number of beats in each burst is this value + 1.
        -- r - read data
        m03_axi_rvalid   => m03_axi_rvalidi,   -- in std_logic;
        m03_axi_rready   => m03_axi_rreadyi,   -- out std_logic;
        m03_axi_rdata    => m03_axi_rdatai,    -- in std_logic_vector(511 downto 0);
        m03_axi_rlast    => m03_axi_rlasti,    -- in std_logic;        
        m03_axi_rresp    => m03_axi_rrespi,    -- in std_logic_vector(1 downto 0); -- read response; "00" and "01 are ok, "10" and "11" indicate an error.

	-- m04
        m04_axi_awvalid => m04_axi_awvalidi,   -- out std_logic;
        m04_axi_awready => m04_axi_awreadyi,   -- in std_logic;
        m04_axi_awaddr  => m04_axi_awaddri(31 downto 0),    -- out std_logic_vector(29 downto 0);
        m04_axi_awlen   => m04_axi_awleni,     -- out std_logic_vector(7 downto 0); Number of beats in each burst is this value + 1.
        -- w bus - write data.
        m04_axi_wvalid   => m04_axi_wvalidi,   -- out std_logic;
        m04_axi_wready   => m04_axi_wreadyi,   -- in std_logic;
        m04_axi_wdata    => m04_axi_wdatai,    -- out std_logic_vector(511 downto 0);
        m04_axi_wlast    => m04_axi_wlasti,    -- out std_logic;
        -- b bus - write response; "00" or "01" means ok, "10" or "11" means the write failed.
        m04_axi_bvalid   => m04_axi_bvalidi,   -- in std_logic;
        m04_axi_bresp    => m04_axi_brespi,    -- in std_logic_vector(1 downto 0);
        -- ar - read address
        m04_axi_arvalid  => m04_axi_arvalidi,  -- out std_logic;
        m04_axi_arready  => m04_axi_arreadyi,  -- in std_logic;
        m04_axi_araddr   => m04_axi_araddri(31 downto 0),   -- out std_logic_vector(29 downto 0);
        m04_axi_arlen    => m04_axi_arleni,    -- out std_logic_vector(7 downto 0); --  Number of beats in each burst is this value + 1.
        -- r - read data
        m04_axi_rvalid   => m04_axi_rvalidi,   -- in std_logic;
        m04_axi_rready   => m04_axi_rreadyi,   -- out std_logic;
        m04_axi_rdata    => m04_axi_rdatai,    -- in std_logic_vector(511 downto 0);
        m04_axi_rlast    => m04_axi_rlasti,    -- in std_logic;        
        m04_axi_rresp    => m04_axi_rrespi    -- in std_logic_vector(1 downto 0); -- read response; "00" and "01 are ok, "10" and "11" indicate an error.

    );

---------------------------------------------------------------------------------------------------------------
-- HBM mappings and AXI register slice for timing
---------------------------------------------------------------------------------------------------------------    
    -- Default outgoing signals for m01 bus
    m01_axi_araddri(63 downto 32) <= m01_shared(63 downto 32);  
    m01_axi_awaddri(63 downto 32) <= m01_shared(63 downto 32);
    m01_axi_awidi(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m01_axi_awsizei  <= "110";  -- size of 6 indicates 64 bytes in each beat (i.e. 512 bit wide bus) -- out std_logic_vector(2 downto 0);
    m01_axi_awbursti <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m01_axi_breadyi  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m01_axi_wstrbi  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m01_axi_aridi(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m01_axi_arsizei  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m01_axi_arbursti <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
   
    -- these have no ports on the axi register slice
    m01_axi_arlock <= "00";
    m01_axi_awlock <= "00";
    m01_axi_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m01_axi_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m01_axi_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m01_axi_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m01_axi_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m01_axi_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m01_axi_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m01_axi_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    -- Ignored incoming signals for m01 bus:
    -- m01_axi_bid; Since we only use 1 ID, we can ignore this. -- in std_logic_vector(0 downto 0);
    -- m01_axi_rid  -- in std_logic_vector(0 downto 0);
    
    
    -- Register slice for the m01 AXI interface
    m01_reg_slice : axi_reg_slice512_LLFFL
    port map (
        aclk    => ap_clk, --  IN STD_LOGIC;
        aresetn => ap_rst_n, --  IN STD_LOGIC;
        -- 
        s_axi_awaddr   => m01_axi_awaddri, -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen    => m01_axi_awleni,  -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize   => m01_axi_awsizei, -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst  => m01_axi_awbursti, -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awvalid  => m01_axi_awvalidi,  -- IN STD_LOGIC;
        s_axi_awready  => m01_axi_awreadyi,  -- OUT STD_LOGIC;
        s_axi_wdata    => m01_axi_wdatai,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb    => m01_axi_wstrbi,    -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast    => m01_axi_wlasti,    -- IN STD_LOGIC;
        s_axi_wvalid   => m01_axi_wvalidi,   -- IN STD_LOGIC;
        s_axi_wready   => m01_axi_wreadyi,   -- OUT STD_LOGIC;
        s_axi_bresp    => m01_axi_brespi,    --  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid   => m01_axi_bvalidi,   -- OUT STD_LOGIC;
        s_axi_bready   => m01_axi_breadyi,   -- IN STD_LOGIC;
        s_axi_araddr   => m01_axi_araddri,   -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen    => m01_axi_arleni,    -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize   => m01_axi_arsizei,   -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst  => m01_axi_arbursti,  -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid  => m01_axi_arvalidi,  -- IN STD_LOGIC;
        s_axi_arready  => m01_axi_arreadyi,  -- OUT STD_LOGIC;
        s_axi_rdata    => m01_axi_rdatai,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp    => m01_axi_rrespi,    -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast    => m01_axi_rlasti,    -- OUT STD_LOGIC;
        s_axi_rvalid   => m01_axi_rvalidi,   -- OUT STD_LOGIC;
        s_axi_rready   => m01_axi_rreadyi,   -- IN STD_LOGIC;
        --
        m_axi_awaddr   => m01_axi_awaddr, -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen    => m01_axi_awlen,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize   => m01_axi_awsize, -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst  => m01_axi_awburst, -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid  => m01_axi_awvalid,  -- OUT STD_LOGIC;
        m_axi_awready  => m01_axi_awready,  -- IN STD_LOGIC;
        m_axi_wdata    => m01_axi_wdata,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_wstrb    => m01_axi_wstrb,    -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_wlast    => m01_axi_wlast,    -- OUT STD_LOGIC;
        m_axi_wvalid   => m01_axi_wvalid,   -- OUT STD_LOGIC;
        m_axi_wready   => m01_axi_wready,   -- IN STD_LOGIC;
        m_axi_bresp    => m01_axi_bresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid   => m01_axi_bvalid,   -- IN STD_LOGIC;
        m_axi_bready   => m01_axi_bready,   -- OUT STD_LOGIC;
        m_axi_araddr   => m01_axi_araddr,   -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen    => m01_axi_arlen,    -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize   => m01_axi_arsize,   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst  => m01_axi_arburst,  -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
       
        m_axi_arvalid  => m01_axi_arvalid,  -- OUT STD_LOGIC;
        m_axi_arready  => m01_axi_arready,  -- IN STD_LOGIC;
        m_axi_rdata    => m01_axi_rdata,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_rresp    => m01_axi_rresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast    => m01_axi_rlast,    -- IN STD_LOGIC;
        m_axi_rvalid   => m01_axi_rvalid,   -- IN STD_LOGIC;
        m_axi_rready   => m01_axi_rready    --: OUT STD_LOGIC
    );


    -- Default outgoing signals for m02 bus
    m02_axi_araddri(63 downto 32) <= m02_shared(63 downto 32);  
    m02_axi_awaddri(63 downto 32) <= m02_shared(63 downto 32);
    m02_axi_awidi(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m02_axi_awsizei  <= "110";  -- size of 6 indicates 64 bytes in each beat (i.e. 512 bit wide bus) -- out std_logic_vector(2 downto 0);
    m02_axi_awbursti <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m02_axi_breadyi  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m02_axi_wstrbi  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m02_axi_aridi(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m02_axi_arsizei  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m02_axi_arbursti <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
   
    -- these have no ports on the axi register slice
    m02_axi_arlock <= "00";
    m02_axi_awlock <= "00";
    m02_axi_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m02_axi_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m02_axi_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m02_axi_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m02_axi_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m02_axi_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m02_axi_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m02_axi_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    -- Ignored incoming signals for m02 bus:
    -- m02_axi_bid; Since we only use 1 ID, we can ignore this. -- in std_logic_vector(0 downto 0);
    -- m02_axi_rid  -- in std_logic_vector(0 downto 0);
    
-------------------------------------------------------------------------------------------    
    -- Register slice for the m02 AXI interface
    m02_reg_slice : axi_reg_slice512_LLFFL
    port map (
        aclk    => ap_clk, --  IN STD_LOGIC;
        aresetn => ap_rst_n, --  IN STD_LOGIC;
        -- 
        s_axi_awaddr   => m02_axi_awaddri, -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen    => m02_axi_awleni,  -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize   => m02_axi_awsizei, -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst  => m02_axi_awbursti, -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awvalid  => m02_axi_awvalidi,  -- IN STD_LOGIC;
        s_axi_awready  => m02_axi_awreadyi,  -- OUT STD_LOGIC;
        s_axi_wdata    => m02_axi_wdatai,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb    => m02_axi_wstrbi,    -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast    => m02_axi_wlasti,    -- IN STD_LOGIC;
        s_axi_wvalid   => m02_axi_wvalidi,   -- IN STD_LOGIC;
        s_axi_wready   => m02_axi_wreadyi,   -- OUT STD_LOGIC;
        s_axi_bresp    => m02_axi_brespi,    --  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid   => m02_axi_bvalidi,   -- OUT STD_LOGIC;
        s_axi_bready   => m02_axi_breadyi,   -- IN STD_LOGIC;
        s_axi_araddr   => m02_axi_araddri,   -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen    => m02_axi_arleni,    -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize   => m02_axi_arsizei,   -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst  => m02_axi_arbursti,  -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid  => m02_axi_arvalidi,  -- IN STD_LOGIC;
        s_axi_arready  => m02_axi_arreadyi,  -- OUT STD_LOGIC;
        s_axi_rdata    => m02_axi_rdatai,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp    => m02_axi_rrespi,    -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast    => m02_axi_rlasti,    -- OUT STD_LOGIC;
        s_axi_rvalid   => m02_axi_rvalidi,   -- OUT STD_LOGIC;
        s_axi_rready   => m02_axi_rreadyi,   -- IN STD_LOGIC;
        --
        m_axi_awaddr   => m02_axi_awaddr, -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen    => m02_axi_awlen,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize   => m02_axi_awsize, -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst  => m02_axi_awburst, -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid  => m02_axi_awvalid,  -- OUT STD_LOGIC;
        m_axi_awready  => m02_axi_awready,  -- IN STD_LOGIC;
        m_axi_wdata    => m02_axi_wdata,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_wstrb    => m02_axi_wstrb,    -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_wlast    => m02_axi_wlast,    -- OUT STD_LOGIC;
        m_axi_wvalid   => m02_axi_wvalid,   -- OUT STD_LOGIC;
        m_axi_wready   => m02_axi_wready,   -- IN STD_LOGIC;
        m_axi_bresp    => m02_axi_bresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid   => m02_axi_bvalid,   -- IN STD_LOGIC;
        m_axi_bready   => m02_axi_bready,   -- OUT STD_LOGIC;
        m_axi_araddr   => m02_axi_araddr,   -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen    => m02_axi_arlen,    -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize   => m02_axi_arsize,   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst  => m02_axi_arburst,  -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
       
        m_axi_arvalid  => m02_axi_arvalid,  -- OUT STD_LOGIC;
        m_axi_arready  => m02_axi_arready,  -- IN STD_LOGIC;
        m_axi_rdata    => m02_axi_rdata,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_rresp    => m02_axi_rresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast    => m02_axi_rlast,    -- IN STD_LOGIC;
        m_axi_rvalid   => m02_axi_rvalid,   -- IN STD_LOGIC;
        m_axi_rready   => m02_axi_rready    --: OUT STD_LOGIC
    );
    
-------------------------------------------------------------------------------------------    
    -- Default outgoing signals for m03 bus
    m03_axi_araddri(63 downto 32) <= m03_shared(63 downto 32);  
    m03_axi_awaddri(63 downto 32) <= m03_shared(63 downto 32);
    m03_axi_awidi(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m03_axi_awsizei  <= "110";  -- size of 6 indicates 64 bytes in each beat (i.e. 512 bit wide bus) -- out std_logic_vector(2 downto 0);
    m03_axi_awbursti <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m03_axi_breadyi  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m03_axi_wstrbi  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m03_axi_aridi(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m03_axi_arsizei  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m03_axi_arbursti <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
   
    -- these have no ports on the axi register slice
    m03_axi_arlock <= "00";
    m03_axi_awlock <= "00";
    m03_axi_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m03_axi_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m03_axi_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m03_axi_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m03_axi_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m03_axi_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m03_axi_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m03_axi_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    -- Ignored incoming signals for m03 bus:
    -- m03_axi_bid; Since we only use 1 ID, we can ignore this. -- in std_logic_vector(0 downto 0);
    -- m03_axi_rid  -- in std_logic_vector(0 downto 0);
    
    
    -- Register slice for the m03 AXI interface
    m03_reg_slice : axi_reg_slice512_LLFFL
    port map (
        aclk    => ap_clk, --  IN STD_LOGIC;
        aresetn => ap_rst_n, --  IN STD_LOGIC;
        -- 
        s_axi_awaddr   => m03_axi_awaddri, -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen    => m03_axi_awleni,  -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize   => m03_axi_awsizei, -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst  => m03_axi_awbursti, -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awvalid  => m03_axi_awvalidi,  -- IN STD_LOGIC;
        s_axi_awready  => m03_axi_awreadyi,  -- OUT STD_LOGIC;
        s_axi_wdata    => m03_axi_wdatai,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb    => m03_axi_wstrbi,    -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast    => m03_axi_wlasti,    -- IN STD_LOGIC;
        s_axi_wvalid   => m03_axi_wvalidi,   -- IN STD_LOGIC;
        s_axi_wready   => m03_axi_wreadyi,   -- OUT STD_LOGIC;
        s_axi_bresp    => m03_axi_brespi,    --  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid   => m03_axi_bvalidi,   -- OUT STD_LOGIC;
        s_axi_bready   => m03_axi_breadyi,   -- IN STD_LOGIC;
        s_axi_araddr   => m03_axi_araddri,   -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen    => m03_axi_arleni,    -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize   => m03_axi_arsizei,   -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst  => m03_axi_arbursti,  -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid  => m03_axi_arvalidi,  -- IN STD_LOGIC;
        s_axi_arready  => m03_axi_arreadyi,  -- OUT STD_LOGIC;
        s_axi_rdata    => m03_axi_rdatai,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp    => m03_axi_rrespi,    -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast    => m03_axi_rlasti,    -- OUT STD_LOGIC;
        s_axi_rvalid   => m03_axi_rvalidi,   -- OUT STD_LOGIC;
        s_axi_rready   => m03_axi_rreadyi,   -- IN STD_LOGIC;
        --
        m_axi_awaddr   => m03_axi_awaddr, -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen    => m03_axi_awlen,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize   => m03_axi_awsize, -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst  => m03_axi_awburst, -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid  => m03_axi_awvalid,  -- OUT STD_LOGIC;
        m_axi_awready  => m03_axi_awready,  -- IN STD_LOGIC;
        m_axi_wdata    => m03_axi_wdata,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_wstrb    => m03_axi_wstrb,    -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_wlast    => m03_axi_wlast,    -- OUT STD_LOGIC;
        m_axi_wvalid   => m03_axi_wvalid,   -- OUT STD_LOGIC;
        m_axi_wready   => m03_axi_wready,   -- IN STD_LOGIC;
        m_axi_bresp    => m03_axi_bresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid   => m03_axi_bvalid,   -- IN STD_LOGIC;
        m_axi_bready   => m03_axi_bready,   -- OUT STD_LOGIC;
        m_axi_araddr   => m03_axi_araddr,   -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen    => m03_axi_arlen,    -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize   => m03_axi_arsize,   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst  => m03_axi_arburst,  -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
       
        m_axi_arvalid  => m03_axi_arvalid,  -- OUT STD_LOGIC;
        m_axi_arready  => m03_axi_arready,  -- IN STD_LOGIC;
        m_axi_rdata    => m03_axi_rdata,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_rresp    => m03_axi_rresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast    => m03_axi_rlast,    -- IN STD_LOGIC;
        m_axi_rvalid   => m03_axi_rvalid,   -- IN STD_LOGIC;
        m_axi_rready   => m03_axi_rready    --: OUT STD_LOGIC
    );
    
-------------------------------------------------------------------------------------------    
    -- Default outgoing signals for m04 bus
    m04_axi_araddri(63 downto 32) <= m04_shared(63 downto 32);  
    m04_axi_awaddri(63 downto 32) <= m04_shared(63 downto 32);
    m04_axi_awidi(0) <= '0';   -- We only use a single ID -- out std_logic_vector(0 downto 0);
    m04_axi_awsizei  <= "110";  -- size of 6 indicates 64 bytes in each beat (i.e. 512 bit wide bus) -- out std_logic_vector(2 downto 0);
    m04_axi_awbursti <= "01";   -- "01" indicates incrementing addresses for each beat in the burst.  -- out std_logic_vector(1 downto 0);
    m04_axi_breadyi  <= '1';  -- Always accept acknowledgement of write transactions. -- out std_logic;
    m04_axi_wstrbi  <= (others => '1');  -- We always write all bytes in the bus. --  out std_logic_vector(63 downto 0);
    m04_axi_aridi(0) <= '0';     -- ID are not used. -- out std_logic_vector(0 downto 0);
    m04_axi_arsizei  <= "110";   -- 6 = 64 bytes per beat = 512 bit wide bus. -- out std_logic_vector(2 downto 0);
    m04_axi_arbursti <= "01";    -- "01" = incrementing address for each beat in the burst. -- out std_logic_vector(1 downto 0);
   
    -- these have no ports on the axi register slice
    m04_axi_arlock <= "00";
    m04_axi_awlock <= "00";
    m04_axi_awcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m04_axi_awprot  <= "000";   -- Has no effect in Vitis environment. -- out std_logic_vector(2 downto 0);
    m04_axi_awqos   <= "0000";  -- Has no effect in vitis environment, -- out std_logic_vector(3 downto 0);
    m04_axi_awregion <= "0000"; -- Has no effect in Vitis environment. -- out std_logic_vector(3 downto 0);
    m04_axi_arcache <= "0011";  -- out std_logic_vector(3 downto 0); bufferable transaction. Default in Vitis environment.
    m04_axi_arprot  <= "000";   -- Has no effect in vitis environment; out std_logic_Vector(2 downto 0);
    m04_axi_arqos    <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    m04_axi_arregion <= "0000"; -- Has no effect in vitis environment; out std_logic_vector(3 downto 0);
    -- Ignored incoming signals for m04 bus:
    -- m04_axi_bid; Since we only use 1 ID, we can ignore this. -- in std_logic_vector(0 downto 0);
    -- m04_axi_rid  -- in std_logic_vector(0 downto 0);
    
    
    -- Register slice for the m04 AXI interface
    m04_reg_slice : axi_reg_slice512_LLFFL
    port map (
        aclk    => ap_clk, --  IN STD_LOGIC;
        aresetn => ap_rst_n, --  IN STD_LOGIC;
        -- 
        s_axi_awaddr   => m04_axi_awaddri, -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_awlen    => m04_axi_awleni,  -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize   => m04_axi_awsizei, -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst  => m04_axi_awbursti, -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awvalid  => m04_axi_awvalidi,  -- IN STD_LOGIC;
        s_axi_awready  => m04_axi_awreadyi,  -- OUT STD_LOGIC;
        s_axi_wdata    => m04_axi_wdatai,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb    => m04_axi_wstrbi,    -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast    => m04_axi_wlasti,    -- IN STD_LOGIC;
        s_axi_wvalid   => m04_axi_wvalidi,   -- IN STD_LOGIC;
        s_axi_wready   => m04_axi_wreadyi,   -- OUT STD_LOGIC;
        s_axi_bresp    => m04_axi_brespi,    --  OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid   => m04_axi_bvalidi,   -- OUT STD_LOGIC;
        s_axi_bready   => m04_axi_breadyi,   -- IN STD_LOGIC;
        s_axi_araddr   => m04_axi_araddri,   -- IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_arlen    => m04_axi_arleni,    -- IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize   => m04_axi_arsizei,   -- IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst  => m04_axi_arbursti,  -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arvalid  => m04_axi_arvalidi,  -- IN STD_LOGIC;
        s_axi_arready  => m04_axi_arreadyi,  -- OUT STD_LOGIC;
        s_axi_rdata    => m04_axi_rdatai,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp    => m04_axi_rrespi,    -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast    => m04_axi_rlasti,    -- OUT STD_LOGIC;
        s_axi_rvalid   => m04_axi_rvalidi,   -- OUT STD_LOGIC;
        s_axi_rready   => m04_axi_rreadyi,   -- IN STD_LOGIC;
        --
        m_axi_awaddr   => m04_axi_awaddr, -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_awlen    => m04_axi_awlen,  -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_awsize   => m04_axi_awsize, -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_awburst  => m04_axi_awburst, -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_awvalid  => m04_axi_awvalid,  -- OUT STD_LOGIC;
        m_axi_awready  => m04_axi_awready,  -- IN STD_LOGIC;
        m_axi_wdata    => m04_axi_wdata,    -- OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_wstrb    => m04_axi_wstrb,    -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_wlast    => m04_axi_wlast,    -- OUT STD_LOGIC;
        m_axi_wvalid   => m04_axi_wvalid,   -- OUT STD_LOGIC;
        m_axi_wready   => m04_axi_wready,   -- IN STD_LOGIC;
        m_axi_bresp    => m04_axi_bresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_bvalid   => m04_axi_bvalid,   -- IN STD_LOGIC;
        m_axi_bready   => m04_axi_bready,   -- OUT STD_LOGIC;
        m_axi_araddr   => m04_axi_araddr,   -- OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_arlen    => m04_axi_arlen,    -- OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_arsize   => m04_axi_arsize,   -- OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_arburst  => m04_axi_arburst,  -- OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
       
        m_axi_arvalid  => m04_axi_arvalid,  -- OUT STD_LOGIC;
        m_axi_arready  => m04_axi_arready,  -- IN STD_LOGIC;
        m_axi_rdata    => m04_axi_rdata,    -- IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_rresp    => m04_axi_rresp,    -- IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_rlast    => m04_axi_rlast,    -- IN STD_LOGIC;
        m_axi_rvalid   => m04_axi_rvalid,   -- IN STD_LOGIC;
        m_axi_rready   => m04_axi_rready    --: OUT STD_LOGIC
    );

    
END RTL;
