#!/bin/bash
#
# Fetch and/or build sources that require the other toolchains
#

BUILD_JOBS=4

. ./build-common.sh || exit $?

# Check that baremetal toolchain is on PATH
function check_bm_toolchain()
{
    export PATH=${PATH}:${GCC_ARM_NONE_EABI_BINDIR}
    which arm-none-eabi-gcc > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: update GCC_ARM_NONE_EABI_BINDIR or add toolchain bin directory to PATH"
        exit 1
    fi
}

# Check that poky toolchain is on PATH
function check_poky_toolchain()
{
    export PATH=${PATH}:${POKY_SDK_AARCH64_PATH}
    export SYSROOT="$POKY_SDK_AARCH64_SYSROOT"
    which aarch64-poky-linux-gcc > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: update POKY_SDK_AARCH64_PATH or add toolchain to PATH"
        exit 1
    fi
    if [ ! -d "${POKY_SDK_AARCH64_SYSROOT}" ]; then
        echo "Error: POKY_SDK_AARCH64_SYSROOT not found: $POKY_SDK_AARCH64_SYSROOT"
        exit 1
    fi
}

function bm_build()
{
    make clean && \
    make all -j${BUILD_JOBS}
}

function uboot_r52_build()
{
    make clean && \
    make hpsc_rtps_r52_defconfig && \
    make -j${BUILD_JOBS} CROSS_COMPILE=arm-none-eabi- CONFIG_LD_GCC=y
}

function qemu_build()
{
    rm -rf BUILD && \
    mkdir BUILD && \
    cd BUILD && \
    ../configure --target-list="aarch64-softmmu" --enable-fdt --disable-kvm \
                 --disable-xen && \
    make -j${BUILD_JOBS} && \
    cd ..
}

function qemu_dt_build()
{
    make clean && \
    make -j${BUILD_JOBS}
}

function utils_build()
{
    # host utilities
    echo "hpsc-utils: build host sources..."
    cd host && \
    make clean && \
    make -j${BUILD_JOBS} && \
    cd .. || return $?
    # linux utilities
    echo "hpsc-utils: build linux sources..."
    cd linux && \
    make clean && \
    make -j${BUILD_JOBS} && \
    cd .. || return $?
}

PREBUILD_FNS=(check_bm_toolchain
              check_poky_toolchain)

# Indexes of these arrays must align to each other
BUILD_REPOS=("https://github.com/ISI-apex/hpsc-baremetal.git"
             "https://github.com/ISI-apex/u-boot.git"
             "https://github.com/ISI-apex/qemu.git"
             "https://github.com/ISI-apex/qemu-devicetrees.git"
             "https://github.com/ISI-apex/hpsc-utils.git")
BUILD_DIRS=("hpsc-baremetal"
            "u-boot-r52"
            "qemu"
            "qemu-devicetrees"
            "hpsc-utils")
BUILD_CHECKOUTS=("$GIT_CHECKOUT_BM"
                 "$GIT_CHECKOUT_UBOOT_R52"
                 "$GIT_CHECKOUT_QEMU"
                 "$GIT_CHECKOUT_QEMU_DT"
                 "$GIT_CHECKOUT_HPSC_UTILS")
BUILD_FNS=(bm_build
           uboot_r52_build
           qemu_build
           qemu_dt_build
           utils_build)

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

if [ $IS_ONLINE -ne 0 ]; then
    echo "Fetching sources..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        git_clone_pull "${BUILD_REPOS[$i]}" "${BUILD_DIRS[$i]}" || exit $?
    done
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Running pre-build checks..."
    for pfn in "${PREBUILD_FNS[@]}"; do
        "$pfn"
    done
    echo "Running builds..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        DIR="${BUILD_DIRS[$i]}"
        CHECKOUT="${BUILD_CHECKOUTS[$i]}"
        if [ ! -d "$DIR" ]; then
            echo "$DIR: Error: must fetch sources before build"
            exit 1
        fi
        # subshell avoids potential cd problems
        (
            cd "$DIR"
            echo "$DIR: checkout: $CHECKOUT..."
            assert_str "$CHECKOUT"
            git checkout "$CHECKOUT" || exit $?
            "${BUILD_FNS[$i]}"
        )
        RC=$?
        if [ $RC -eq 0 ]; then
            echo "$DIR: build successful"
        else
            echo "$DIR: Error: build failed with exit code: $RC"
            exit $RC
        fi
    done
fi
