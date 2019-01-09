#!/bin/bash

function conf_replace_or_append()
{
    local key=$1
    local value=$2
    local file="conf/local.conf"
    # Using '@' instead of '/' in sed so paths can be values
    grep -q "^$key =" "$file" && sed -i "s@^$key.*@$key = $value@" "$file" ||\
        echo "$key = $value" >> "$file"
}

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetchall|buildall|populate_sdk|taskexp>] [-h] [-w DIR]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) perform fetchall, buildall, and populate_sdk (not runtests nor taskexp)"
    echo "       fetchall: download sources"
    echo "       buildall: like all, but try offline"
    echo "       populate_sdk: build poky SDK installer, including sysroot (rootfs)"
    echo "       runtests: run the Yocto automated runtime tests (requires build)"
    echo "       taskexp: run the task dependency explorer (requires build)"
    echo "    -h: show this message and exit"
    echo "    -w DIR: Set the working directory (default=ID from -b)"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_ONLINE=0
IS_BUILD=0
IS_POPULATE_SDK=0
IS_RUNTESTS=0
IS_TASKEXP=0
BUILD=""
WORKING_DIR=""
# parse options
while getopts "h?a:b:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            elif [ "${OPTARG}" == "fetchall" ]; then
                IS_ONLINE=1
            elif [ "${OPTARG}" == "buildall" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "populate_sdk" ]; then
                IS_POPULATE_SDK=1
            elif [ "${OPTARG}" == "runtests" ]; then
                IS_RUNTESTS=1
            elif [ "${OPTARG}" == "taskexp" ]; then
                IS_TASKEXP=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        b)
            BUILD="${OPTARG}"
            ;;
        h)
            usage
            ;;
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        *)
            echo "Unknown option"
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$BUILD" ]; then
    usage
fi
WORKING_DIR=${WORKING_DIR:-"$BUILD"}
POKY_DL_DIR=${PWD}/${WORKING_DIR}/poky_dl
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -eq 1 ]; then
    # do everything except runtests and taskexp
    IS_ONLINE=1
    IS_BUILD=1
    IS_POPULATE_SDK=1
fi

# Fail-fast
set -e

. ./build-common.sh
build_set_environment "$BUILD"

TOPDIR=${PWD}
mkdir -p "$WORKING_DIR"
cd "$WORKING_DIR"

# clone our repositories and checkout correct revisions
if [ $IS_ONLINE -ne 0 ]; then
    # add the meta-openembedded layer (for the mpich package)
    git_clone_pull_checkout "https://github.com/openembedded/meta-openembedded.git" \
                            "meta-openembedded" \
                            "$GIT_CHECKOUT_META_OE"
    # add the meta-hpsc layer
    git_clone_pull_checkout "https://github.com/ISI-apex/meta-hpsc" \
                            "meta-hpsc" \
                            "$GIT_CHECKOUT_META_HPSC"
    # download the yocto poky git repository
    git_clone_pull_checkout "https://git.yoctoproject.org/git/poky" \
                            "poky" \
                            "$GIT_CHECKOUT_POKY"
fi
BITBAKE_LAYERS=("${PWD}/meta-openembedded/meta-oe"
                "${PWD}/meta-openembedded/meta-python"
                "${PWD}/meta-hpsc/meta-hpsc-bsp")

cd poky

# create build directory if it doesn't exist and configure it
# poky's sanity checker tries to reach example.com unless we force it offline
export BB_NO_NETWORK=1
. ./oe-init-build-env build
for layer in "${BITBAKE_LAYERS[@]}"; do
    bitbake-layers add-layer "$layer"
done
unset BB_NO_NETWORK

# configure local.conf
conf_replace_or_append "MACHINE" "\"hpsc-chiplet\""
conf_replace_or_append "DL_DIR" "\"${POKY_DL_DIR}\""
conf_replace_or_append "FORTRAN_forcevariable" "\",fortran\""
# the following commands are needed for enabling runtime tests
conf_replace_or_append "INHERIT_append" "\" testimage\""
conf_replace_or_append "TEST_TARGET" "\"simpleremote\""
conf_replace_or_append "TEST_SERVER_IP" "\"$(hostname -I | cut -d ' ' -f 1)\""
conf_replace_or_append "TEST_TARGET_IP" "\"127.0.0.1:10022\""
conf_replace_or_append "IMAGE_FSTYPES_append" "\" cpio.gz\""
conf_replace_or_append "TEST_SUITES" "\"perl ping scp ssh date\""

# finally, execute the requested action(s)
if [ $IS_ONLINE -ne 0 ]; then
    bitbake core-image-hpsc --runall="fetch"
    bitbake core-image-hpsc -c populate_sdk --runall="fetch"
fi

# force offline now to catch anything that still tries to fetch
# this (hopefully) ensures that offline builds will work
if [ "$BUILD" != "HEAD" ]; then
    echo "Setting BB_NO_NETWORK=1 after fetch for release build"
    export BB_NO_NETWORK=1
fi

if [ $IS_BUILD -ne 0 ]; then
    bitbake core-image-hpsc
fi

if [ $IS_POPULATE_SDK -ne 0 ]; then
    bitbake core-image-hpsc -c populate_sdk
fi

if [ $IS_RUNTESTS -ne 0 ]; then
    bitbake core-image-hpsc -c testimage
fi

if [ $IS_TASKEXP -ne 0 ]; then
    bitbake -u taskexp -g core-image-hpsc
fi

cd "$TOPDIR"
