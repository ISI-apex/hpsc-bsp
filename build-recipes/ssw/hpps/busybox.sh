#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/busybox.git"
export GIT_REV=39c03aff68b726458265df7b32376dfa6267927a
export GIT_BRANCH="hpsc"

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
