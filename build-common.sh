#!/bin/bash
#
# Build scripts source this file to get build settings.
# Untagged builds are only allowed if HPSC_BUILD_DEVELOPMENT is set.
#
# For fine-grained modifications, developers can edit individual repository
# checkouts below.
#

# Common git tag used for releases - update this in advance of each release
GIT_RELEASE_TAG="hpsc-2.0"

# Uncomment or set in environment to perform a development (not a release) build
# HPSC_BUILD_DEVELOPMENT=1

#
# Toolchain paths - can be overridden by environment
#

export GCC_ARM_NONE_EABI_BINDIR=${GCC_ARM_NONE_EABI_BINDIR:-"${PWD}/../gcc-arm-none-eabi-7-2018-q2-update/bin"}
export POKY_SDK_AARCH64_PATH=${POKY_SDK_AARCH64_PATH:-"/opt/poky/2.3.4/sysroots/x86_64-pokysdk-linux/usr/bin/aarch64-poky-linux"}
export POKY_SDK_AARCH64_SYSROOT=${POKY_SDK_AARCH64_SYSROOT:-"/opt/poky/2.3.4/sysroots/aarch64-poky-linux"}

#
# Set git revisions to use
#

if [ -n "$HPSC_BUILD_DEVELOPMENT" ]; then
    # Anything goes - read from the environment, otherwise use the latest
    export GIT_CHECKOUT_DEFAULT=${GIT_CHECKOUT_DEFAULT:-"hpsc"}
    export SRCREV_DEFAULT=${SRCREV_DEFAULT:-"\${AUTOREV}"}
    echo ""
    echo "Performing development build:"
    echo "  GIT_CHECKOUT_DEFAULT = $GIT_CHECKOUT_DEFAULT"
    echo "  SRCREV_DEFAULT = $SRCREV_DEFAULT"
    echo ""
else
    # Force git revisions for release
    export GIT_CHECKOUT_DEFAULT="$GIT_RELEASE_TAG"
    export SRCREV_DEFAULT="$GIT_RELEASE_TAG"
    echo ""
    echo "Performing release build:"
    echo "  GIT_RELEASE_TAG = $GIT_RELEASE_TAG"
    echo ""
fi

#
# If you need to pick specific revisions for individual repositories, edit the
# values below.
# In general, such changes should NOT be committed!
#

# Repositories used for poky and its layer configuration
export GIT_CHECKOUT_POKY="$GIT_CHECKOUT_DEFAULT"
export GIT_CHECKOUT_META_OE="$GIT_CHECKOUT_DEFAULT"
export GIT_CHECKOUT_META_HPSC="$GIT_CHECKOUT_DEFAULT"

# HPSC repositories built by poky
# The following SRCREV_* env vars specify the commit hash or tag
# (e.g. 'hpsc-0.9') that will be checked out for each repository.
# Specify "\${AUTOREV}" to pull and  check out the head of the hpsc branch.
export SRCREV_atf="$SRCREV_DEFAULT"
export SRCREV_linux_hpsc="$SRCREV_DEFAULT"
export SRCREV_qemu_devicetrees="$SRCREV_DEFAULT"
export SRCREV_qemu="$SRCREV_DEFAULT"
export SRCREV_u_boot="$SRCREV_DEFAULT"

# Repositories not built by poky
export GIT_CHECKOUT_BM="$GIT_CHECKOUT_DEFAULT"
export GIT_CHECKOUT_UBOOT_R52="$GIT_CHECKOUT_DEFAULT"
export GIT_CHECKOUT_HPSC_UTILS="$GIT_CHECKOUT_DEFAULT"
# Building qemu outside poky is a (temporary?) workaround for some issues
export GIT_CHECKOUT_QEMU="$GIT_CHECKOUT_DEFAULT"
export GIT_CHECKOUT_QEMU_DT="$GIT_CHECKOUT_DEFAULT"

#
# Some common functions
#

# Clone repository if not already done, always pull
function git_clone_pull()
{
    local repo=$1
    local dir=$2
    # Don't ask for credentials if requests are bad
    export GIT_TERMINAL_PROMPT=0 # for git > 2.3
    export GIT_ASKPASS=/bin/echo
    echo "Pulling repository: $repo"
    if [ ! -d "$dir" ]; then
        git clone "$repo" "$dir" || return $?
    fi
    cd "$dir"
    git pull
    RC=$?
    cd - > /dev/null
    return $RC
}

# Assert that a string is not empty
function assert_str()
{
    if [ -z "$1" ]; then
        echo "String assertion failed!"
        exit 1
    fi
}
