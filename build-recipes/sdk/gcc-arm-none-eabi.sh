#!/bin/bash

export GCC_ARM_NONE_EABI_VERSION=7-2018-q2-update # exported for other recipes

export WGET_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-${GCC_ARM_NONE_EABI_VERSION}-linux.tar.bz2"
export WGET_OUTPUT="gcc-arm-none-eabi-${GCC_ARM_NONE_EABI_VERSION}-linux.tar.bz2"
export WGET_OUTPUT_MD5="299ebd3f1c2c90930d28ab82e5d8d6c0"

export DO_FETCH_ONLY=1

INST_DIR="${REC_ENV_DIR}/gcc-arm-none-eabi/"
export PATH="${INST_DIR}/bin:$PATH" # for other recipes

DEPLOY_DIR=sdk/toolchains
DEPLOY_ARTIFACTS=("$WGET_OUTPUT")

function do_toolchain_uninstall()
{
    rm -rf "$INST_DIR"
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_toolchain_install()
{
    if [ -d "$INST_DIR" ]; then
        echo "Bare metal toolchain already installed: $INST_DIR"
    else
        echo "Installing bare metal toolchain..."
        mkdir -p "$INST_DIR" || return $?
        tar xjf "$WGET_OUTPUT" -C "$INST_DIR" --strip-components=1
    fi
}
