#!/bin/bash
#
# Depends on:
#  rtems-source-builder
#  rtems-rtps-r52
#

export GIT_REPO="https://github.com/ISI-apex/hpsc-rtems.git"
export GIT_REV=7fab331d8111d29a9ae1fc572a8e6891690db513
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