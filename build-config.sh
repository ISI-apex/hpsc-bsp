#!/bin/bash
#
# Build scripts use this file to get build configurations.
#
# Note: poky (and its layers) specify its own set of transitive dependencies.
# To configure its HPSC-modified repositories, update recipes in meta-hpsc.
#

#
# Repositories for poky and its layers
#

export GIT_URL_POKY="https://git.yoctoproject.org/git/poky"
export GIT_CHECKOUT_POKY="thud-20.0.0" # tag

# meta-oe doesn't tag releases - choose a known revision on "thud" branch
export GIT_URL_META_OE="https://github.com/openembedded/meta-openembedded.git"
export GIT_CHECKOUT_META_OE="6094ae18c8a35e5cc9998ac39869390d7f3bb1e2"

export GIT_URL_META_HPSC="https://github.com/ISI-apex/meta-hpsc"
export GIT_CHECKOUT_META_HPSC="e6a813764eb6341a546eb14e22ad19f49f10f39e"

#
# Repositories not built by poky
#

export GIT_URL_BM="https://github.com/ISI-apex/hpsc-baremetal.git"
export GIT_CHECKOUT_BM="111a30b662bd807972696bf5a5bc99637cc8a26b"

# ATF also built by yocto (set revision in meta-hpsc)
export GIT_URL_ATF="https://github.com/ISI-apex/arm-trusted-firmware.git"
export GIT_CHECKOUT_ATF_A53="5c1a87f3b606ac2bc60b3c9d243c6c15ba55a967"

# u-boot also built by yocto (set revision in meta-hpsc)
export GIT_URL_UBOOT="https://github.com/ISI-apex/u-boot.git"
export GIT_CHECKOUT_UBOOT_R52="72d0ce6eee1012b5a3c59028b8af66e69c45f83e"
export GIT_CHECKOUT_UBOOT_A53="72d0ce6eee1012b5a3c59028b8af66e69c45f83e"

export GIT_URL_HPSC_UTILS="https://github.com/ISI-apex/hpsc-utils.git"
export GIT_CHECKOUT_HPSC_UTILS="6312ada9b1a11e8115e633e42f62179d4abf9dba"

export GIT_URL_QEMU="https://github.com/ISI-apex/qemu.git"
export GIT_CHECKOUT_QEMU="067d63ef09394fcafe5e5919a923b1800a146737"

export GIT_URL_QEMU_DT="https://github.com/ISI-apex/qemu-devicetrees.git"
export GIT_CHECKOUT_QEMU_DT="371f3116a014431fd8b4f6079bc740e7aaa499ce"
