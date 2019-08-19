#!/bin/bash
#
# Depends on:
#  sdk/rtems-source-builder
#  ssw/rtps/r52/rtems
#

export GIT_REPO="https://github.com/ISI-apex/hpsc-rtems.git"
export GIT_REV=dedc698be539a004c8413f7c5e7ad4204b107855
export GIT_BRANCH=hpsc

# exports PATH, RTEMS_RTPS_R52_BSP, and RTEMS_MAKEFILE_PATH
export DEPENDS_ENVIRONMENT="sdk/rtems-source-builder:ssw/rtps/r52/rtems"

DEPLOY_DIR=ssw/rtps/r52
DEPLOY_ARTIFACTS=(rtps-r52/o-optimize/rtps-r52.img)

function do_toolchain_uninstall()
{
    # RTEMS builds don't provide an "uninstall" goal...
    # delete old binaries, libraries, and headers (in case some were removed)
    # reliable as long as the project sticks to its libhpsc* naming convention
    rm -f "${RTEMS_RTPS_R52_BSP}"/bin/rtps-r52.{img,exe}
    rm -f "${RTEMS_RTPS_R52_BSP}"/arm-rtems5/gen_r52_qemu/lib/libhpsc*.a
    rm -rf "${RTEMS_RTPS_R52_BSP}"/arm-rtems5/gen_r52_qemu/lib/include/hpsc*
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    ENV_check_rsb_toolchain || return $?
    ENV_check_rtems_r52_sdk || return $?
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_toolchain_install()
{
    make install
}
