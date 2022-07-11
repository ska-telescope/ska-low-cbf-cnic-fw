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

1 x 100 GbE port is supported. In the case of 2 it is the furthest from the PCIe connector.

## Getting started on a developer machine
Clone this repository onto your machine.
cd into the dir then run the following to setup dependancies

git submodule update --init --recursive

You will be able to work locally with setup and then commit to repo for compilation and packages for others.

RunMe.sh will create project.

## CI Build Notes
Note CI configuration imported from


Version number is taken from the `version` file in the project root directory.
This file must contain three numbers separated by dots, e.g. `1.2.3`.
See also [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


# Changelog

