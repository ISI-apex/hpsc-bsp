#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=44d8948148fa2dcafe2313c79fb6c92aa3bed250
export GIT_BRANCH="hpsc"

# Note: this should be a reference to sdk/; need to split yocto build into
# the SDK part (the cross compiler) and the SW part.
export DEPENDS_ENVIRONMENT="ssw/hpps/yocto" # exports YOCTO_HPPS_SDK

DEPLOY_DIR_1=ssw/hpps/tests
DEPLOY_ARTIFACTS_1=(
    test/linux/mboxtester
    test/linux/rtit-tester
    test/linux/shm-standalone-tester
    test/linux/shm-tester
    test/linux/wdtester
)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
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
}
