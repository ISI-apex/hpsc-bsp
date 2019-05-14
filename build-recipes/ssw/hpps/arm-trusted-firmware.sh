#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/arm-trusted-firmware.git"
export GIT_REV=6adac3282c549bfae08f1ac0269b977fdef3730b
export GIT_BRANCH="hpsc"

export DO_FETCH_ONLY=1

function do_build()
{
    echo "Not currently building this recipe for binary release."
}
