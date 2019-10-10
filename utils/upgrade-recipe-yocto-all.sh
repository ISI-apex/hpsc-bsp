#!/bin/bash
#
# Upgrade all custom Yocto recipes in the meta-hpsc layer
#

LAYBRANCH=hpsc

# recipe names from yocto layers
RECIPES=(
    arm-trusted-firmware
    u-boot-hpps
    linux-hpsc # linux takes awhile to upgrade (lots of native dependencies)
    hpsc-utils
)

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

for rec in "${RECIPES[@]}"; do
    echo "Upgrading Yocto recipe: $rec"
    # -B may be overriden in $@, but not -r
    "${THIS_DIR}/upgrade-recipe-yocto.sh" -O origin -B "$LAYBRANCH" "$@" -r "$rec" || \
    	exit $?
done
