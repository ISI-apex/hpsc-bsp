#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=4e8a9bf4d9f4af34caeb3e017dc994bbb96d075b
export GIT_BRANCH=hpsc

DEPLOY_DIR=sdk/qemu-devicetrees
DEPLOY_ARTIFACTS=(LATEST/SINGLE_ARCH/hpsc-arch.dts
                  hpsc-busids.dtsh
                  hpsc-irqs.dtsh)

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
