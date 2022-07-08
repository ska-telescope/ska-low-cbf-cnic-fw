# TCL File Generated by Component Editor 10.0
# Fri Nov 19 10:40:24 CET 2010
# DO NOT MODIFY


# +-----------------------------------
# | 
# | avs_common_reg_r_w "avs_common_reg_r_w" v1.1
# | null 2010.11.19.10:40:24
# | Large PIO register
# | 
# | $UNB/Firmware/modules/common/src/vhdl/avs_common_reg_r_w.vhd
# | 
# |    ./avs_common_reg_r_w.vhd syn, sim
# |    ./common_pkg.vhd syn, sim
# |    ./common_mem_pkg.vhd syn, sim
# |    ./common_pipeline.vhd syn, sim
# |    ./common_reg_r_w.vhd syn, sim
# | 
# +-----------------------------------

# +-----------------------------------
# | request TCL package from ACDS 10.0
# | 
package require -exact sopc 10.0
# | 
# +-----------------------------------

# +-----------------------------------
# | module avs_common_reg_r_w
# | 
set_module_property DESCRIPTION "Large PIO register"
set_module_property NAME avs_common_reg_r_w
set_module_property VERSION 1.1
set_module_property INTERNAL false
set_module_property GROUP Uniboard
set_module_property DISPLAY_NAME avs_common_reg_r_w
set_module_property TOP_LEVEL_HDL_FILE avs_common_reg_r_w.vhd
set_module_property TOP_LEVEL_HDL_MODULE avs_common_reg_r_w
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property ANALYZE_HDL TRUE
# | 
# +-----------------------------------

# +-----------------------------------
# | files
# | 
add_file avs_common_reg_r_w.vhd {SYNTHESIS SIMULATION}
add_file common_pkg.vhd {SYNTHESIS SIMULATION}
add_file common_mem_pkg.vhd {SYNTHESIS SIMULATION}
add_file common_pipeline.vhd {SYNTHESIS SIMULATION}
add_file common_reg_r_w.vhd {SYNTHESIS SIMULATION}
# | 
# +-----------------------------------

# +-----------------------------------
# | parameters
# | 
add_parameter g_latency NATURAL 1
set_parameter_property g_latency DEFAULT_VALUE 1
set_parameter_property g_latency DISPLAY_NAME g_latency
set_parameter_property g_latency TYPE NATURAL
set_parameter_property g_latency UNITS None
set_parameter_property g_latency ALLOWED_RANGES 0:2147483647
set_parameter_property g_latency AFFECTS_GENERATION false
set_parameter_property g_latency HDL_PARAMETER true
add_parameter g_adr_w NATURAL 5
set_parameter_property g_adr_w DEFAULT_VALUE 5
set_parameter_property g_adr_w DISPLAY_NAME g_adr_w
set_parameter_property g_adr_w TYPE NATURAL
set_parameter_property g_adr_w UNITS None
set_parameter_property g_adr_w ALLOWED_RANGES 0:2147483647
set_parameter_property g_adr_w AFFECTS_GENERATION false
set_parameter_property g_adr_w HDL_PARAMETER true
add_parameter g_dat_w NATURAL 32
set_parameter_property g_dat_w DEFAULT_VALUE 32
set_parameter_property g_dat_w DISPLAY_NAME g_dat_w
set_parameter_property g_dat_w TYPE NATURAL
set_parameter_property g_dat_w UNITS None
set_parameter_property g_dat_w ALLOWED_RANGES 0:2147483647
set_parameter_property g_dat_w AFFECTS_GENERATION false
set_parameter_property g_dat_w HDL_PARAMETER true
add_parameter g_nof_dat NATURAL 32
set_parameter_property g_nof_dat DEFAULT_VALUE 32
set_parameter_property g_nof_dat DISPLAY_NAME g_nof_dat
set_parameter_property g_nof_dat TYPE NATURAL
set_parameter_property g_nof_dat UNITS None
set_parameter_property g_nof_dat ALLOWED_RANGES 0:2147483647
set_parameter_property g_nof_dat AFFECTS_GENERATION false
set_parameter_property g_nof_dat HDL_PARAMETER true
add_parameter g_init_sl STD_LOGIC 0
set_parameter_property g_init_sl DEFAULT_VALUE 0
set_parameter_property g_init_sl DISPLAY_NAME g_init_sl
set_parameter_property g_init_sl TYPE STD_LOGIC
set_parameter_property g_init_sl UNITS None
set_parameter_property g_init_sl ALLOWED_RANGES 0:1
set_parameter_property g_init_sl AFFECTS_GENERATION false
set_parameter_property g_init_sl HDL_PARAMETER true
add_parameter g_init_reg STD_LOGIC_VECTOR 0
set_parameter_property g_init_reg DEFAULT_VALUE 0
set_parameter_property g_init_reg DISPLAY_NAME g_init_reg
set_parameter_property g_init_reg TYPE STD_LOGIC_VECTOR
set_parameter_property g_init_reg UNITS None
set_parameter_property g_init_reg ALLOWED_RANGES 0:1090748135619415929462984244733782862448264161996232692431832786189721331849119295216264234525201987223957291796157025273109870820177184063610979765077554799078906298842192989538609825228048205159696851613591638196771886542609324560121290553901886301017900252535799917200010079600026535836800905297805880952350501630195475653911005312364560014847426035293551245843928918752768696279344088055617515694349945406677825140814900616105920256438504578013326493565836047242407382442812245131517757519164899226365743722432277368075027627883045206501792761700945699168497257879683851737049996900961120515655050115561271491492515342105748966629547032786321505730828430221664970324396138635251626409516168005427623435996308921691446181187406395310665404885739434832877428167407495370993511868756359970390117021823616749458620969857006263612082706715408157066575137281027022310927564910276759160520878304632411049364568754920967322982459184763427383790272448438018526977764941072715611580434690827459339991961414242741410599117426060556483763756314527611362658628383368621157993638020878537675545336789915694234433955666315070087213535470255670312004130725495834508357439653828936077080978550578912967907352780054935621561090795845172954115972927479877527738560008204118558930004777748727761853813510493840581861598652211605960308356405941821189714037868726219481498727603653616298856174822413033485438785324024751419417183012281078209729303537372804574372095228703622776363945290869806258422355148507571039619387449629866808188769662815778153079393179093143648340761738581819563002994422790754955061288818308430079648693232179158765918035565216157115402992120276155607873107937477466841528362987708699450152031231862594203085693838944657061346236704234026821102958954951197087076546186622796294536451620756509351018906023773821539532776208676978589731966330308893304665169436185078350641568336944530051437491311298834367265238595404904273455928723949525227184617404367854754610474377019768025576605881038077270707717942221977090385438585844095492116099852538903974655703943973086090930596963360767529964938414598185705963754561497355827813623833288906309004288017321424808663962671333528009232758350873059614118723781422101460198615747386855096896089189180441339558524822867541113212638793675567650340362970031930023397828465318547238244232028015189689660418822976000815437610652254270163595650875433851147123214227266605403581781469090806576468950587661997186505665475715792895
set_parameter_property g_init_reg AFFECTS_GENERATION false
set_parameter_property g_init_reg HDL_PARAMETER true
# | 
# +-----------------------------------

# +-----------------------------------
# | display items
# | 
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point system
# | 
add_interface system clock end

set_interface_property system ENABLED true

add_interface_port system csi_system_clk clk Input 1
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point system_reset
# | 
add_interface system_reset reset end
set_interface_property system_reset associatedClock system
set_interface_property system_reset synchronousEdges DEASSERT

set_interface_property system_reset ASSOCIATED_CLOCK system
set_interface_property system_reset ENABLED true

add_interface_port system_reset csi_system_reset reset Input 1
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point register
# | 
add_interface register avalon end
set_interface_property register addressAlignment DYNAMIC
set_interface_property register associatedClock system
set_interface_property register associatedReset system_reset
set_interface_property register burstOnBurstBoundariesOnly false
set_interface_property register explicitAddressSpan 0
set_interface_property register holdTime 0
set_interface_property register isMemoryDevice false
set_interface_property register isNonVolatileStorage false
set_interface_property register linewrapBursts false
set_interface_property register maximumPendingReadTransactions 0
set_interface_property register printableDevice false
set_interface_property register readLatency 0
set_interface_property register readWaitTime 1
set_interface_property register setupTime 0
set_interface_property register timingUnits Cycles
set_interface_property register writeWaitTime 0

set_interface_property register ASSOCIATED_CLOCK system
set_interface_property register ENABLED true

add_interface_port register avs_register_address address Input g_adr_w
add_interface_port register avs_register_write write Input 1
add_interface_port register avs_register_writedata writedata Input g_dat_w
add_interface_port register avs_register_read read Input 1
add_interface_port register avs_register_readdata readdata Output g_dat_w
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point out_reg
# | 
add_interface out_reg conduit end

set_interface_property out_reg ENABLED true

add_interface_port out_reg coe_out_reg_export export Output g_dat_w*g_nof_dat
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point in_reg
# | 
add_interface in_reg conduit end

set_interface_property in_reg ENABLED true

add_interface_port in_reg coe_in_reg_export export Input g_dat_w*g_nof_dat
# | 
# +-----------------------------------
