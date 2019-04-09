#!/bin/bash
#
# Depends on:
#  rtems-source-builder
#

export GIT_REPO="https://github.com/ISI-apex/rtems.git"
export GIT_REV=7b9d68a4c01e9f1256a03f8a73cfa8b17f761037
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="rtems-source-builder" # exports PATH

# Builds take a long time, incremental build seems to be work
export DO_CLEAN_AFTER_FETCH=0

# TODO: Why is set -e being ignored here?

function maybe_bootstrap()
{
    # RTEMS doesn't do incremental builds, and it's a little slow to bootstrap
    # Try to optimize: see if either RSB or this recipe has been updated
    # NOTE: Assumes both recipes are otherwise static - does NOT rebuild if
    #       recipes changes in ANY way other than updating GIT_REV!
    #       Force a clean of the working directory to test other changes
    local do_boostrap=1
    local rsb_git_rev_curr=$(arm-rtems5-gcc --version | grep RSB |
                             awk '{print $8}' | cut -d- -f1)
    # idiot-check to make sure we actually got a git hash
    if [ ${#rsb_git_rev_curr} -ne 40 ]; then
        echo "WARNING: failed to get RSB revision; will bootstrap RTEMS..."
    elif [ -e hpsc-bsp-rsb-rev.txt ] && [ -e hpsc-bsp-rtems-rev.txt ]; then
        local rsb_git_rev_last=$(cat hpsc-bsp-rsb-rev.txt)
        local rtems_rev_last=$(cat hpsc-bsp-rtems-rev.txt)
        echo "RSB git rev (last): $rsb_git_rev_last"
        echo "RSB git rev (curr): $rsb_git_rev_curr"
        echo "RTEMS git rev (last): $rtems_rev_last"
        echo "RTEMS git rev (curr): $GIT_REV"
        if [ "$rsb_git_rev_curr" == "$rsb_git_rev_last" ] &&
           [ "$GIT_REV" == "$rtems_rev_last" ]; then
            echo "No change in git revisions since last bootstrap; skipping..."
            echo "Clean this recipe to force a rebuild"
            do_boostrap=0
       fi
    fi
    if [ $do_boostrap -eq 1 ]; then
        echo "rtems: bootstrap"
        ./bootstrap || return $?
    fi
    echo "$rsb_git_rev_curr" > hpsc-bsp-rsb-rev.txt
    echo "$GIT_REV" > hpsc-bsp-rtems-rev.txt
}

function exes_to_uboot_fmt()
{
    while IFS= read -r -d '' file; do
        # local BASE="$(echo "$file" | sed 's/.exe$//')"
        local BASE="${file%.exe}" # strip .exe extension
        echo "${BASE}: arm-rtems5-objcopy"
        arm-rtems5-objcopy -O binary "${BASE}.exe" "${BASE}.bin" || return $?
        echo "${BASE}: gzip"
        gzip -f -9 "${BASE}.bin" || return $?
        echo "${BASE}: mkimage"
        mkimage -A arm -O rtems -T kernel -C gzip -a 70000000 -e 70000040 \
                -n "$(basename "$file")" -d "${BASE}.bin.gz" "${BASE}.img" \
                || return $?
    done < <(find . -name "*.exe" -print0)
}

# for other recipes
export RTEMS_RTPS_R52_BSP=${REC_ENV_DIR}/RTEMS-5-RTPS-R52
export RTEMS_MAKEFILE_PATH=${RTEMS_RTPS_R52_BSP}/arm-rtems5/gen_r52_qemu

function do_build()
{
    maybe_bootstrap || return $?

    mkdir -p b-gen_r52_qemu
    cd b-gen_r52_qemu
    echo "rtems: gen_r52_qemu: configure"
    # required for sleep functions to work when running in QEMU
    export CLOCK_DRIVER_USE_FAST_IDLE=0
    # prevents RTEMS from crashing QEMU on failures
    export BSP_RESET_BOARD_AT_EXIT=0
    ../configure --target=arm-rtems5 \
                 --prefix="$RTEMS_RTPS_R52_BSP" \
                 --disable-networking \
                 --enable-rtemsbsp=gen_r52_qemu \
                 --enable-tests || return $?
    echo "rtems: gen_r52_qemu: make"
    make || return $?

    exes_to_uboot_fmt || return $?
}

function do_toolchain_install()
{
    rm -rf "$RTEMS_RTPS_R52_BSP" # always clean prefix
    cd b-gen_r52_qemu
    echo "rtems: gen_r52_qemu: make install"
    make install
}