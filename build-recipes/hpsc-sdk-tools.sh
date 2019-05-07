#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-sdk-tools"
export GIT_REV=119f1b330db20b73715d7375e459b4e97d8d7d02
export GIT_BRANCH="hpsc"

DEPLOY_DIR_1=BSP/host-utils
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
