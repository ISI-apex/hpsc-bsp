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

    # Note: The BSP recipe build system doesn't handle dependencies for us, so
    #       we must have explicit knowledge of the yocto recipe dependencies.
    #       These could change in the future and thus need to be kept in sync.
    #       Fortunately, these dependencies don't change as often as the recipe.
    local YOCTO_SUBDIR="ssw/hpps/yocto"
    local IS_FETCH=${IS_FETCH:-1}
    # clone poky and the layers we configure
    if [ "$IS_FETCH" -ne 0 ]; then
        "${BSP_DIR}/build-recipe.sh" -w "$WORKING_DIR" -a fetch \
            -r "${YOCTO_SUBDIR}/poky" \
            -r "${YOCTO_SUBDIR}/meta-openembedded" \
            -r "${YOCTO_SUBDIR}/meta-hpsc" \
            -r "${YOCTO_SUBDIR}" \
            || return $?
    fi

    # Note: This has the side effect of also exporting the recipe environment to
    #       the user, but that's preferable to duplicating the recipe behavior
    #       here, which too easily gets out of sync as the recipe evolves.
    # use the build recipe to configure the environment
    source "${BSP_DIR}/build-recipes/build-recipe-env.sh" \
        -r ssw/hpps/yocto -w "$WORKING_DIR" || return $?
    # recipe functions (rightfully) expect the working directory to be either
    # "$REC_SRC_DIR" or "$REC_WORK_DIR" (see ENV.sh)
    # check REC_WORK_DIR b/c `cd ""` may succeed, but would not do what we want
    if [ -z "$REC_WORK_DIR" ]; then
        echo "REC_WORK_DIR not set! This is a bug."
        return 1
    fi
    cd "$REC_WORK_DIR" || return $?
    yocto_maybe_init_env # function in the yocto build recipe
}

if [ -z "$RC" ]; then
    configure_env
    RC=$?
fi
# subshell to set exit code (don't directly exit since this script is sourced)
(exit $RC)
