#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=ac7563be74f27d95dca3b5ae848745e1206128f7
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
