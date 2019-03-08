#!/bin/bash

# Fail-fast
set -e

function usage()
{
    echo "Usage: $0 [-a <all|fetch|build|populate_sdk|test|taskexp>] [-w DIR] [-h]"
    echo "    -a ACTION"
    echo "       all: (default) fetch, build, and populate_sdk (not test or taskexp)"
    echo "       fetch: download sources"
    echo "       build: compile poky image"
    echo "       populate_sdk: build poky SDK installer, including sysroot (rootfs)"
    echo "       test: run the Yocto automated runtime tests (requires build)"
    echo "       taskexp: run the task dependency explorer (requires build)"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
IS_POPULATE_SDK=0
IS_TEST=0
IS_TASKEXP=0
WORKING_DIR="BUILD"
# parse options
while getopts "h?a:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            elif [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "populate_sdk" ]; then
                IS_POPULATE_SDK=1
            elif [ "${OPTARG}" == "test" ]; then
                IS_TEST=1
            elif [ "${OPTARG}" == "taskexp" ]; then
                IS_TASKEXP=1
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
    # do everything except test and taskexp
    IS_FETCH=1
    IS_BUILD=1
    IS_POPULATE_SDK=1
fi

# these recipes are only used for test, so must be fetched/built separately
TEST_RECIPES=(openmp-test pthreads-test hpsc-utils)

. ./configure-hpsc-yocto-env.sh -w "$WORKING_DIR"

# finally, execute the requested action(s)
if [ $IS_FETCH -ne 0 ]; then
    bitbake core-image-hpsc --runall="fetch"
    bitbake core-image-hpsc -c populate_sdk --runall="fetch"
    bitbake "${TEST_RECIPES[@]}" --runall="fetch"
    bitbake core-image-hpsc -c testimage --runall="fetch"
fi

# force offline now to catch anything that still tries to fetch
# this also helps ensure that offline builds will work
echo "Setting BB_NO_NETWORK=1 after fetch"
export BB_NO_NETWORK=1

if [ $IS_BUILD -ne 0 ]; then
    bitbake core-image-hpsc
fi

if [ $IS_POPULATE_SDK -ne 0 ]; then
    bitbake core-image-hpsc -c populate_sdk
fi

if [ $IS_TEST -ne 0 ]; then
    bitbake "${TEST_RECIPES[@]}"
    bitbake core-image-hpsc -c testimage
fi

if [ $IS_TASKEXP -ne 0 ]; then
    bitbake -u taskexp -g core-image-hpsc
fi
