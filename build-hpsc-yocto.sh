#!/bin/bash

# Yocto packages to install
# Please list alphabetically and group items together appropriately
YOCTO_INSTALL=(gdb gdbserver
               libgfortran
               libgomp
               libstdc++
               mpich
               mtd-utils
               openssh openssh-sftp-server
               python-core python-numpy
               # qemu
               util-linux
               watchdog)

function conf_replace_or_append()
{
    local key=$1
    local value=$2
    local file="conf/local.conf"
    grep -q "^$key =" "$file" && sed -i "s/^$key.*/$key = $value/" "$file" ||\
        echo "$key = $value" >> "$file"
}

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetchall|populate_sdk|buildall|taskexp>] [-h] [-w DIR]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) download sources and build all,"
    echo "            including kernel image and rootfs"
    echo "       fetchall: download sources"
    echo "       populate_sdk: build poky SDK installer, including sysroot (rootfs)"
    echo "       buildall: like all, but try offline"
    echo "       taskexp: run the task dependency explorer (requires build)"
    echo "    -h: show this message and exit"
    echo "    -w DIR: Set the working directory (default=ID from -b)"
    exit 1
}

# Script options
IS_ONLINE=1
ACTION=""
BUILD=""
WORKING_DIR=""
# parse options
while getopts "h?a:b:w:" o; do
    case "$o" in
        a)
            if [ "${OPTARG}" == "all" ] ||
               [ "${OPTARG}" == "fetchall" ]; then
                IS_ONLINE=1
            elif [ "${OPTARG}" == "populate_sdk" ] ||
                 [ "${OPTARG}" == "buildall" ] ||
                 [ "${OPTARG}" == "taskexp" ]; then
                # TODO: Force bitbake offline (may involve setting BB_NO_NETWORK)
                IS_ONLINE=0
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ACTION="${OPTARG}"
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
if [ -z "$WORKING_DIR" ]; then
    WORKING_DIR="$BUILD"
fi
. ./build-common.sh || exit $?
build_set_environment "$BUILD"

TOPDIR=${PWD}
mkdir -p "$WORKING_DIR" || exit 1
cd "$WORKING_DIR"

# BB_ENV_EXTRAWHITE allows additional variables to pass through from
# the external environment into Bitbake's datastore
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE \
                          SRCREV_atf \
                          SRCREV_linux_hpsc \
                          SRCREV_qemu_devicetrees \
                          SRCREV_qemu \
                          SRCREV_u_boot"

if [ $IS_ONLINE -ne 0 ]; then
    git_clone_pull "https://github.com/ISI-apex/meta-openembedded" "meta-openembedded" || exit $?
    git_clone_pull "https://github.com/ISI-apex/meta-hpsc" "meta-hpsc" || exit $?
    git_clone_pull "https://github.com/ISI-apex/poky" "poky" || exit $?
fi

# add the meta-openembedded layer (for the mpich package)
cd meta-openembedded
assert_str "$GIT_CHECKOUT_META_OE"
git checkout "$GIT_CHECKOUT_META_OE" || exit $?
cd ..

# add the meta-hpsc layer
cd meta-hpsc
assert_str "$GIT_CHECKOUT_META_HPSC"
git checkout "$GIT_CHECKOUT_META_HPSC" || exit $?
cd ..

BITBAKE_LAYERS=("${PWD}/meta-openembedded/meta-oe"
                "${PWD}/meta-openembedded/meta-python"
                "${PWD}/meta-hpsc/meta-xilinx-bsp")

# download the yocto poky git repository
cd poky
assert_str "$GIT_CHECKOUT_POKY"
git checkout "$GIT_CHECKOUT_POKY" || exit $?
# create build directory and configure it
. ./oe-init-build-env build
for layer in "${BITBAKE_LAYERS[@]}"; do
    bitbake-layers add-layer "$layer"
done

# configure local.conf
conf_replace_or_append "MACHINE" "\"hpsc-chiplet\""
conf_replace_or_append "CORE_IMAGE_EXTRA_INSTALL" "\"${YOCTO_INSTALL[*]}\""
conf_replace_or_append "FORTRAN_forcevariable" "\",fortran\""

# finally, execute the requested action
case "$ACTION" in
    "" | "all" | "buildall")
        bitbake core-image-minimal
        ;;
    "fetchall")
        bitbake core-image-minimal -c fetchall
        ;;
    "populate_sdk")
        bitbake core-image-minimal -c populate_sdk
        ;;
    "taskexp")
        bitbake -u taskexp -g core-image-minimal
        ;;
esac

cd "$TOPDIR"
