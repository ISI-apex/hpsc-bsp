#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=7e1400d8056ff617cbbaa361247c693d157cc68b
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="hpsc-yocto-hpps" # exports YOCTO_HPPS_SDK

DEPLOY_DIR_1=BSP/aarch64-poky-linux-utils
DEPLOY_ARTIFACTS_1=(
    test/linux/mboxtester
    test/linux/rtit-tester
    test/linux/shm-standalone-tester
    test/linux/shm-tester
    test/linux/wdtester
)

DEPLOY_DIR_2=BSP/ssw-conf
DEPLOY_ARTIFACTS_2=(
    conf/base/trch/syscfg-schema.json
)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    undeploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}

function do_build()
{
    (
        echo "hpsc-utils: build"
        echo "hpsc-utils: source poky environment"
        ENV_check_yocto_hpps_sdk
        source "${YOCTO_HPPS_SDK}/environment-setup-aarch64-poky-linux"
        unset LDFLAGS
        make_parallel -C "test/linux"
    )
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    deploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}
