#!/bin/bash
#
# Depends on:
#  rtems-source-builder
#  rtems-rtps-r52
#

export GIT_REPO="https://github.com/ISI-apex/hpsc-rtems.git"
export GIT_REV=7379cb53a0d4b6b48b951e3fb2d64d9bda687465
export GIT_BRANCH="hpsc"

# exports PATH, RTEMS_RTPS_R52_BSP, and RTEMS_MAKEFILE_PATH
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

function do_toolchain_uninstall()
{
    # RTEMS builds don't provide an "uninstall" goal...
    # delete old binaries, libraries, and headers (in case some were removed)
    # reliable as long as the project sticks to its libhpsc* naming convention
    rm -f "${RTEMS_RTPS_R52_BSP}/bin/rtps-r52.{img,exe}"
    rm -f "${RTEMS_RTPS_R52_BSP}/arm-rtems5/gen_r52_qemu/lib/libhpsc*.a"
    rm -rf "${RTEMS_RTPS_R52_BSP}/arm-rtems5/gen_r52_qemu/lib/include/libhpsc*"
}

function do_toolchain_install()
{
    do_toolchain_uninstall
    make install
}
