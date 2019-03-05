#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=6312ada9b1a11e8115e633e42f62179d4abf9dba
export GIT_BRANCH="hpsc"

function do_build()
{
    for s in host linux; do
        (
            echo "hpsc-utils: $s: build"
            if [ "$s" == "linux" ]; then
                echo "hpsc-utils: source poky environment"
                . "${POKY_SDK}/environment-setup-aarch64-poky-linux"
                unset LDFLAGS
            fi
            make_parallel -C "$s"
        )
    done
}
