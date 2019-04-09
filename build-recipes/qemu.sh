#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu.git"
export GIT_REV=406c351cd19cb38c2ce83e4d4c87b9832d431cb5
export GIT_BRANCH="hpsc"

export DO_BUILD_OUT_OF_SOURCE=1

function do_post_fetch()
{
    # Fetches submodules, which requires internet
    # We only know which submodules are used b/c we've run configure before...
    ./scripts/git-submodule.sh update ui/keycodemapdb dtc capstone
}

function do_build()
{
    mkdir -p build
    (
        cd build
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
    deploy_artifacts "BSP" build/_install/bin/qemu-system-aarch64 \
                           build/_install/libexec/qemu-bridge-helper
}
