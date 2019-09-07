#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/arm-trusted-firmware.git"
export GIT_REV=29f510a1179436b648aaf5ce7879e941b3fcf31d
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
