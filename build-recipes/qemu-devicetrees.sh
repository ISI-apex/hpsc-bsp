#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=9748e4cc53d3a0748eb54d4fef9e42c8bb880361
export GIT_BRANCH="hpsc"

function do_build()
{
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "BSP" LATEST/SINGLE_ARCH/hpsc-arch.dtb
}
