#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/u-boot.git"
export GIT_REV=10dd87747a492dda4435ea5bf04e6264abbddd53
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="gcc-arm-none-eabi"

function do_build()
{
    ENV_check_bm_toolchain
    make hpsc_rtps_r52_defconfig
    make_parallel CROSS_COMPILE=arm-none-eabi-
}

function do_deploy()
{
    deploy_artifacts BSP/rtps-r52 u-boot.bin
}
