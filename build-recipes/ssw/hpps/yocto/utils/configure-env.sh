#!/bin/bash
#
# Configure Yocto/poky environment.
#
# After sourcing, the working directory will be the poky build directory and
# the caller's environment will be set by poky's 'oe-init-build-env' script.
#

# This script is sourced, it must not set -e
# set -e

TEST_MODULES=(perl ping scp ssh date mpi openmp pthreads shm_standalone)

function usage()
{
    echo "Usage: $0 -d DIR -b DIR -p DIR [-l DIR]+ [-h]"
    echo "    -d DIR: set the download directory (use a full path)"
    echo "    -b DIR: set the build directory (use a full path)"
    echo "    -p DIR: set the poky source directory (use a full path)"
    echo "    -l DIR: add a layer directory (use a full path)"
    echo "    -h: show this message and exit"
}

# Script options
DL_DIR=""
BUILD_DIR=""
POKY_DIR=""
LAYER_DIRS=()
# parse options
OPTIND=1 # reset since we're probably being sourced
while getopts "d:b:p:l:h?" o; do
    case "$o" in
        d)
            DL_DIR="${OPTARG}"
            ;;
        b)
            BUILD_DIR="${OPTARG}"
            ;;
        p)
            POKY_DIR="${OPTARG}"
            ;;
        l)
            LAYER_DIRS+=("${OPTARG}")
            ;;
        h)
            usage
            return
            ;;
        *)
            echo "Unknown option"
            usage
            return 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$DL_DIR" ] || [ -z "$BUILD_DIR" ] || [ -z "$POKY_DIR" ]; then
    usage
    return 1
fi

# poky's sanity checker tries to reach example.com unless we force it offline
export BB_NO_NETWORK=1
# create build directory and cd to it
source "${POKY_DIR}/oe-init-build-env" "$BUILD_DIR" || return $?
# configure layers
for layer in "${LAYER_DIRS[@]}"; do
    bitbake-layers add-layer "$layer" || return $?
done
unset BB_NO_NETWORK

# configure local.conf
function conf_replace_or_append()
{
    local line=$1
    local file="conf/local.conf"
    local key
    key=$(echo "$line" | awk '{print $1}')
    # support assignment types: ?=, +=, or =
    # Using '@' instead of '/' in sed so paths can be values
    grep -q "^$key ?*+*=" "$file" && sed -i "s@^${key} .*@${line}@" "$file" || \
        echo "$line" >> "$file"
}
conf_replace_or_append "MACHINE ?= \"hpsc-chiplet\""
conf_replace_or_append "DL_DIR ?= \"${DL_DIR}\""
conf_replace_or_append "FORTRAN_forcevariable = \",fortran\""
# the following commands are needed for enabling runtime tests
conf_replace_or_append "INHERIT_append += \" testimage\""
conf_replace_or_append "TEST_TARGET = \"simpleremote\""
conf_replace_or_append "TEST_SERVER_IP = \"$(hostname -I | cut -d ' ' -f 1)\""
conf_replace_or_append "TEST_TARGET_IP = \"127.0.0.1:3088\""
conf_replace_or_append "IMAGE_FSTYPES_append += \" cpio.gz\""
conf_replace_or_append "TEST_SUITES += \"${TEST_MODULES[*]}\""
