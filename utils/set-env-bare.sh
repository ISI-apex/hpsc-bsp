#!/bin/bash
#
# Setup the environment to use the bare-metal compiler
#

function usage()
{
    echo "Usage: $0 [-w DIR] [-h]"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    echo ""
    echo "Source this script to setup the bare-metal application development environment"
}

WORKING_DIR="BUILD"
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

function setup_bm_env()
{
    # verify that components exist
    local BSP_DIR
    BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    local BM_PATH="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/gcc-arm-none-eabi"
    if [ ! -d "$BM_PATH" ]; then
        echo "Recipe not built: sdk/gcc-arm-none-eabi"
        return 1
    fi
    # export environment variables
    export PATH=${BM_PATH}/bin:$PATH
}

if [ -z "$RC" ]; then
    setup_bm_env
    RC=$?
fi
# subshell to set exit code (don't directly exit since this script is sourced)
(exit $RC)
