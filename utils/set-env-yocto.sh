#!/bin/bash
#
# Setup the environment to use the Yocto compiler
#

function usage()
{
    echo "Usage: $0 [-w DIR] [-h]"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    echo ""
    echo "Source this script to setup the Yocto application development environment"
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

function setup_yocto_env()
{
    # verify that components exist
    local BSP_DIR
    BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
    local YOCTO_ENV="${BSP_DIR}/${WORKING_DIR#${BSP_DIR}}/env/yocto-hpps-sdk/environment-setup-aarch64-poky-linux"
    if [ ! -e "$YOCTO_ENV" ]; then
        echo "Recipe not built: ssw/hpps/yocto"
        return 1
    fi
    # source environment setup script
    source "$YOCTO_ENV"
}

if [ -z "$RC" ]; then
    setup_yocto_env
    RC=$?
fi
# subshell to set exit code (don't directly exit since this script is sourced)
(exit $RC)
