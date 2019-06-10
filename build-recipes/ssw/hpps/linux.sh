#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/linux-hpsc.git"
export GIT_REV=6964cd371ec788e906d71f634a4deed76d0951ec
export GIT_BRANCH="hpsc"

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
