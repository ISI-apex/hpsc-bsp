#!/bin/bash
#
# Depends on:
#  rtems-source-builder
#  rtems-rtps-r52
#

export GIT_REPO="https://github.com/ISI-apex/hpsc-rtems.git"
export GIT_REV=bf7746d0e6358247aa5e6e26779cf622c1f24424
export GIT_BRANCH="hpsc"

# exports PATH and RTEMS_MAKEFILE_PATH
export DEPENDS_ENVIRONMENT="rtems-source-builder:rtems-rtps-r52"

function do_build()
{
    ENV_check_rsb_toolchain || return 1
    ENV_check_rtems_r52_sdk || return 1
    make_parallel
}

function do_deploy()
{
    deploy_artifacts BSP/rtps-r52 rtps-r52/o-optimize/rtps-r52.img
}
