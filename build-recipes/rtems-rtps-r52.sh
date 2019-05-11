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
# export DO_CLEAN_AFTER_FETCH=0

# TODO: Why is set -e being ignored here?

# for other recipes
export RTEMS_RTPS_R52_BSP=${REC_ENV_DIR}/RTEMS-5-RTPS-R52
export RTEMS_MAKEFILE_PATH=${RTEMS_RTPS_R52_BSP}/arm-rtems5/gen_r52_qemu

function do_toolchain_uninstall()
{
    rm -rf "$RTEMS_RTPS_R52_BSP"
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

function do_build()
{
    local rsb_src=$(get_dependency_src rtems-source-builder)
    echo "rtems: sb-bootstrap"
    "${rsb_src}/source-builder/sb-bootstrap" || return $?

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
    do_toolchain_uninstall # always clean prefix
    cd b-gen_r52_qemu
    echo "rtems: gen_r52_qemu: make install"
    make install
}
