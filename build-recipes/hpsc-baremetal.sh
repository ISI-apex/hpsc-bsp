#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=80e21f5a3f7a9c0388d708bc55c4eb4d85fc6c5c
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="gcc-arm-none-eabi"

DEPLOY_DIR=BSP/trch
DEPLOY_ARTIFACTS=(trch/bld/trch.elf)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    ENV_check_bm_toolchain
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
