#!/bin/bash

export WGET_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2"
export WGET_OUTPUT="gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2"
export WGET_OUTPUT_MD5="299ebd3f1c2c90930d28ab82e5d8d6c0"

export DO_FETCH_ONLY=1

function do_deploy()
{
    deploy_artifacts toolchains "$WGET_OUTPUT"
}

function do_toolchain_install()
{
    local inst_dir="${REC_ENV_DIR}/gcc-arm-none-eabi-7-2018-q2-update"
    if [ -d "$inst_dir" ]; then
        echo "Bare metal toolchain already installed: $inst_dir"
    else
        echo "Installing bare metal toolchain..."
        tar xjf "$WGET_OUTPUT" -C "$(dirname "$inst_dir")"
    fi
}
