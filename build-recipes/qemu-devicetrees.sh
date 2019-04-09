#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=8c98c46ba0050cd274bc50a7bbe697e650cefed7
export GIT_BRANCH="hpsc"

function do_build()
{
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "BSP" LATEST/SINGLE_ARCH/hpsc-arch.dtb
}
