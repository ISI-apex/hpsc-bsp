#!/bin/bash
#
# A meta recipe to construct the HPSC Yocto configuration
#
# Implicitly depends on:
#  poky
#  meta-openembedded
#  meta-hpsc
#

# The only content in our src dir are the sources downloaded in do_late_fetch.
# We don't need/want to copy this large directory to the work dir.
export DO_BUILD_OUT_OF_SOURCE=1

# Builds take a long time, but OpenEmbedded is very good at incremental builds,
# so don't let the build directory be cleaned unless user forces it.
export DO_CLEAN_AFTER_FETCH=0


DL_DIR="${REC_SRC_DIR}/poky_dl"
BUILD_DIR="${REC_WORK_DIR}/poky_build"

POKY_DIR=$(get_dependency_src "ssw/hpps/yocto/poky")
META_OE_DIR=$(get_dependency_src "ssw/hpps/yocto/meta-openembedded")
META_HPSC_DIR=$(get_dependency_src "ssw/hpps/yocto/meta-hpsc")
LAYERS=("${META_OE_DIR}/meta-oe"
        "${META_OE_DIR}/meta-python"
        "${META_HPSC_DIR}/meta-hpsc-bsp")

# test-only recipes must be fetched/built independently of rootfs image
TEST_RECIPES=()

HPSC_YOCTO_INITIALIZED=0
function yocto_maybe_init_env()
{
    if [ $HPSC_YOCTO_INITIALIZED -eq 0 ]; then
        local LAYER_ARGS=()
        for l in "${LAYERS[@]}"; do
            LAYER_ARGS+=("-l" "$l")
        done
        source "${REC_UTIL_DIR}/configure-env.sh" -d "${DL_DIR}" \
                                                  -b "${BUILD_DIR}" \
                                                  -p "${POKY_DIR}" \
                                                  "${LAYER_ARGS[@]}"
        TEST_RECIPES=($("${REC_UTIL_DIR}/find-test-recipes.sh"))
        echo "Found test recipes: (${TEST_RECIPES[*]})"
        HPSC_YOCTO_INITIALIZED=1
    fi
}

function do_late_fetch()
{
    yocto_maybe_init_env
    bitbake core-image-hpsc "${TEST_RECIPES[@]}" --runall="fetch"
    bitbake core-image-hpsc -c populate_sdk --runall="fetch"
    bitbake core-image-hpsc -c testimage --runall="fetch"
}

POKY_DEPLOY_DIR=poky_build/tmp/deploy
POKY_IMAGE_DIR=${POKY_DEPLOY_DIR}/images/hpsc-chiplet

export YOCTO_VERSION=2.6.1 # exported for other recipes
export YOCTO_HPPS_SDK="${REC_ENV_DIR}/yocto-hpps-sdk" # exported for other recipes

POKY_TC_INSTALLER=${POKY_DEPLOY_DIR}/sdk/poky-glibc-x86_64-core-image-hpsc-aarch64-toolchain-${YOCTO_VERSION}.sh

DEPLOY_DIR_1=BSP/hpps
DEPLOY_ARTIFACTS_1=(
    "${POKY_IMAGE_DIR}/arm-trusted-firmware.bin"
    "${POKY_IMAGE_DIR}/u-boot.bin"
    "${POKY_IMAGE_DIR}/hpsc.dtb"
    "${POKY_IMAGE_DIR}/Image.gz"
    "${POKY_IMAGE_DIR}/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot"
)
DEPLOY_DIR_2=toolchains
DEPLOY_ARTIFACTS_2=("$POKY_TC_INSTALLER")

function do_toolchain_uninstall()
{
    rm -rf "$YOCTO_HPPS_SDK"
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    undeploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}

function do_build()
{
    yocto_maybe_init_env
    if [ "$(basename "${PWD}")" != "poky_build" ]; then
        # if yocto env was already init'd then we're still in our work directory
        cd poky_build
    fi
    # subshell is so BB_NO_NETWORK isn't remembered
    (
        echo "Building with BB_NO_NETWORK=1"
        export BB_NO_NETWORK=1
        bitbake core-image-hpsc "${TEST_RECIPES[@]}"
        bitbake core-image-hpsc -c populate_sdk
    )
    cd "$REC_WORK_DIR"
    chmod +x "$POKY_TC_INSTALLER"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR_1" "${DEPLOY_ARTIFACTS_1[@]}"
    deploy_artifacts "$DEPLOY_DIR_2" "${DEPLOY_ARTIFACTS_2[@]}"
}

function do_toolchain_install()
{
    do_toolchain_uninstall # re-install every time
    echo "Installing Yocto HPPS SDK..."
        "$POKY_TC_INSTALLER" <<EOF
$YOCTO_HPPS_SDK
y
EOF
}
