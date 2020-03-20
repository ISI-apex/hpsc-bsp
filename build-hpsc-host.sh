#!/bin/bash

# The recipes managed by this script
RECIPES=("bsp"
         "sdk/qemu"
         "sdk/qemu-devicetrees"
         "sdk/rtems-tools"
         "sdk/rtems-source-builder"
         "sdk/hpsc-sdk-tools"
         "sdk/hpsc-eclipse")

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@" || exit $?
done
