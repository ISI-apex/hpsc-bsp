#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-sdk-tools"
export GIT_REV=880435d8b4c8a77fdcdcb89cc1e0016f396a6238
export GIT_BRANCH=hpsc

DEPLOY_DIR_1=sdk/tools
DEPLOY_ARTIFACTS_1=(
    bin/cfgc
    bin/expandvars
    bin/inicfg.py
    bin/launch-qemu
    bin/memmap.py
    bin/mkmemimg
    bin/merge-env
    bin/merge-map
    bin/merge-ini
    bin/mksfs
    bin/numparse.py
    bin/qemu-chardev-ptys
    bin/qemu-ifup.sh
    bin/qemu-preload-mem
    bin/qmp-cmd
    bin/qmp.py
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
