#!/bin/bash

# The recipes managed by this script
RECIPES=("ssw/trch/rtems"
         "ssw/rtps/r52/rtems"
         "ssw/rtps/r52/hpsc-rtems")

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@" || exit $?
done
