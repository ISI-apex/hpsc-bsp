#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=d2bb5a18ead5f7cddb9930d0f58b75ac3cf44b80
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="gcc-arm-none-eabi"

function do_build()
{
    ENV_check_bm_toolchain
    make_parallel
}

function do_deploy()
{
    deploy_artifacts BSP/rtps-r52 rtps/bld/rtps.uimg
    deploy_artifacts BSP/trch trch/bld/trch.elf
}
