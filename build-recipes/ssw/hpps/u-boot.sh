#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/u-boot.git"
export GIT_REV=79df69589d9049872485d68c194fc7c0baeabd6d
export GIT_BRANCH=hpsc

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
