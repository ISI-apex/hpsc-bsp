#!/bin/bash

# The recipes managed by this script
RECIPES=("ssw/hpps/baretest")

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
for rec in "${RECIPES[@]}"; do
    "${BSP_DIR}/build-recipe.sh" -r "$rec" "$@" || exit $?
done
