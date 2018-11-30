#!/bin/bash

# The following toolchain path needs to be updated:
BAREMETAL_TOOLCHAIN_DIR=/path/to/gcc-arm-none-eabi-toolchain

# Check that toolchain is on PATH
function check_toolchain()
{
    which arm-none-eabi-gcc > /dev/null 2>&1
    echo $?
}

if [ $(check_toolchain) -ne 0 ]; then
    PATH=${PATH}:${BAREMETAL_TOOLCHAIN_DIR}/bin
    if [ $(check_toolchain) -ne 0 ]; then
        echo "Error: update BAREMETAL_TOOLCHAIN_DIR or add toolchain bin directory to PATH"
        exit 1
    fi
fi

if [ -d hpsc-baremetal ]; then
    # Better to let the user (or a smarter script) actually delete things
    echo "Error: 'hpsc-baremetal' already exists - please delete and retry"
    exit 1
fi

# Download the hpsc-baremetal git repository and build it
git clone -b hpsc https://github.com/ISI-apex/hpsc-baremetal.git
cd hpsc-baremetal
make all
