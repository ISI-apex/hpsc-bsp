#!/bin/bash

# The following toolchain path needs to be updated:
BAREMETAL_TOOLCHAIN_DIR=/path/to/gcc-arm-none-eabi-toolchain

BAREMETAL_BRANCH_TAG="hpsc"
UBOOT_R52_BRANCH_TAG="hpsc"

# Check that toolchain is on PATH
function check_toolchain()
{
    which arm-none-eabi-gcc > /dev/null 2>&1
    echo $?
}

# Checkout repository if not already done, always pull branch/tag
# $1 = repository name, $2 = branch/tag name
function isi_github_pull()
{
    local repo=$1
    local brtag=$2
    local dir=$3
    echo "Pulling repository=$repo, branch/tag=$brtag"
    if [ ! -d "$dir" ]; then
        git clone "https://github.com/ISI-apex/$repo.git" "$dir"
    fi
    cd "$dir"
    # `git pull origin "$brtag"` is causing conflicts...?
    git checkout "$brtag"
    git pull
    cd ..
}

if [ $(check_toolchain) -ne 0 ]; then
    PATH=${PATH}:${BAREMETAL_TOOLCHAIN_DIR}/bin
    if [ $(check_toolchain) -ne 0 ]; then
        echo "Error: update BAREMETAL_TOOLCHAIN_DIR or add toolchain bin directory to PATH"
        exit 1
    fi
fi


## hpsc-baremetal
isi_github_pull hpsc-baremetal "$BAREMETAL_BRANCH_TAG" hpsc-baremetal
cd hpsc-baremetal
echo "hpsc-baremetal: cleaning and compiling"
# clean in case there are changes to the Makefile variables
make clean all
RC=$?
if [ $RC -eq 0 ]; then
    echo "hpsc-baremetal: build successful"
else
    echo "hpsc-baremetal: Error: build failed with exit code: $RC"
    exit $RC
fi
cd ..

## u-boot-r52
isi_github_pull u-boot "$UBOOT_R52_BRANCH_TAG" u-boot-r52
cd u-boot-r52
make hpsc_rtps_r52_defconfig
make -j4 CROSS_COMPILE=arm-none-eabi- CONFIG_LD_GCC=y
RC=$?
if [ $RC -eq 0 ]; then
    echo "u-boot-r52: build successful"
else
    echo "u-boot-r52: Error: build failed with exit code: $RC"
    exit $RC
fi
cd ..
