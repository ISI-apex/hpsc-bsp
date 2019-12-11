#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=6ddb4ffe6950ac8987a3daffeff0936d1c2932e2
export GIT_BRANCH=hpsc

DEPLOY_DIR_1=ssw/tests
DEPLOY_ARTIFACTS_1=(
    test/pytest/README.md
    test/pytest/conftest.py
    test/pytest/measure_load.py
    test/pytest/test_dma.py
    test/pytest/test_interrupt_affinity.py
    test/pytest/test_mbox.py
    test/pytest/test_nand.py
    test/pytest/test_parallel_scaling.py
    test/pytest/test_shm.py
    test/pytest/test_sram.py
    test/pytest/test_timer_interrupt.py
    test/pytest/test_wdt.py
)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
}
