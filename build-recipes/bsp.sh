#!/bin/bash
# Deploy local BSP artifacts

export DO_FETCH_ONLY=1

DEPLOY_DIR_1=""
DEPLOY_ARTIFACTS_1=(
    "${REC_UTIL_DIR}/checkout.sh"
    "${REC_UTIL_DIR}/run-qemu.sh"
    "${REC_UTIL_DIR}/test.sh"
    "${REC_UTIL_DIR}/qemu-env.sh"
)
DEPLOY_DIR_2="conf"
DEPLOY_ARTIFACTS_2=("${REC_UTIL_DIR}"/conf/*)

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    undeploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    deploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}
