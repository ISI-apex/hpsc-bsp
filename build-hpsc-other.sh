#!/bin/bash
#
# Fetch and/or build sources that require the other toolchains
#

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("hpsc-baremetal"
         "arm-trusted-firmware-rtps-a53"
         "u-boot-rtps-r52"
         "u-boot-rtps-a53"
         "qemu"
         "qemu-devicetrees"
         "hpsc-utils"
         "hpsc-eclipse")

# Check that baremetal toolchain is on PATH
function check_bm_toolchain()
{
    if ! which arm-none-eabi-gcc > /dev/null 2>&1; then
        echo "Error: Bare metal cross compiler 'arm-none-eabi-gcc' is not on PATH"
        echo "  e.g., export PATH=\$PATH:/opt/gcc-arm-none-eabi-7-2018-q2-update/bin"
        return 1
    fi
}

# Verify poky toolchain
function check_poky_toolchain()
{
    if [ -z "$POKY_SDK" ] || [ ! -d "$POKY_SDK" ]; then
        echo "Error: POKY_SDK not found: $POKY_SDK"
        echo "  e.g., export POKY_SDK=/opt/poky/2.6"
        return 1
    fi
}

PREBUILD_FNS=(check_bm_toolchain
              check_poky_toolchain)

function usage()
{
    echo "Usage: $0 [-a <all|fetch|build|test>] [-w DIR] [-h]"
    echo "    -a ACTION"
    echo "       all: (default) fetch, build, and test"
    echo "       fetch: download/update sources (forces clean)"
    echo "       build: compile pre-downloaded sources"
    echo "       test: run unit tests"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    echo ""
    echo "The POKY_SDK environment variable must also be set to the SDK path."
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
IS_TEST=0
WORKING_DIR="BUILD"
while getopts "h?a:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
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
        w)
            WORKING_DIR="${OPTARG}"
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
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    IS_FETCH=1
    IS_BUILD=1
    IS_TEST=1
fi

function for_each_recipe()
{
    for rec in "${RECIPES[@]}"; do
        ./build-recipe.sh -r "$rec" -w "$WORKING_DIR" -a "$1"
    done
}

if [ $IS_FETCH -ne 0 ]; then
    echo "Performing action: fetch..."
    for_each_recipe fetch
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Running pre-build checks..."
    for pfn in "${PREBUILD_FNS[@]}"; do
        "$pfn"
    done
    echo "Performing action: build..."
    for_each_recipe build
fi

if [ $IS_TEST -ne 0 ]; then
    echo "Performing action: test..."
    for_each_recipe test
fi
