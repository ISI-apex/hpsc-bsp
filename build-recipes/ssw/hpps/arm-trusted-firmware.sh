#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/arm-trusted-firmware.git"
export GIT_REV=a7bb92cd4d8b62c75a9374451d8d2cdcd83f3a1e
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
