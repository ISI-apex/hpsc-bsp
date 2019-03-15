#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu.git"
export GIT_REV=91e0c3c44f7c95775c31919b55e0d3c43bae26ef
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
    cd build
    "${REC_SRC_DIR}/configure" --target-list="aarch64-softmmu" \
                               --prefix="${PWD}/_install" \
                               --enable-fdt --disable-kvm --disable-xen
    make_parallel
    make_parallel install
}

function do_test()
{
    make_parallel -C build check-unit
}
