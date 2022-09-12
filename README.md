C-NIC firmware

## Cloning the repo


To clone the repo including populatating submodule repo's:

    git clone --recurse-submodules --remote-submodules  

for a branch

    git clone --recurse-submodules --remote-submodules -b <branch_name> 


You can also issue the following to checkout and populate the submodule repo's

    git submodule init
    git submodule update

## Build Tools

Vivado/Vitis 2021.2

## Targets

Target Devices - ALVEO U50LV, ALVEO U55C

1 x 100 GbE port is supported for capture and playout. In the case of the U55C it is the furthest from the PCIe connector.


## Getting started on a developer machine
Clone this repository onto your machine.
cd into the dir then run the following to setup dependancies

git submodule update --init --recursive

You will be able to work locally with setup and then commit to repo for compilation and packages for others.

RunMe.sh will create project.

## CI Build Notes
Note CI configuration imported from


Version number is taken from the `release` file in the project root directory.
This file must contain three numbers separated by dots, e.g. `1.2.3`.
See also [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Command sequence to update for a patch version example:
* make bump-patch-release
* make git-create-tag
* make git-push-tag

Reference this;
https://developer.skao.int/en/latest/tools/software-package-release-procedure.html#release-management

## Changelog
* 0.1.2 - 
    * CNIC TX will now pre-fill the TX FIFO after reset has been released and be ready within 1us for transmit.
    * CNIC TX timer has been updated to remove burst behaviour during initial packet play out.
    * Personality register configured to ASCII value of CNIC.
    * U55C 
        * Second 100GbE port enabled with timeslave to allow timing of packets through network switches.
        * PTP for time stamping or scheduling can be sourced from either 100GbE port.

* 0.1.1 - 
    * Initial release
