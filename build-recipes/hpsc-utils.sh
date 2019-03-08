#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=5d259ecb960a4acf7dd950bfe1fb1ea423c86a73
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
