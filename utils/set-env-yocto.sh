#!/bin/bash
#
# Setup the environment to use the Yocto compiler
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

function setup_yocto_env()
{
    # verify that components exist
    local BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    local YOCTO_ENV="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/yocto-hpps-sdk/environment-setup-aarch64-poky-linux"
    if [ ! -e "$YOCTO_ENV" ]; then
        echo "Recipe not built: sdk/gcc-arm-none-eabi"
        return 1
    fi
    # source environment setup script
    source "$YOCTO_ENV"
}

setup_yocto_env
