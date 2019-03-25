#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/rtems-tools.git"
export GIT_REV=391ad5c67ff1bc1249514f319469bd6994045779
export GIT_BRANCH="hpsc"

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
