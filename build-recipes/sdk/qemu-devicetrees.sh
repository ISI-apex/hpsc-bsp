#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=d927e5889b06a3f4e53a0f57c99a0041e5973050
export GIT_BRANCH="hpsc"

DEPLOY_DIR=BSP
DEPLOY_ARTIFACTS=(LATEST/SINGLE_ARCH/hpsc-arch.dtb)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
