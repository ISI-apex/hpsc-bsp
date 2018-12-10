#!/bin/bash

# Checkout values can be configured from the environment
GIT_CHECKOUT_POKY=${GIT_CHECKOUT_POKY:-"hpsc"}
GIT_CHECKOUT_META_OE=${GIT_CHECKOUT_META_OE:-"hpsc"}
GIT_CHECKOUT_META_HPSC=${GIT_CHECKOUT_META_HPSC:-"hpsc"}

# The following SRCREV_* env vars allow the user to specify the commit hash or
# tag (e.g. 'hpsc-0.9') that will be checked out for each of the repositories
# below.  Alternatively, the user can specify "\${AUTOREV}" to check out the
# head of the hpsc branch.
export SRCREV_atf=${SRCREV_atf:-"\${AUTOREV}"}
export SRCREV_linux_hpsc=${SRCREV_linux_hpsc:-"\${AUTOREV}"}
export SRCREV_qemu_devicetrees=${SRCREV_qemu_devicetrees:-"\${AUTOREV}"}
export SRCREV_qemu=${SRCREV_qemu:-"\${AUTOREV}"}
export SRCREV_u_boot=${SRCREV_u_boot:-"\${AUTOREV}"}
# BB_ENV_EXTRAWHITE allows additional variables to pass through from
# the external environment into Bitbake's datastore
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE \
                          SRCREV_atf \
                          SRCREV_linux_hpsc \
                          SRCREV_qemu_devicetrees \
                          SRCREV_qemu \
                          SRCREV_u_boot"

# Yocto packages to install
YOCTO_INSTALL=(gdb gdbserver
               libc-staticdev
               libgomp libgomp-dev libgomp-staticdev
               libstdc++
               mpich
               mtd-utils
               openssh openssh-sftp-server
               python-core python-numpy
               util-linux
               watchdog
               qemu)


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

# Clone repository if not already done, always pull
function isi_github_pull()
{
    local repo=$1
    local dir=$1
    # Don't ask for credentials if requests are bad
    export GIT_TERMINAL_PROMPT=0 # for git > 2.3
    export GIT_ASKPASS=/bin/echo
    echo "Pulling repository=$repo"
    if [ ! -d "$dir" ]; then
        git clone "https://github.com/ISI-apex/$repo.git" "$dir" || return $?
    fi
    cd "$dir"
    git pull
    RC=$?
    cd - > /dev/null
    return $RC
}

function conf_replace_or_append()
{
    local key=$1
    local value=$2
    local file="conf/local.conf"
    grep -q "^$key =" "$file" && sed -i "s/^$key.*/$key = $value/" "$file" ||\
        echo "$key = $value" >> "$file"
}

if [ $IS_ONLINE -ne 0 ]; then
    isi_github_pull "meta-openembedded" || exit $?
    isi_github_pull "meta-hpsc" || exit $?
    isi_github_pull "poky" || exit $?
fi

# add the meta-openembedded layer (for the mpich package)
cd meta-openembedded
git checkout "$GIT_CHECKOUT_META_OE" || exit $?
cd ..

# add the meta-hpsc layer
cd meta-hpsc
git checkout "$GIT_CHECKOUT_META_HPSC" || exit $?
cd ..

BITBAKE_LAYERS=("${PWD}/meta-openembedded/meta-oe"
                "${PWD}/meta-openembedded/meta-python"
                "${PWD}/meta-hpsc/meta-xilinx-bsp")

# download the yocto poky git repository
cd poky
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
