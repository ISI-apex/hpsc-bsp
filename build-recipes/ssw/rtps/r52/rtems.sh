#!/bin/bash
#
# Depends on:
#  sdk/rtems-source-builder
#

export GIT_REPO="https://github.com/ISI-apex/rtems.git"
export GIT_REV=6be2f05acea476460a6cc5d946789fa9b40efac9
export GIT_BRANCH=hpsc-1.2

export DEPENDS_ENVIRONMENT="sdk/rtems-source-builder" # exports PATH

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
    ENV_check_rsb_toolchain || return $?
    local rsb_src
    rsb_src=$(get_dependency_src "sdk/rtems-source-builder")
    echo "rtems: sb-bootstrap"
    "${rsb_src}/source-builder/sb-bootstrap" || return $?

    mkdir -p b-gen_r52_qemu
    cd b-gen_r52_qemu || return $?
    echo "rtems: gen_r52_qemu: configure"
    # required for sleep functions to work when running in QEMU
    export CLOCK_DRIVER_USE_FAST_IDLE=0
    # prevents RTEMS from crashing QEMU on failures
    export BSP_RESET_BOARD_AT_EXIT=0
    ../configure --target=arm-rtems5 \
                 --prefix="$RTEMS_RTPS_R52_BSP" \
                 --disable-networking \
                 --enable-rtemsbsp=gen_r52_qemu || return $?
                 # --enable-tests || return $?
    echo "rtems: gen_r52_qemu: make"
    make_parallel || return $?

    exes_to_uboot_fmt || return $?
}

function do_toolchain_install()
{
    do_toolchain_uninstall # always clean prefix
    cd b-gen_r52_qemu || return $?
    echo "rtems: gen_r52_qemu: make install"
    make install
}
