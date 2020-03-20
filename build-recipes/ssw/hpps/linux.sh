#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/linux-hpsc.git"
export GIT_REV=3f0a594e339cb7114f1c1667379b3f21cebd9492
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
