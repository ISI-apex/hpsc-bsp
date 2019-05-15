#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=7be33769c2204a1d76af470327fe96fce755a320
export GIT_BRANCH="hpsc"

DEPLOY_DIR=sdk
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
