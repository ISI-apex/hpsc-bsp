#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/u-boot.git"
export GIT_REV=79df69589d9049872485d68c194fc7c0baeabd6d
export GIT_BRANCH=hpsc

export DEPENDS_ENVIRONMENT="sdk/gcc-arm-none-eabi"

DEPLOY_DIR=ssw/rtps/r52
DEPLOY_ARTIFACTS=(u-boot.bin)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    ENV_check_bm_toolchain || return $?
    make hpsc_rtps_r52_defconfig || return $?
    make_parallel CROSS_COMPILE=arm-none-eabi-
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
