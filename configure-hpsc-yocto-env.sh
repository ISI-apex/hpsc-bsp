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
# TODO: clean up to minimize pollution of user's environment

LAYER_RECIPES=(poky
               meta-openembedded
               meta-hpsc)

function usage()
{
    echo "Usage: $0 -w DIR [-h]"
    echo "    -w DIR: set the working directory"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
WORKING_DIR=""
# parse options
OPTIND=1 # reset since we're probably being sourced
while getopts "h?w:" o; do
    case "$o" in
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
if [ -z "$WORKING_DIR" ]; then
    usage
fi

. ./build-common.sh
build_work_dirs "$WORKING_DIR"

IS_FETCH=${IS_FETCH:-1}
POKY_DL_DIR=$(cd "$WORKING_DIR" && echo "${PWD}/src/poky_dl")

# clone poky and the layers we configure
if [ "$IS_FETCH" -ne 0 ]; then
    REC_PARAMS=()
    for rec in "${LAYER_RECIPES[@]}"; do
        REC_PARAMS+=("-r" "$rec")
    done
    ./build-recipe.sh -w "$WORKING_DIR" -a fetch "${REC_PARAMS[@]}" || exit $?
fi

cd "$WORKING_DIR"

# poky's sanity checker tries to reach example.com unless we force it offline
export BB_NO_NETWORK=1
# We can use poky and its layers in src dir since everything is out-of-tree
BITBAKE_LAYERS=("${PWD}/src/meta-openembedded/meta-oe"
                "${PWD}/src/meta-openembedded/meta-python"
                "${PWD}/src/meta-hpsc/meta-hpsc-bsp")
# create build directory and cd to it
. ./src/poky/oe-init-build-env work/poky_build || exit $?
# configure layers
for layer in "${BITBAKE_LAYERS[@]}"; do
    bitbake-layers add-layer "$layer" || exit $?
done
unset BB_NO_NETWORK

# configure local.conf
function conf_replace_or_append()
{
    local line=$1
    local file="conf/local.conf"
    local key=$(echo "$line" | awk '{print $1}')
    # support assignment types: ?=, +=, or =
    # Using '@' instead of '/' in sed so paths can be values
    grep -q "^$key ?*+*=" "$file" && sed -i "s@^${key} .*@${line}@" "$file" || \
        echo "$line" >> "$file"
}
conf_replace_or_append "MACHINE ?= \"hpsc-chiplet\""
conf_replace_or_append "DL_DIR ?= \"${POKY_DL_DIR}\""
conf_replace_or_append "FORTRAN_forcevariable = \",fortran\""
# the following commands are needed for enabling runtime tests
conf_replace_or_append "INHERIT_append += \" testimage\""
conf_replace_or_append "TEST_TARGET = \"simpleremote\""
conf_replace_or_append "TEST_SERVER_IP = \"$(hostname -I | cut -d ' ' -f 1)\""
conf_replace_or_append "TEST_TARGET_IP = \"127.0.0.1:3040\""
conf_replace_or_append "IMAGE_FSTYPES_append += \" cpio.gz\""
conf_replace_or_append "TEST_SUITES += \"perl ping scp ssh date openmp pthreads\""
