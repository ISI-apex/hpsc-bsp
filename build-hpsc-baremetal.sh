#!/bin/bash

# The following toolchain path needs to be updated:
BAREMETAL_TOOLCHAIN_DIR=/path/to/gcc-arm-none-eabi-toolchain

# Add the toolchain to the path
PATH=${PATH}:${BAREMETAL_TOOLCHAIN_DIR}/bin

# Download the hpsc-baremetal git repository and build it
git clone -b hpsc https://github.com/ISI-apex/hpsc-baremetal.git
cd hpsc-baremetal
make all
