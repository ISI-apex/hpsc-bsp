#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=61acbf9c923a8df1cda6dc8e8884e00ac83edea8
export GIT_BRANCH=hpsc

DEPLOY_DIR_1=ssw/tests
DEPLOY_ARTIFACTS_1=(
    test/pytest/README.md
    test/pytest/buildspec.yml
    test/pytest/conftest.py
    test/pytest/measure_load.py
    test/pytest/test_devices.py
)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}
