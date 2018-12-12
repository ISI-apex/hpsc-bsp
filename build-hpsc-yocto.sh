#!/bin/bash

# Yocto packages to install
# Please list alphabetically and group items together appropriately
YOCTO_INSTALL=(gdb gdbserver
               libc-staticdev
               libgomp libgomp-dev libgomp-staticdev
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

# Script options
IS_ONLINE=1
ACTION=$1
case "$ACTION" in
    "" | "all" |\
    "fetchall" |\
    "populate_sdk" |\
    "taskexp")
        ;;
    *)
        echo "Usage: $0 [ACTION]"
        echo "  where ACTION is one of:"
        echo "    all: (default) download sources and build all, including kernel image and rootfs"
        echo "    fetchall: download sources"
        echo "    populate_sdk: download sources, then build cross-compiler toolchain installer"
        echo "    taskexp: after the previous builds have completed, run the task dependency explorer"
        exit 1
        ;;
esac

. ./build-common.sh || exit $?

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

# finally, execute the requested action
case "$ACTION" in
    "" | "all")
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
    *)
        echo "Unknown ACTION"
        exit 1
        ;;
esac
