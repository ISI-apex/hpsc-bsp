#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=04a7eb8001a651cf0e82594baa00418453303439
export GIT_BRANCH="hpsc"

function do_build()
{
    make_parallel
}

function do_deploy()
{
    deploy_artifacts BSP/rtps-r52 rtps/bld/rtps.uimg
    deploy_artifacts BSP/trch trch/bld/trch.elf
}
