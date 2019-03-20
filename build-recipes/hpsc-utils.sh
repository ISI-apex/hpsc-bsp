#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_REV=5d259ecb960a4acf7dd950bfe1fb1ea423c86a73
export GIT_BRANCH="hpsc"

export DEPENDS_ENVIRONMENT="hpsc-yocto-hpps" # exports YOCTO_HPPS_SDK

function do_build()
{
    for s in host linux; do
        (
            echo "hpsc-utils: $s: build"
            if [ "$s" == "linux" ]; then
                echo "hpsc-utils: source poky environment"
                ENV_check_yocto_hpps_sdk
                source "${YOCTO_HPPS_SDK}/environment-setup-aarch64-poky-linux"
                unset LDFLAGS
            fi
            make_parallel -C "$s"
        )
    done
}

function do_deploy()
{
    deploy_artifacts BSP/host-utils host/qemu-nand-creator \
                                    host/sram-image-utils
    deploy_artifacts BSP/aarch64-poky-linux-utils linux/mboxtester \
                                                  linux/rtit-tester \
                                                  linux/shm-standalone-tester \
                                                  linux/shm-tester \
                                                  linux/wdtester
}
