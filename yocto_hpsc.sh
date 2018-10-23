#!/bin/bash

pwd=${PWD}

# download the yocto poky git repository
git clone -b hpsc git@github.com:ISI-apex/poky.git
cd poky

# now add the meta-hpsc layer
git clone -b hpsc git@github.com:ISI-apex/meta-hpsc.git

# now add the meta-openembedded layer (for the mpich package)
git clone -b hpsc git@github.com:ISI-apex/meta-openembedded.git

# The following SRCREV_* env vars can be either a tag (e.g. 'hpsc-0.9'), a
# commit hash, or '${AUTOREV}' if the user wants the head of the hpsc branch
export SRCREV_atf='hpsc-0.9'
export SRCREV_linux_hpsc='hpsc-0.9'
export SRCREV_qemu_devicetrees='hpsc-0.9'
export SRCREV_qemu='hpsc-0.9'
export SRCREV_u_boot='hpsc-0.9'

# BB_ENV_EXTRAWHITE allows additional variables to pass through from
# the external environment into Bitbake's datastore
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE SRCREV_atf SRCREV_linux_hpsc SRCREV_qemu_devicetrees SRCREV_qemu SRCREV_u_boot"

# finally, create build directory and configure it
. ./oe-init-build-env build
bitbake-layers add-layer "${pwd}/poky/meta-hpsc/meta-xilinx-bsp"
bitbake-layers add-layer "${pwd}/poky/meta-hpsc/meta-xilinx-contrib"
bitbake-layers add-layer "${pwd}/poky/meta-openembedded/meta-oe"
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
