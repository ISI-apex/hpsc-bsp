#!/bin/bash
#
# Upgrade all managed BSP recipes
#
set -e

RECIPES=(
    arm-trusted-firmware-rtps-a53
    # ENV # parent recipe
    # gcc-arm-none-eabi # not from a git repo, managed manually
    hpsc-baremetal
    # hpsc-eclipse # not from a git repo, managed manually
    hpsc-rtems-rtps-r52
    hpsc-utils
    # hpsc-yocto-hpps # meta recipe
    meta-hpsc
    # meta-openembedded # using upstream, managed manually
    # poky # using upstream, managed manually
    qemu-devicetrees
    qemu
    rtems-rtps-r52
    rtems-source-builder
    rtems-tools
    u-boot-rtps-a53
    u-boot-rtps-r52
)

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if ! git diff-index --cached --quiet HEAD --; then
    echo "Repository has staged changes, cannot proceed"
    exit 1
fi

for rec in "${RECIPES[@]}"; do
    echo "Upgrading BSP recipe: $rec"
    # -r may not be overriden in $@
    "${THIS_DIR}/upgrade-recipe-bsp.sh" "$@" -r "$rec"
done
