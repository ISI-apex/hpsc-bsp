#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/linux-hpsc.git"
export GIT_REV=08bd4b75dddeaa8fb41aee4720938cc0da317b0e
export GIT_BRANCH="hpsc"

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
