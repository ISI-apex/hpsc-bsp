#!/bin/bash

# Fail-fast
set -e

# The recipes managed by this script
RECIPES=("sdk/qemu"
         "sdk/qemu-devicetrees"
         "sdk/hpsc-sdk-tools"
         "sdk/hpsc-eclipse")

for rec in "${RECIPES[@]}"; do
    ./build-recipe.sh -r "$rec" "$@"
done
