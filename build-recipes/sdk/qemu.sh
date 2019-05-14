#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu.git"
export GIT_REV=c90967ad135087cc68087edca16acd3dc582c3ef
export GIT_BRANCH="hpsc"

export DO_BUILD_OUT_OF_SOURCE=1

DEPLOY_DIR=sdk
DEPLOY_ARTIFACTS=(
    build/_install/bin/qemu-system-aarch64
    build/_install/libexec/qemu-bridge-helper
)

function do_post_fetch()
{
    # Fetches submodules, which requires internet
    # We only know which submodules are used b/c we've run configure before...
    ./scripts/git-submodule.sh update ui/keycodemapdb dtc capstone
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    mkdir -p build
    (
        cd build
        # Clusters: TRCH = 0, RTPS R52 = 1, RTPS A53 = 2, HPPS = 3
        export CFLAGS="${CFLAGS} -DGDB_TARGET_CLUSTER=1 "
        "${REC_SRC_DIR}/configure" --target-list="aarch64-softmmu" \
                                   --prefix="${PWD}/_install" \
                                   --enable-fdt --disable-kvm --disable-xen
        make_parallel
        make_parallel install
    )
}

function do_test()
{
    make_parallel -C build check-unit
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
