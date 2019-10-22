#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-sdk-tools"
export GIT_REV=9271dd54120ffd308907732e3878a0f58c31fafd 
export GIT_BRANCH=hpsc

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
    bin/qmp-cmd
)

function do_post_fetch()
{
    make -C .. -f "${REC_SRC_DIR}/make/Makefile.sdk" fetch
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
