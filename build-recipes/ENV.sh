#!/bin/bash
#
# The point of having this templated build infrastructure is that it makes it
# it easier to automate some tasks, both for the build scripts and for users
# or CI tools to update.
#
# All recipes extend this script, so may (and sometimes must) override variables
# and functions.
#
# Global variables accessible to recipes are:
#  REC_UTIL_DIR: the recipe's utility directory (for content not kept in recipe)
#  REC_SRC_DIR: the recipe's source directory
#  REC_WORK_DIR: the recipe's work directory (where builds are performed)
#  REC_ENV_DIR: the recipe's target directory for installing toolchains
# The following variables should only be used by functions in this file:
#  ENV_WORKING_DIR: the parent directory
#  ENV_DEPLOY_DIR: the deploy directory
#

#
# Recipes override the GIT or WGET configurations (GIT takes precedence).
# If GIT_REPO and WGET_URL are both empty, the recipe is a "meta" recipe and 
# should probably tie together other recipes instead (e.g., those with
# DO_FETCH_ONLY=1 as described below).
#

export GIT_REPO=""
export GIT_REV=""
export GIT_BRANCH=""

export WGET_URL=""
export WGET_OUTPUT=""
export WGET_OUTPUT_MD5=""

# Some recipes may only provide sources (e.g., and are used by meta recipes).
# Functions do_fetch and do_post_fetch will be executed, but not do_late_fetch,
# do_build, or do_test.
# Functions do_deploy and do_toolchain_install are executed, but in REC_SRC_DIR
# rather than REC_WORK_DIR.
export DO_FETCH_ONLY=0

# When out of source, REC_SRC_DIR isn't automatically copied to REC_WORK_DIR.
# Instead, an empty work directory is created.
export DO_BUILD_OUT_OF_SOURCE=0

# By default, REC_WORK_DIR is cleaned after fetch, but recipes can override.
# This capability is for efficiency and should be used sparingly - it may cause
# issues if recipes don't always perform incremental builds correctly.
# Users can still force the work directory to be cleaned.
export DO_CLEAN_AFTER_FETCH=1

# While there is no real dependency tree enforced by the build scripts, recipes
# may depend on environments exported by other recipes.
# Environment set by this script always takes precendence though, so a recipe 
# cannot use another's do_* functions or DO_*/GIT_*/WGET_* variables.
# Separate dependencies by a ':' (like the PATH variable).
export DEPENDS_ENVIRONMENT=""


ENV_UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/ENV" >/dev/null 2>&1 && pwd)"
source "${ENV_UTIL_DIR}/util.sh"

#
# The following build steps should be overridden as appropriate.
# Functions operate in REC_WORK_DIR unless otherwise specified.
#

# perform operations that require internet
function do_fetch()
{
    # operates in REC_SRC_DIR
    if [ -n "$GIT_REPO" ]; then
        env_git_clone_fetch_checkout "$GIT_REPO" . "$GIT_REV"
    elif [ -n "$WGET_URL" ]; then
        env_wget_and_md5 "$WGET_URL" "$WGET_OUTPUT" "$WGET_OUTPUT_MD5"
    else
        echo "do_fetch: nothing to fetch"
    fi
}
function do_post_fetch()
{
    # operates in REC_SRC_DIR
    :
}
function do_late_fetch()
{
    :
}

# clean any previously installed toolchain artifacts
function do_toolchain_uninstall()
{
    # operates in REC_WORK_DIR
    # however, if DO_FETCH_ONLY is set, operates in REC_SRC_DIR
    :
}

# clean any previously deployed BSP artifacts
function do_undeploy()
{
    # operates in REC_WORK_DIR
    # however, if DO_FETCH_ONLY is set, operates in REC_SRC_DIR
    :
}

# perform actual build (beginning here, internet may be unavailable)
function do_build()
{
    :
}

# run any unit tests
function do_test()
{
    :
}

# deploy BSP artifacts to a staging area (hint: utilize deploy_artifacts below)
function do_deploy()
{
    # operates in REC_WORK_DIR
    # however, if DO_FETCH_ONLY is set, operates in REC_SRC_DIR
    :
}

# install toolchains fetched or built (hint: should install to REC_ENV_DIR)
function do_toolchain_install()
{
    # operates in REC_WORK_DIR
    # however, if DO_FETCH_ONLY is set, operates in REC_SRC_DIR
    :
}

#
# The following are meant to be used by recipes (and may be overridden).
#

# run make using all available CPUs
function make_parallel()
{
    make -j "$(nproc)" "$@"
}

function get_dependency_src()
{
    # $1 = dependency
    (
        cd "${ENV_WORKING_DIR}/src/$1" && pwd
    )
}

function deploy_artifacts()
{
    # $1 = destination subdirectory, or empty string "" for root of deploy dir
    # remaining params optional: files to deploy to subdirectory
    local subdir=$1
    shift
    local dest="${ENV_DEPLOY_DIR}/${subdir}"
    mkdir -p "$dest"
    echo "Deploying: $dest"
    for f in "$@"; do
        echo "  $(basename "$f")"
        cp "$f" "${dest}/"
    done
}

function undeploy_artifacts()
{
    # $1 = destination subdirectory, or empty string "" for root of deploy dir
    # remaining params optional: files to deploy to subdirectory
    local subdir=$1
    shift
    local dest="${ENV_DEPLOY_DIR}/${subdir}"
    echo "Undeploying: $dest"
    for f in "$@"; do
        echo "  $(basename "$f")"
        rm -f "${dest}/$(basename "$f")"
    done
}

#
# The following are used for checking dependencies in recipes.
# Their existence here violates the generality of the recipe design, but are
# kept here for convenenience (at least for now).
#

# Check that baremetal toolchain is on PATH
function ENV_check_bm_toolchain()
{
    if ! which arm-none-eabi-gcc > /dev/null 2>&1; then
        echo "Error: Bare metal cross compiler 'arm-none-eabi-gcc' is not on PATH"
        echo "  Ensure that recipe has DEPENDS_ENVIRONMENT on 'gcc-arm-none-eabi' and that it is built"
        return 1
    fi
}

# Verify poky toolchain
function ENV_check_yocto_hpps_sdk()
{
    if [ -z "$YOCTO_HPPS_SDK" ] || [ ! -d "$YOCTO_HPPS_SDK" ]; then
        echo "Error: YOCTO_HPPS_SDK not found: $YOCTO_HPPS_SDK"
        echo "  Ensure that recipe has DEPENDS_ENVIRONMENT on 'hpsc-yocto-hpps' and that it is built"
        return 1
    fi
}

# Check that RTEMS toolchain is on PATH
function ENV_check_rsb_toolchain()
{
    if ! which arm-rtems5-gcc > /dev/null 2>&1; then
        echo "Error: RTEMS cross compiler 'arm-rtems5-gcc' is not on PATH"
        echo "  Ensure that recipe has DEPENDS_ENVIRONMENT on 'rtems-source-builder' and that it is built"
        return 1
    fi
}

# Verify RTEMS R52 toolchain
function ENV_check_rtems_r52_sdk()
{
    if [ -z "$RTEMS_RTPS_R52_BSP" ] || [ ! -d "$RTEMS_RTPS_R52_BSP" ]; then
        echo "Error: RTEMS_RTPS_R52_BSP not found: $RTEMS_RTPS_R52_BSP"
        echo "  Ensure that recipe has DEPENDS_ENVIRONMENT on 'rtems-rtps-r52' and that it is built"
        return 1
    fi
}
