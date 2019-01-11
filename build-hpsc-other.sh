#!/bin/bash
#
# Fetch and/or build sources that require the other toolchains
#

# Check that baremetal toolchain is on PATH
function check_bm_toolchain()
{
    which arm-none-eabi-gcc > /dev/null 2>&1 ||
    (
        echo "Error: Bare metal cross compiler 'arm-none-eabi-gcc' is not on PATH"
        echo "  e.g., export PATH=\$PATH:/opt/gcc-arm-none-eabi-7-2018-q2-update/bin"
        exit 1
    )
}

# Verify poky toolchain
function check_poky_toolchain()
{
    if [ -z "$POKY_SDK" ] || [ ! -d "$POKY_SDK" ]; then
        echo "Error: POKY_SDK not found: $POKY_SDK"
        echo "  e.g., export POKY_SDK=/opt/poky/2.6"
        exit 1
    fi
}

function make_clean()
{
    make clean "$@"
}

function make_parallel()
{
    make -j "$(nproc)" "$@"
}

function uboot_r52_build()
{
    make hpsc_rtps_r52_defconfig
    make_parallel CROSS_COMPILE=arm-none-eabi- CONFIG_LD_GCC=y
}

function qemu_post_fetch()
{
    # Fetches submodules, which requires internet
    # We only know which submodules are used b/c we've run configure before...
    ./scripts/git-submodule.sh update ui/keycodemapdb dtc capstone
}
function qemu_clean()
{
    rm -rf BUILD
}
function qemu_build()
{
    mkdir -p BUILD
    (
        cd BUILD
        ../configure --target-list="aarch64-softmmu" --enable-fdt \
                     --disable-kvm --disable-xen
        make_parallel
    )
}
function qemu_test()
{
    make_parallel -C BUILD check-unit
}

function utils_clean()
{
    for s in host linux; do
        echo "hpsc-utils: $s: clean"
        make_clean -C "$s"
    done
}
function utils_build()
{
    for s in host linux; do
        (
            echo "hpsc-utils: $s: build"
            if [ "$s" == "linux" ]; then
                echo "hpsc-utils: source poky environment"
                . "${POKY_SDK}/environment-setup-aarch64-poky-linux"
                unset LDFLAGS
            fi
            make_parallel -C "$s"
        )
    done
}

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetch|clean|build|test>] [-h] [-w DIR]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) fetch and build"
    echo "       fetch: download sources"
    echo "       clean: clean compiled sources"
    echo "       build: compile pre-downloaded sources"
    echo "       test: run unit tests"
    echo "    -h: show this message and exit"
    echo "    -w DIR: set the working directory (default=ID from -b)"
    echo ""
    echo "The POKY_SDK environment variable must also be set to the SDK path."
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_CLEAN=0
IS_BUILD=0
IS_TEST=0
BUILD=""
WORKING_DIR=""
while getopts "h?a:b:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "clean" ]; then
                IS_CLEAN=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "test" ]; then
                IS_TEST=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
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
        w)
            WORKING_DIR="${OPTARG}"
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
WORKING_DIR=${WORKING_DIR:-"$BUILD"}
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    # do everything except clean and test
    IS_FETCH=1
    IS_BUILD=1
fi

# Fail-fast
set -e

. ./build-common.sh
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
BUILD_POST_FETCH=(:
                  :
                  qemu_post_fetch
                  :
                  :)
BUILD_CHECKOUTS=("$GIT_CHECKOUT_BM"
                 "$GIT_CHECKOUT_UBOOT_R52"
                 "$GIT_CHECKOUT_QEMU"
                 "$GIT_CHECKOUT_QEMU_DT"
                 "$GIT_CHECKOUT_HPSC_UTILS")
BUILD_CLEAN_FNS=(make_clean
                 make_clean
                 qemu_clean
                 make_clean
                 utils_clean)
BUILD_FNS=(make_parallel
           uboot_r52_build
           qemu_build
           make_parallel
           utils_build)
BUILD_TEST_FNS=(:
                :
                qemu_test
                :
                :)

TOPDIR=${PWD}
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

if [ $IS_FETCH -ne 0 ]; then
    echo "Fetching sources..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        src="${PWD}/src/${BUILD_DIRS[$i]}.git"
        work="work/${BUILD_DIRS[$i]}"
        git_clone_fetch_bare "${BUILD_REPOS[$i]}" "$src"
        git_clone_fetch_checkout "$src" "$work" "${BUILD_CHECKOUTS[$i]}"
        (
            echo "${BUILD_DIRS[$i]}: post-fetch..."
            cd "$work"
            "${BUILD_POST_FETCH[$i]}"
        )
    done
fi

if [ $IS_CLEAN -ne 0 ]; then
    echo "Running clean..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        work="work/${BUILD_DIRS[$i]}"
        # ignore if directory isn't present
        if [ -d "$work" ]; then
            (
                echo "${BUILD_DIRS[$i]}: clean"
                cd "$work"
                "${BUILD_CLEAN_FNS[$i]}"
            )
        fi
    done
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Running pre-build checks..."
    for pfn in "${PREBUILD_FNS[@]}"; do
        "$pfn"
    done
    echo "Running builds..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        name="${BUILD_DIRS[$i]}"
        work="work/${BUILD_DIRS[$i]}"
        if [ ! -d "$work" ]; then
            echo "$name: Error: must fetch sources before build"
            exit 1
        fi
        (
            echo "$name: build"
            cd "$work"
            "${BUILD_FNS[$i]}" && RC=0 || RC=$?
            if [ $RC -eq 0 ]; then
                echo "$name: build successful"
            else
                echo "$name: Error: build failed with exit code: $RC"
                exit $RC
            fi
        )
    done
fi

if [ $IS_TEST -ne 0 ]; then
    echo "Running test..."
    for ((i = 0; i < ${#BUILD_DIRS[@]}; i++)); do
        name="${BUILD_DIRS[$i]}"
        work="work/${BUILD_DIRS[$i]}"
        if [ ! -d "$work" ]; then
            echo "$name: Error: must fetch sources before test"
            exit 1
        fi
        (
            echo "$name: test"
            cd "$work"
            "${BUILD_TEST_FNS[$i]}"
        )
    done
fi

cd "$TOPDIR"
