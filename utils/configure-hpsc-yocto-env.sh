#!/bin/bash
#
# Configure Yocto/poky environment in a working directory.
#
# Prerequisites:
# -Set IS_FETCH=0 for offline execution.
#
# After sourcing, the working directory will be the poky build directory and
# the caller's environment will be set by poky's 'oe-init-build-env' script.
#

# This script is sourced, it must not set -e
# set -e

function usage()
{
    echo "Usage: $0 -w DIR [-h]"
    echo "    -w DIR: set the working directory"
    echo "    -h: show this message and exit"
}

# Script options
WORKING_DIR=""
# parse options
OPTIND=1 # reset since we're probably being sourced
while getopts "w:h?" o; do
    case "$o" in
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            return
            ;;
        *)
            echo "Unknown option"
            return 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$WORKING_DIR" ]; then
    usage
    return 1
fi

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
cd "$BSP_DIR"

IS_FETCH=${IS_FETCH:-1}
# clone poky and the layers we configure
if [ "$IS_FETCH" -ne 0 ]; then
    ./build-recipe.sh -w "$WORKING_DIR" -a fetch -r hpsc-yocto || return $?
fi

# TODO: mimicks build-recipes/hpsc-yocto.sh... could easily get out of sync

FULL_WD="${PWD}/${WORKING_DIR}"

DL_DIR="${FULL_WD}/src/hpsc-yocto/poky_dl"
BUILD_DIR="${FULL_WD}/work/hpsc-yocto/poky_build"

POKY_DIR="${FULL_WD}/src/poky"
META_OE_DIR="${FULL_WD}/src/meta-openembedded"
META_HPSC_DIR="${FULL_WD}/src/meta-hpsc"
LAYERS=("${META_OE_DIR}/meta-oe"
        "${META_OE_DIR}/meta-python"
        "${META_HPSC_DIR}/meta-hpsc-bsp")

for l in "${LAYERS[@]}"; do
    LAYER_ARGS+=("-l" "$l")
done
source build-recipes/hpsc-yocto/configure-env.sh -d "${DL_DIR}" \
                                                 -b "${BUILD_DIR}" \
                                                 -p "${POKY_DIR}" \
                                                 "${LAYER_ARGS[@]}"
