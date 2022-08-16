#!/bin/bash
#  Distributed under the terms of the CSIRO Open Source Software Licence Agreement
#  See the file LICENSE for more info.


## This script creates a Vivado Vitis project,
## It synthesizes and produces an output bitfile to be programmed
## to an Alveo from the source in this git repository

ALLOWED_ALVEO=(u50lv u55) #ALVEO is either U50 or U55 as of Sept 2021
PERSONALITIES=(cnic)
XILINX_PATH=/tools/Xilinx
VIVADO_VERSION_IN_USE=2021.2

# use ptp submodule (we assume it's initialised)
PTP_IP="${PWD}/pub-timeslave/hw/cores"


ShowHelp()
{
    echo "Usage: ${0##*/} [-h] <device> <personality> <build info> [clean/kernel]"
    echo ""
    echo "e.g. ${0##*/} u55 cnic \"This is the build string\""
    echo ""
    echo "-h    Print this help then exit"
    echo "device: ${ALLOWED_ALVEO[*]}"
    echo "personality: ${PERSONALITIES[*]}"
    echo "build info: free text (use quotes)"
    echo "clean: (optional) clean the build directory"
    echo "OR"
    echo "kernel: (optional) stop after kernel project generation"
}

while getopts ":h" option; do
    case $option in
        h)
            ShowHelp
            exit;;
        ?)
            echo "Unknown option -${OPTARG}"
            echo "Use -h for help"
            exit 1;;
    esac
done

if [ "$#" -lt 3 ]; then
    echo "Not enough parameters"
    ShowHelp
    exit 1
fi

##Select Alveo Card Type
TARGET_ALVEO=$(echo $1 | tr "[:upper:]" "[:lower:]")
if [[ " ${ALLOWED_ALVEO[*]} " =~ " $TARGET_ALVEO " ]]; then
    echo -e "Device: $TARGET_ALVEO"
else
    echo -e "Invalid Device: $TARGET_ALVEO"
    echo -e "Valid devices are: ${ALLOWED_ALVEO[*]}"
    exit 2
fi
# assume U55 is the default otherwise set U50LV
export XPFM=/opt/xilinx/platforms/xilinx_u55c_gen3x16_xdma_2_202110_1/xilinx_u55c_gen3x16_xdma_2_202110_1.xpfm
export CNIC_BOARD=xilinx.com:au55c:part0:1.0
export CNIC_DEVICE=xcu55c-fsvh2892-2L-e
export CNIC_TARGET=u55c
export VITIS_TARGET=u55
# if [ $TARGET_ALVEO = "u50" ]; then
#     export XPFM=/opt/xilinx/platforms/xilinx_u50_gen3x4_xdma_2_202010_1/xilinx_u50_gen3x4_xdma_2_202010_1.xpfm
#     export CNIC_BOARD=xilinx.com:au50:part0:1.0
#     export CNIC_DEVICE=xcu50-fsvh2104-2-e
#     export CNIC_TARGET=u50
#     export VITIS_TARGET=u50
# fi
if [ $TARGET_ALVEO = "u50lv" ]; then
    export XPFM=/opt/xilinx/platforms/xilinx_u50lv_gen3x4_xdma_2_202010_1/xilinx_u50lv_gen3x4_xdma_2_202010_1.xpfm
    export CNIC_BOARD=xilinx.com:au50lv:part0:1.2
    export CNIC_DEVICE=xcu50-fsvh2104-2lv-e
    export CNIC_TARGET=u50lv
    export VITIS_TARGET=u50
fi

export TARGET_ALVEO=$TARGET_ALVEO

if [ ! -f "$XPFM" ]; then
	echo "Error: can't find XPFM file $XPFM"
    exit 5
fi

PERSONALITY=$(echo $2 | tr "[:upper:]" "[:lower:]")
if [[ " ${PERSONALITIES[*]} " =~ " $PERSONALITY " ]]; then
    echo -e "Personality: $PERSONALITY"

else
    echo -e "Invalid Personality: $PERSONALITY"
    echo -e "Valid personalities: ${PERSONALITIES[*]}"
    exit 3
fi

if [ "$3" = "" ]; then
    echo -e "Please supply a buildinfo string that will be associated with the .xcbin and .ccfg in the output files directory"
    echo -e './RunMe.sh u50 cnic "This is the build string"'
    echo -e ' Optionally supply the parameter "clean" to clean the output and build directories'
    echo -e './RunMe.sh u50 cnic "This is the build string" clean'
    exit 4
fi
BUILDINFO=$3
echo "Build Info: $BUILDINFO"

export GITREPO=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
export RADIOHDL=$GITREPO

# $SVN is required for the RADIOHDL scripts
export SVN=$GITREPO
echo -e "\nBase Git directory: $GITREPO"

##Clean the build directory if we pass in a command line parameter called clean
if [ "$4" = "clean" ]; then
    echo -e "Deleting Build Directory $GITREPO/build/alveo"
    echo -e "Deleting output Directory $GITREPO/output"
    rm -rf $GITREPO/build/alveo
    rm -rf $GITREPO/output
    echo "Deleting existing ARGS $GITREPO/build/ARGS"
    rm -rf $GITREPO/build/ARGS
fi

if [ -z "`which ccze`" ]; then
    echo -e "Note: ccze not found, running in monochrome mode"
    COLOUR="cat"
else
    COLOUR="ccze -A"
fi

##Check that the build directories exists
if [ ! -d "$GITREPO/build/$PERSONALITY" ]; then
    echo -e "Creating directory $GITREPO/build/$PERSONALITY"
    mkdir -p $GITREPO/build/$PERSONALITY
fi

##Check that the output directory exists
if [ ! -d "$GITREPO/output" ]; then
    echo -e "Creating directory $GITREPO/output"
    mkdir -p $GITREPO/output
fi

LOGFILE="$GITREPO/output/$PERSONALITY.log"
echo Logging to $LOGFILE
rm -f $LOGFILE
TEE_LOG="tee -a $LOGFILE"

if [ -n "$VIVADO_STACK" ]; then
    STACK_ARG="-stack $VIVADO_STACK"
    echo Using "$STACK_ARG" for vivado
else
    STACK_ARG=""
fi

##Create the New Project for Vitis from the VHDL Source Files
echo -e "Creating the New Project for $PERSONALITY from the VHDL Source Files\n\n"
cd $GITREPO/build/$PERSONALITY

source $GITREPO/tools/bin/setup_radiohdl.sh
echo
echo "<><><><><><><><><><><><><>  Automatic Register Generation System (ARGS)  <><><><><><><><><><><><><>" | $TEE_LOG
echo

if [ -n "$XILINX_REFERENCE_DESIGN" ]; then
    echo "XILINX_REFERENCE_DESIGN: Using Existing ARGS FILES"
    echo
else
    echo "SKA Design: Re-generating ARGS from configuration YAML files in $GITREPO/libraries"
    source $GITREPO/tools/bin/setup_radiohdl.sh 
    echo
    python3 $GITREPO/tools/radiohdl/base/vivado_config.py -l $PERSONALITY -a | $TEE_LOG | $COLOUR
fi

# If you wish to just generate the .CCFG , issue the following command
#python3 $GITREPO/tools/args/gen_c_config.py -f $PERSONALITY
echo "Sourcing ${XILINX_PATH}/Vitis/$VIVADO_VERSION_IN_USE/settings64.sh"
source ${XILINX_PATH}/Vitis/$VIVADO_VERSION_IN_USE/settings64.sh | $TEE_LOG | $COLOUR

echo
echo "<><><><><><><><><><><><><>  Vivado Create Project <><><><><><><><><><><><><>" | $TEE_LOG
echo
echo "Personality for project is " $PERSONALITY | $TEE_LOG
echo "Target Device for project is " $TARGET_ALVEO | $TEE_LOG
echo "Vivado Version for project is " $VIVADO_VERSION_IN_USE | $TEE_LOG
echo
source ${XILINX_PATH}/Vitis/$VIVADO_VERSION_IN_USE/settings64.sh


vivado $STACK_ARG -mode batch -source $GITREPO/designs/$PERSONALITY/create_project.tcl -tclargs $PERSONALITY | $TEE_LOG | $COLOUR



##Find latest Vivado project directorys
PRJ_DIR=$GITREPO/build/$PERSONALITY/
cd $PRJ_DIR

NEWEST_DIR=`ls -rd *_build_* |head -n1 | tr -d '\n'`
if [ -z $NEWEST_DIR ]; then
    echo "FAIL: Could not find the latest ${PERSONALITY}_build_ directory"
    exit 1
fi

PRJ_DIR+=$NEWEST_DIR
echo ""
echo "Newest Vivado Project Directory=" $PRJ_DIR | $TEE_LOG

#Copy ARG generated .CCFG file to the project directory
cp $GITREPO/build/ARGS/$PERSONALITY/$PERSONALITY.ccfg $PRJ_DIR/

cd $PRJ_DIR
echo
TB_REGISTERS_INPUT=$GITREPO/designs/$PERSONALITY/src/tb/registers.txt
if [ -f "$TB_REGISTERS_INPUT" ]; then
    TB_REGISTERS_OUTPUT=$GITREPO/designs/$PERSONALITY/src/tb/registers_tb.txt
    echo "Generating $TB_REGISTERS_OUTPUT for the testbench from $TB_REGISTERS_INPUT" | $TEE_LOG
    python3 $GITREPO/tools/args/gen_tb_config.py -c $PRJ_DIR/${PERSONALITY}.ccfg -i "$TB_REGISTERS_INPUT" -o "$TB_REGISTERS_OUTPUT" | $TEE_LOG
    cp $GITREPO/designs/$PERSONALITY/src/tb/registers*.txt .
else
    echo "Skipping testbench generation, $TB_REGISTERS_INPUT does not exist"
fi

echo $BUILDINFO >> $PRJ_DIR/buildinfo.txt

if [ "$4" = "kernel" ]; then
    exit 0
fi

## Package up the Vitis Kernel and Generate an XO file

echo
echo "<><><><><><><><><><><><><>  Vivado PACKAGE KERNEL  <><><><><><><><><><><><><>" | $TEE_LOG
echo

vivado $PRJ_DIR/$PERSONALITY.xpr $STACK_ARG -mode batch -source $GITREPO/designs/$PERSONALITY/src/scripts/package_kernel.tcl | $TEE_LOG | $COLOUR
echo
echo "<><><><><><><><><><><><><>  Vivado Generate XO File <><><><><><><><><><><><><>" | $TEE_LOG
echo

vivado $PRJ_DIR/$PERSONALITY.xpr $STACK_ARG -mode batch -source $GITREPO/designs/$PERSONALITY/src/scripts/gen_xo.tcl -tclargs ./$PERSONALITY.xo $PERSONALITY $GITREPO/designs/$PERSONALITY/src/scripts/$VITIS_TARGET | $TEE_LOG | $COLOUR



##Run Vitis
cd $PRJ_DIR

source /opt/xilinx/xrt/setup.sh | $TEE_LOG | $COLOUR
echo
echo
echo "<><><><><><><><><><><><><>  Running Vitis v++ <><><><><><><><><><><><><>" | $TEE_LOG
echo

v++ --optimize 0 --report_level 2 --save-temps --config "$GITREPO/designs/$PERSONALITY/src/scripts/$VITIS_TARGET/connectivity.ini" -l -t hw -o $PERSONALITY.xclbin --user_ip_repo_paths $PTP_IP -f $XPFM $PRJ_DIR/$PERSONALITY.xo | $TEE_LOG | $COLOUR

cp $LOGFILE $PRJ_DIR/

cd $GITREPO/build/ARGS/py/$PERSONALITY/
NEWEST_FPGAMAP=`ls -rd fpgamap_* |head -n1 | tr -d '\n'`
if [ -z $NEWEST_FPGAMAP ]; then
    echo "FAIL: Could not find the latest fpgamap.py file "
    exit 1
fi



if [ -f "$PRJ_DIR/$PERSONALITY.xclbin" ]; then
    echo "xclbin file was created, copying build to the $GITREPO/output directory."

    cd $PRJ_DIR
    cd ..
    rm latest
    ln -s $PRJ_DIR latest

    cd $GITREPO/output
    mkdir $NEWEST_DIR
    cd $NEWEST_DIR

    cp "$PRJ_DIR/$PERSONALITY.log" .
    cp $PRJ_DIR/$PERSONALITY.xclbin .
    cp $PRJ_DIR/$PERSONALITY.ltx .
    cp $PRJ_DIR/buildinfo.txt .
    cp $GITREPO/build/ARGS/py/$PERSONALITY/$NEWEST_FPGAMAP .
    cp $GITREPO/build/ARGS/$PERSONALITY/$PERSONALITY.ccfg .
    mkdir logs
    cd logs
    cp $PRJ_DIR/v++_$PERSONALITY.log .
    cp $PRJ_DIR/_x/logs/link/vivado.log .
    cp $PRJ_DIR/_x/logs/link/v++.log .
    cd ..
    cd $GITREPO/output
    rm latest
    ln -s $NEWEST_DIR latest
    scp -r $NEWEST_DIR $USERMACHINE:~/project/ska-low-cbf-firmware/output
    echo
    echo
    echo "Please navigate to the directory $PRJ_DIR for the output .xclbin files and log files including $PERSONALITY.log "
    echo
else
    echo "[ERROR] xclbin file was NOT created"
    exit 2
fi
