#!/bin/bash
#
# Depends on:
#  sdk/rtems-source-builder
#

export GIT_REPO="https://github.com/ISI-apex/rtems.git"
export GIT_REV=05ec36128f274c0c0a7838e89c2ad520ce9b1316
export GIT_BRANCH=hpsc-trch-1.1

export DEPENDS_ENVIRONMENT="sdk/rtems-source-builder" # exports PATH

# for other recipes
export RTEMS_TRCH_BSP=${REC_ENV_DIR}/RTEMS-5-TRCH
export RTEMS_MAKEFILE_PATH=${RTEMS_TRCH_BSP}/arm-rtems5/hpsc_trch_qemu

function do_toolchain_uninstall()
{
    rm -rf "$RTEMS_TRCH_BSP"
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

    mkdir -p b-hpsc_trch_qemu
    cd b-hpsc_trch_qemu || return $?
    echo "rtems: hpsc_trch_qemu: configure"
    # required for sleep functions to work when running in QEMU
    export CLOCK_DRIVER_USE_FAST_IDLE=0
    # prevents RTEMS from crashing QEMU on failures
    export BSP_RESET_BOARD_AT_EXIT=0
    ../configure --target=arm-rtems5 \
                 --prefix="$RTEMS_TRCH_BSP" \
                 --disable-networking \
                 --enable-rtemsbsp=hpsc_trch_qemu || return $?
                 # --enable-tests || return $?
    echo "rtems: hpsc_trch_qemu: make"
    make_parallel || return $?

    exes_to_uboot_fmt || return $?
}

function do_toolchain_install()
{
    do_toolchain_uninstall # always clean prefix
    cd b-hpsc_trch_qemu || return $?
    echo "rtems: hpsc_trch_qemu: make install"
    make install
}
