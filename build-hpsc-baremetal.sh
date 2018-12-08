#!/bin/bash
#
# Fetch and/or build sources that require the baremetal toolchain
#

# The following toolchain path may need to be updated:
GCC_ARM_NONE_EABI_BINDIR=${PWD}/../gcc-arm-none-eabi-7-2018-q2-update/bin

BM_GIT_CHECKOUT="hpsc"
UBOOT_R52_GIT_CHECKOUT="hpsc"

BUILD_JOBS=4

# Check that toolchain is on PATH
function check_toolchain()
{
    which arm-none-eabi-gcc > /dev/null 2>&1
}

# Clone repository if not already done, always pull
function isi_github_pull()
{
    local repo=$1
    local dir=$2
    # Don't ask for credentials if requests are bad
    export GIT_TERMINAL_PROMPT=0 # for git > 2.3
    export GIT_ASKPASS=/bin/echo
    echo "Pulling repository=$repo"
    if [ ! -d "$dir" ]; then
        git clone "https://github.com/ISI-apex/$repo.git" "$dir" || return $?
    fi
    cd "$dir"
    git pull
    RC=$?
    cd - > /dev/null
    return $RC
}

# Script options
IS_ONLINE=1
IS_BUILD=1
case "$1" in
    "" | "all")
        ;;
    "fetchall")
        IS_BUILD=0
        ;;
    "buildall")
        IS_ONLINE=0
        ;;
    *)
        echo "Usage: $0 [ACTION]"
        echo "  where ACTION is one of:"
        echo "    all: (default) download sources and compile"
        echo "    fetchall: download sources"
        echo "    buildall: compile pre-downloaded sources"
        exit 1
        ;;
esac

if [ $IS_BUILD -ne 0 ]; then
    PATH=${PATH}:${GCC_ARM_NONE_EABI_BINDIR}
    if ! check_toolchain; then
        echo "Error: update GCC_ARM_NONE_EABI_BINDIR or add toolchain bin directory to PATH"
        exit 1
    fi
fi

## hpsc-baremetal
DIR="hpsc-baremetal"
if [ $IS_ONLINE -ne 0 ]; then
    isi_github_pull hpsc-baremetal "$DIR" || exit $?
fi
if [ $IS_BUILD -ne 0 ]; then
    if [ ! -d "$DIR" ]; then
        echo "$DIR: Error: must fetch sources before build"
        exit 1
    fi

    cd "$DIR" || exit $?
    echo "$DIR: checkout $BM_GIT_CHECKOUT..."
    git checkout "$BM_GIT_CHECKOUT" || exit $?
    echo "$DIR: clean..."
    make clean
    echo "$DIR: build..."
    make all -j${BUILD_JOBS}
    RC=$?
    if [ $RC -eq 0 ]; then
        echo "$DIR: build successful"
    else
        echo "$DIR: Error: build failed with exit code: $RC"
        exit $RC
    fi
    cd - > /dev/null
fi

## u-boot-r52
DIR="u-boot-r52"
if [ $IS_ONLINE -ne 0 ]; then
    isi_github_pull u-boot "$DIR" || exit $?
fi
if [ $IS_BUILD -ne 0 ]; then
    if [ ! -d "$DIR" ]; then
        echo "$DIR: Error: must fetch sources before build"
        exit 1
    fi
    cd "$DIR" || exit $?
    echo "$DIR: checkout $UBOOT_R52_GIT_CHECKOUT..."
    git checkout "$UBOOT_R52_GIT_CHECKOUT" || exit $?
    echo "$DIR: clean..."
    make clean
    echo "$DIR: build..."
    make hpsc_rtps_r52_defconfig
    make -j${BUILD_JOBS} CROSS_COMPILE=arm-none-eabi- CONFIG_LD_GCC=y
    RC=$?
    if [ $RC -eq 0 ]; then
        echo "$DIR: build successful"
    else
        echo "$DIR: Error: build failed with exit code: $RC"
        exit $RC
    fi
    cd - > /dev/null
fi
