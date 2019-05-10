#!/bin/bash
#
# Upgrade all custom Yocto recipes in the meta-hpsc layer
#
set -e

LAYBRANCH=hpsc
RECIPES=(
    ssw/hpps/arm-trusted-firmware
    ssw/hpps/u-boot
    ssw/hpps/linux # linux takes awhile to upgrade (lots of native dependencies)
    ssw/hpsc-utils
)

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

for rec in "${RECIPES[@]}"; do
    echo "Upgrading Yocto recipe: $rec"
    # -B may be overriden in $@, but not -r
    "${THIS_DIR}/upgrade-recipe-yocto.sh" -B "$LAYBRANCH" "$@" -r "$rec"
done
