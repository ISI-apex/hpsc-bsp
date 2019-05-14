#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=70d292bc58e880a4e80d2b6bcc1797e9ae320d19
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="sdk/gcc-arm-none-eabi"

DEPLOY_DIR=ssw/trch
DEPLOY_ARTIFACTS=(
    trch/bld/trch.elf
    trch/syscfg-schema.json
)

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
