#!/bin/bash

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("sdk/qemu"
         "sdk/qemu-devicetrees"
         "sdk/hpsc-sdk-tools"
         "sdk/hpsc-eclipse")

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@"
done
