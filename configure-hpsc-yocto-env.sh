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

# Fail-fast
set -e

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
. ./build-config.sh
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

IS_FETCH=${IS_FETCH:-1}
POKY_DL_DIR=${PWD}/src/poky_dl

# clone our repositories and checkout correct revisions
if [ "$IS_FETCH" -ne 0 ]; then
    # download the yocto poky git repository
    git_clone_fetch_checkout "$GIT_URL_POKY" "src/poky" "$GIT_CHECKOUT_POKY"
    # add the meta-openembedded layer (for the mpich package)
    git_clone_fetch_checkout "$GIT_URL_META_OE" "src/meta-openembedded" \
                             "$GIT_CHECKOUT_META_OE"
    # add the meta-hpsc layer
    git_clone_fetch_checkout "$GIT_URL_META_HPSC" "src/meta-hpsc" \
                             "$GIT_CHECKOUT_META_HPSC"
fi

# poky's sanity checker tries to reach example.com unless we force it offline
export BB_NO_NETWORK=1
# We can use poky and its layers in src dir since everything is out-of-tree
BITBAKE_LAYERS=("${PWD}/src/meta-openembedded/meta-oe"
                "${PWD}/src/meta-openembedded/meta-python"
                "${PWD}/src/meta-hpsc/meta-hpsc-bsp")
# create build directory and cd to it
. ./src/poky/oe-init-build-env work/poky_build
# configure layers
for layer in "${BITBAKE_LAYERS[@]}"; do
    bitbake-layers add-layer "$layer"
done
unset BB_NO_NETWORK

# configure local.conf
function conf_replace_or_append()
{
    local key=$1
    local value=$2
    local file="conf/local.conf"
    # Using '@' instead of '/' in sed so paths can be values
    grep -q "^$key =" "$file" && sed -i "s@^$key.*@$key = $value@" "$file" ||\
        echo "$key = $value" >> "$file"
}
conf_replace_or_append "MACHINE" "\"hpsc-chiplet\""
conf_replace_or_append "DL_DIR" "\"${POKY_DL_DIR}\""
conf_replace_or_append "FORTRAN_forcevariable" "\",fortran\""
# the following commands are needed for enabling runtime tests
conf_replace_or_append "INHERIT_append" "\" testimage\""
conf_replace_or_append "TEST_TARGET" "\"simpleremote\""
conf_replace_or_append "TEST_SERVER_IP" "\"$(hostname -I | cut -d ' ' -f 1)\""
conf_replace_or_append "TEST_TARGET_IP" "\"127.0.0.1:10022\""
conf_replace_or_append "IMAGE_FSTYPES_append" "\" cpio.gz\""
conf_replace_or_append "TEST_SUITES" "\"perl ping scp ssh date openmp pthreads\""
