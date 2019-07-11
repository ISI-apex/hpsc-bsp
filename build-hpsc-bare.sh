#!/bin/bash

# The recipes managed by this script
RECIPES=("sdk/gcc-arm-none-eabi"
         "ssw/hpsc-baremetal"
         "ssw/rtps/a53/arm-trusted-firmware"
         "ssw/rtps/a53/u-boot"
         "ssw/rtps/r52/u-boot")

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@" || exit $?
done
