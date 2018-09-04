#!/bin/bash

pwd=${PWD}

# cd into poky directory, create build directory and configure it
cd poky
. ./oe-init-build-env build
bitbake-layers add-layer "${pwd}/poky/meta-hpsc/meta-xilinx-bsp"
bitbake-layers add-layer "${pwd}/poky/meta-hpsc/meta-xilinx-contrib"
cd conf
printf "\nMACHINE = \"zcu102-zynqmp\"\n" >> local.conf

# One or more of the following options should be enabled to start the download and/or build

# Option #1- run bitbake to download source code to "downloads" folder and then stop
#bitbake core-image-minimal -c fetchall

# Option #2- run bitbake to download source code, then create all of the Yocto-generated files including kernel image and rootfs
bitbake core-image-minimal

# Option #3- run bitbake to download source code, then build cross-compiler toolchain installer
#bitbake core-image-minimal -c populate_sdk


# after the previous builds have completed, run the task dependency explorer
#bitbake -u taskexp -g core-image-minimal
