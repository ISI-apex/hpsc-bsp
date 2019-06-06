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

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@"
done
