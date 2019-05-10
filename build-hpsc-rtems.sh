#!/bin/bash

# Fail-fast
set -e

RECIPES=("sdk/rtems-tools"
         "sdk/rtems-source-builder"
         "ssw/rtps/r52/rtems"
         "ssw/rtps/r52/hpsc-rtems")

function usage()
{
    echo "Usage: $0 [-a <all|fetch|build>] [-w DIR] [-h]"
    echo "    -a ACTION"
    echo "       all: (default) fetch and build"
    echo "       fetch: download sources"
    echo "       build: compile poky image"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
WORKING_DIR="BUILD"
# parse options
while getopts "a:w:h?" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            elif [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
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
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -eq 1 ]; then
    IS_FETCH=1
    IS_BUILD=1
fi

ACTION_FLAGS=()
if [ $IS_FETCH -ne 0 ]; then
    ACTION_FLAGS+=(-a fetch)
fi
if [ $IS_BUILD -ne 0 ]; then
    ACTION_FLAGS+=(-a build)
fi

for rec in "${RECIPES[@]}"; do
    ./build-recipe.sh -r "$rec" -w "$WORKING_DIR" "${ACTION_FLAGS[@]}"
done
