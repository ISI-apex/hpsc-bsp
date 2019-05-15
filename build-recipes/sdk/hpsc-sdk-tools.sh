#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-sdk-tools"
export GIT_REV=ad7837f59e40ea2445fb70e2737a574baa58410d
export GIT_BRANCH="hpsc"

DEPLOY_DIR_1=sdk/tools
DEPLOY_ARTIFACTS_1=(
    bin/qemu-ifup.sh
    bin/qmp.py
    bin/cfgc
    bin/mkmemimg
    bin/qemu-nand-creator
    bin/sram-image-utils
    bin/merge-env
    bin/merge-map
    bin/merge-ini
    bin/launch-qemu
    bin/hpsc-objcopy
    bin/memstripe
    bin/miniconfig.sh
    bin/qemu-chardev-ptys
    bin/qmp-mem-wait
)

function do_fetch()
{
    env_git_clone_fetch_checkout "$GIT_REPO" . "$GIT_REV"
    make -C .. -f hpsc-sdk-tools/make/Makefile.sdk fetch
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}

function do_build()
{
    make_parallel -C bin
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}
