#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/linux-hpsc.git"
export GIT_REV=c43bb3f680fd4fdafdf9183570847dc3b950cc04
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
