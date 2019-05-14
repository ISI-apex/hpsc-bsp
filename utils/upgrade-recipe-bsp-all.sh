#!/bin/bash
#
# Upgrade all managed BSP recipes
#
set -e

RECIPES=(
    # ENV # parent recipe
    # sdk/gcc-arm-none-eabi # not from a git repo, managed manually
    # sdk/hpsc-eclipse # not from a git repo, managed manually
    sdk/hpsc-sdk-tools
    sdk/qemu
    sdk/qemu-devicetrees
    sdk/rtems-source-builder
    sdk/rtems-tools
    ssw/hpps/arm-trusted-firmware
    ssw/hpps/busybox
    ssw/hpps/linux
    ssw/hpps/u-boot
    # ssw/hpps/yocto # meta recipe
    ssw/hpps/yocto/meta-hpsc
    # ssw/hpps/yocto/meta-openembedded # using upstream, managed manually
    # ssw/hpps/yocto/poky # using upstream, managed manually
    ssw/hpsc-baremetal
    ssw/hpsc-utils
    ssw/rtps/a53/arm-trusted-firmware
    ssw/rtps/a53/u-boot
    ssw/rtps/r52/hpsc-rtems
    ssw/rtps/r52/rtems
    ssw/rtps/r52/u-boot
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
