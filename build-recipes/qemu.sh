#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu.git"
export GIT_REV=067d63ef09394fcafe5e5919a923b1800a146737
export GIT_BRANCH="hpsc"

function do_post_fetch()
{
    # Fetches submodules, which requires internet
    # We only know which submodules are used b/c we've run configure before...
    ./scripts/git-submodule.sh update ui/keycodemapdb dtc capstone
}

function do_build()
{
    mkdir -p BUILD
    cd BUILD
    ../configure --target-list="aarch64-softmmu" --enable-fdt \
                 --disable-kvm --disable-xen
    make_parallel
}

function do_test()
{
    make_parallel -C BUILD check-unit
}
