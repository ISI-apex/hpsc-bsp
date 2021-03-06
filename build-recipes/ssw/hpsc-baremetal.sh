#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=cf524d2718f840ac2e6dd22e1b08b85a1c4948f6
export GIT_BRANCH=hpsc

export DEPENDS_ENVIRONMENT="sdk/gcc-arm-none-eabi"

DEPLOY_DIR=ssw/trch
DEPLOY_ARTIFACTS=(
    trch/bld/trch.bin
    trch/syscfg-schema.json
)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    ENV_check_bm_toolchain || return $?
    make_parallel CROSS_COMPILE=arm-none-eabi-
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
