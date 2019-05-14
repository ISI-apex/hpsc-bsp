#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/u-boot.git"
export GIT_REV=412039ff0b1633b30bb4e1552b988ff58452554d
export GIT_BRANCH="hpsc"

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
