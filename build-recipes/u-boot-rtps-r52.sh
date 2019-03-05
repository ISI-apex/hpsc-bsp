#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/u-boot.git"
export GIT_REV=72d0ce6eee1012b5a3c59028b8af66e69c45f83e
export GIT_BRANCH="hpsc"

function do_build()
{
    make hpsc_rtps_r52_defconfig
    make_parallel CROSS_COMPILE=arm-none-eabi-
}
