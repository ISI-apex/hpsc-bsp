#!/bin/bash
#
# Setup the environment to use the bare-metal compiler
#

WORKING_DIR="BUILD"
# parse options
while getopts "w:h?" o; do
    case "$o" in
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage 1
            ;;
    esac
done

function setup_bm_env()
{
    # verify that components exist
    local BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    local BM_PATH="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/gcc-arm-none-eabi"
    if [ ! -d "$BM_PATH" ]; then
        echo "Recipe not built: sdk/gcc-arm-none-eabi"
        return 1
    fi
    # export environment variables
    export PATH=${BM_PATH}/bin:$PATH
}

setup_bm_env
