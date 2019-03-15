#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_REV=bf769b15a3251b52678b859d331441685fc55078
export GIT_BRANCH="hpsc"

function do_build()
{
    make_parallel
}

function do_deploy()
{
    deploy_artifacts "BSP" LATEST/SINGLE_ARCH/hpsc-arch.dtb
}
