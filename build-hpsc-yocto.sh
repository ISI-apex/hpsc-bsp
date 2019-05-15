#!/bin/bash

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("ssw/hpps/yocto/poky"
         "ssw/hpps/yocto/meta-openembedded"
         "ssw/hpps/yocto/meta-hpsc"
         "ssw/hpps/yocto"
         "ssw/hpps/arm-trusted-firmware"
         "ssw/hpps/busybox"
         "ssw/hpps/linux"
         "ssw/hpps/u-boot"
         "ssw/hpsc-utils")

for rec in "${RECIPES[@]}"; do
    ./build-recipe.sh -r "$rec" "$@"
done
