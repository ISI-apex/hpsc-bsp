#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=823d066cff5be1f34fc1b68b6b585530dd949171
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="gcc-arm-none-eabi"

function do_build()
{
    ENV_check_bm_toolchain
    make_parallel
}

function do_deploy()
{
    # RTPS baremetal image superseded by RTEMS image
    # deploy_artifacts BSP/rtps-r52 rtps/bld/rtps.uimg
    deploy_artifacts BSP/trch trch/bld/trch.elf
}
