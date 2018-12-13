#!/bin/bash
#
# Fetch and/or build sources that require the other toolchains
#

BUILD_JOBS=4

# Must know where the POKY SDK is - fall back on default install location
export POKY_SDK=${POKY_SDK:-"/opt/poky/2.4.3"}

# Check that baremetal toolchain is on PATH
function check_bm_toolchain()
{
    which arm-none-eabi-gcc > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Bare metal cross compiler 'arm-none-eabi-gcc' is not on PATH"
        echo "  e.g., export PATH=\$PATH:/opt/gcc-arm-none-eabi-7-2018-q2-update/bin"
        exit 1
    fi
}

# Verify poky toolchain components
function check_poky_toolchain()
{
    if [ ! -d "$POKY_SDK" ]; then
        echo "Error: POKY_SDK not found: $POKY_SDK"
        echo "  e.g., export POKY_SDK=/opt/poky/2.4.3"
        exit 1
    fi
    local POKY_CC_PATH=$POKY_SDK/sysroots/x86_64-pokysdk-linux/usr/bin/aarch64-poky-linux
    export PATH=$PATH:$POKY_CC_PATH
    which aarch64-poky-linux-gcc > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: 'aarch64-poky-linux-gcc' not found in SDK: $POKY_CC_PATH"
        exit 1
    fi
    export SYSROOT="$POKY_SDK/sysroots/aarch64-poky-linux"
    if [ ! -d "${SYSROOT}" ]; then
        echo "Error: sysroot 'aarch64-poky-linux' not found in SDK: $SYSROOT"
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

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetchall|buildall>] [-h]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) download sources and compile"
    echo "       fetchall: download sources"
    echo "       buildall: compile pre-downloaded sources"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
IS_ONLINE=1
IS_BUILD=1
BUILD=""
# parse options
while getopts "h?a:b:" o; do
    case "$o" in
        a)
            if [ "${OPTARG}" == "fetchall" ]; then
                IS_BUILD=0
            elif [ "${OPTARG}" == "buildall" ]; then
                IS_ONLINE=0
            elif [ "${OPTARG}" != "all" ]; then
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        b)
            BUILD="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "$BUILD" ]; then
    usage
fi
. ./build-common.sh || exit $?
build_set_environment "$BUILD"


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
