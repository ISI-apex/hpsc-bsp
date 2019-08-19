#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/rtems-tools.git"
export GIT_REV=c55786b47c854f9330c1c8b96d50b96f1994596c
export GIT_BRANCH=hpsc-1.2

export RT_PATH="${REC_ENV_DIR}/RT-5" # exported for other recipes

function do_toolchain_uninstall()
{
    if [ -d "$RT_PATH" ]; then
        ./waf uninstall || rm -rf "$RT_PATH"
    fi
}

function do_build()
{
    ./waf configure --prefix="$RT_PATH"
    ./waf build
}

function do_toolchain_install()
{
    do_toolchain_uninstall # re-install every time
    ./waf install
}
