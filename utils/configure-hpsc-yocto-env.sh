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
RC=
# parse options
OPTIND=1 # reset since we're probably being sourced
while getopts "w:h?" o; do
    case "$o" in
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            RC=0
            ;;
        *)
            echo "Unknown option"
            usage
            RC=1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$RC" ] && [ -z "$WORKING_DIR" ]; then
    usage
    RC=1
fi

function configure_env()
{
    local BSP_DIR
    BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    cd "$BSP_DIR"

    local YOCTO_SUBDIR="ssw/hpps/yocto"

    local IS_FETCH=${IS_FETCH:-1}
    # clone poky and the layers we configure
    if [ "$IS_FETCH" -ne 0 ]; then
        ./build-recipe.sh -w "$WORKING_DIR" -a fetch \
            -r "${YOCTO_SUBDIR}/poky" \
            -r "${YOCTO_SUBDIR}/meta-openembedded" \
            -r "${YOCTO_SUBDIR}/meta-hpsc" \
            || return $?
    fi

    # TODO: mimicks build-recipes/ssw/hpps/yocto.sh... could get out of sync...

    local FULL_WD="${PWD}/${WORKING_DIR}"
    local YOCTO_SRC_DIR="${FULL_WD}/src/${YOCTO_SUBDIR}"
    local YOCTO_WORK_DIR="${FULL_WD}/work/${YOCTO_SUBDIR}"

    mkdir -p "${YOCTO_SRC_DIR}" "${YOCTO_WORK_DIR}"

    local DL_DIR="${YOCTO_SRC_DIR}/poky_dl"
    local BUILD_DIR="${YOCTO_WORK_DIR}/poky_build"

    local POKY_DIR="${YOCTO_SRC_DIR}/poky"
    local META_OE_DIR="${YOCTO_SRC_DIR}/meta-openembedded"
    local META_HPSC_DIR="${YOCTO_SRC_DIR}/meta-hpsc"
    local LAYERS=("${META_OE_DIR}/meta-oe"
            "${META_HPSC_DIR}/meta-hpsc-bsp")

    local LAYER_ARGS=()
    for l in "${LAYERS[@]}"; do
        LAYER_ARGS+=("-l" "$l")
    done
    source "build-recipes/${YOCTO_SUBDIR}/utils/configure-env.sh" \
        -d "${DL_DIR}" \
        -b "${BUILD_DIR}" \
        -p "${POKY_DIR}" \
        "${LAYER_ARGS[@]}"
}

if [ -z "$RC" ]; then
    configure_env
    RC=$?
fi
# subshell to set exit code (don't directly exit since this script is sourced)
(exit $RC)
