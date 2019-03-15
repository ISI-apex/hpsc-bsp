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

POKY_DIR=$(get_dependency_src "poky")
META_OE_DIR=$(get_dependency_src "meta-openembedded")
META_HPSC_DIR=$(get_dependency_src "meta-hpsc")
LAYERS=("${META_OE_DIR}/meta-oe"
        "${META_OE_DIR}/meta-python"
        "${META_HPSC_DIR}/meta-hpsc-bsp")

function yocto_setup()
{
    local LAYER_ARGS=()
    for l in "${LAYERS[@]}"; do
        LAYER_ARGS+=("-l" "$l")
    done
    source "${REC_UTIL_DIR}/configure-env.sh" -d "${DL_DIR}" -b "${BUILD_DIR}" \
                                              -p "${POKY_DIR}" "${LAYER_ARGS[@]}"
}

# test-only recipes must be fetched/built independently of rootfs image
TEST_RECIPES=()
# Parse test module JSON file to get its recipe dependencies
function get_json_dependent_recipes()
{
    python -c "import sys, json
json = json.load(sys.stdin)
print '\n'.join([json[j]['pkg'] for j in json])" < "$1"
}
# Search layer for test module JSON files
function find_layer_test_mod_jsons()
{
    # per Yocto documentation, test cases always in: lib/oeqa/runtime/cases
    local tcdir="$1/lib/oeqa/runtime/cases"
    if test -d "$tcdir"; then
        find "$tcdir" -maxdepth 1 -name "*.json"
    fi
}
# Search layer for JSON-specified test dependencies
function find_layer_test_recipes_for_suites()
{
    local laydir=$1
    shift
    # grep expression replaces "suite1 suite2 ..." with "suite1|suite2|..." so
    # JSONS only matches specified test modules
    # NOTE: assumes no newline characters or leading/trailing whitespace
    local suite_e=$(echo "$*" | tr "[:blank:]" "|")
    if [ -z "$(echo "$suite_e" | tr -d "|")" ]; then
        # no test modules (or specified as empty string or whitespace) causes
        # function to match on all JSON files when we actually want to filter
        return 
    fi
    local JSONS=($(find_layer_test_mod_jsons "$laydir" | grep -E "$suite_e"))
    local RECIPES=()
    for f in "${JSONS[@]}"; do
        RECIPES+=($(get_json_dependent_recipes "$f"))
    done
    echo "${RECIPES[@]}" # note: may contain duplicate entries
}
function yocto_get_test_recipes()
{
    local TEST_SUITES=($(grep TEST_SUITES conf/local.conf | cut -d'=' -f2- | tr -d '"' | xargs))
    echo "Found test suites: (${TEST_SUITES[*]})"
    local LAYERS=($(bitbake-layers show-layers | tail -n +4 | awk '{print $2}'))
    local TRS=()
    for l in "${LAYERS[@]}"; do
        TRS+=($(find_layer_test_recipes_for_suites "$l" "${TEST_SUITES[@]}"))
    done
    # filter duplicate entries
    TEST_RECIPES=($(echo "${TRS[@]}" | tr ' ' '\n' | sort -u))
    echo "Found test recipes: (${TEST_RECIPES[*]})"
}

HPSC_YOCTO_INITIALIZED=0
function yocto_maybe_init_env()
{
    if [ $HPSC_YOCTO_INITIALIZED -eq 0 ]; then
        yocto_setup
        yocto_get_test_recipes
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

function do_build()
{
    yocto_maybe_init_env
    # subshell is so BB_NO_NETWORK isn't remembered
    (
        echo "Building with BB_NO_NETWORK=1"
        export BB_NO_NETWORK=1
        bitbake core-image-hpsc "${TEST_RECIPES[@]}"
        bitbake core-image-hpsc -c populate_sdk
    )
}

function do_deploy()
{
    local deploy_dir=poky_build/tmp/deploy
    local image_dir=${deploy_dir}/images/hpsc-chiplet
    deploy_artifacts BSP/hpps "${image_dir}/arm-trusted-firmware.bin" \
                              "${image_dir}/u-boot.bin" \
                              "${image_dir}/hpsc.dtb" \
                              "${image_dir}/Image.gz" \
                              "${image_dir}/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot"
    deploy_artifacts toolchains "${deploy_dir}/sdk/poky-glibc-x86_64-core-image-hpsc-aarch64-toolchain-2.6.sh"
}
