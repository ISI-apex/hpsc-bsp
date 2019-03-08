#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_REV=04a7eb8001a651cf0e82594baa00418453303439
export GIT_BRANCH="hpsc"

function do_build()
{
    make_parallel
}
