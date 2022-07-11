#!/bin/bash

apt update
git clone --depth 1 https://github.com/Xilinx/XRT.git
cd XRT
./src/runtime_src/tools/scripts/xrtdeps.sh -docker
cd build
# -opt skips building the Debug version
./build.sh -opt
cp -r Release /build
