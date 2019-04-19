#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/rtems-tools.git"
export GIT_REV=cdfafce46499283b5c9bc9348021d23359387dc0
export GIT_BRANCH="hpsc-1.1"

export RT_PATH="${REC_ENV_DIR}/RT-5" # exported for other recipes
function do_build()
{
    ./waf configure --prefix="$RT_PATH"
    ./waf build
}

function do_toolchain_install()
{
    if [ -d "$RT_PATH" ]; then
        ./waf uninstall || rm -rf "$RT_PATH"
    fi
    ./waf install
}
