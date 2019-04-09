#!/bin/bash
#
# Setup the environment to build RTEMS applications
#

function usage()
{
    echo "Usage: $0 [-w DIR] [-h]"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    echo ""
    echo "Source this script to setup the RTEMS application development environment"
    return $?
}

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

function setup_rtems_env()
{
    # verify that components exist
    local BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    local RSB_PREFIX="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/RSB-5"
    local RTEMS_PREFIX="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/RTEMS-5-RTPS-R52"
    if [ ! -d "$RSB_PREFIX" ]; then
        echo "Recipe not built: rtems-source-builder"
        return 1
    fi
    if [ ! -d "$RTEMS_PREFIX" ]; then
        echo "Recipe not built: rtems-rtps-r52"
        return 1
    fi
    # export environment variables
    export PATH=${RSB_PREFIX}/bin:$PATH
    export RTEMS_MAKEFILE_PATH="${RTEMS_PREFIX}/arm-rtems5/gen_r52_qemu"
}

setup_rtems_env