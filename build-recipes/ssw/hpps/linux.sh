#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/linux-hpsc.git"
export GIT_REV=8b6042ae1e00d0a382aaf8e64ca30edf9c02099d
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
