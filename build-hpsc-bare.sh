#!/bin/bash

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("sdk/gcc-arm-none-eabi"
         "ssw/hpsc-baremetal"
         "ssw/rtps/a53/arm-trusted-firmware"
         "ssw/rtps/a53/u-boot"
         "ssw/rtps/r52/u-boot")

for rec in "${RECIPES[@]}"; do
    ./build-recipe.sh -r "$rec" "$@"
done
