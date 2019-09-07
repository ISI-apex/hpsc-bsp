#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=f6157b3aa18f8b8046d30044afc89db5a402805f
export GIT_BRANCH=hpsc

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
