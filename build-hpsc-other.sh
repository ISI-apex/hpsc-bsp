#!/bin/bash
#
# Fetch and/or build sources that require the other toolchains
#

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("sdk/gcc-arm-none-eabi"
         "sdk/hpsc-sdk-tools"
         "sdk/qemu"
         "sdk/qemu-devicetrees"
         "ssw/hpps/arm-trusted-firmware"
         "ssw/hpps/busybox"
         "ssw/hpps/linux"
         "ssw/hpps/u-boot"
         "ssw/hpsc-baremetal"
         "ssw/rtps/a53/arm-trusted-firmware"
         "ssw/rtps/a53/u-boot"
         "ssw/rtps/r52/u-boot"
         "ssw/hpsc-utils"
         "sdk/hpsc-eclipse")

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

ACTION_FLAGS=()
if [ $IS_FETCH -ne 0 ]; then
    ACTION_FLAGS+=(-a fetch)
fi
if [ $IS_BUILD -ne 0 ]; then
    ACTION_FLAGS+=(-a build)
fi
if [ $IS_TEST -ne 0 ]; then
    ACTION_FLAGS+=(-a test)
fi

for rec in "${RECIPES[@]}"; do
    ./build-recipe.sh -r "$rec" -w "$WORKING_DIR" "${ACTION_FLAGS[@]}"
done
