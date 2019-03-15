#!/bin/bash
#
# The point of having this templated build infrastructure is that it makes it
# it easier to automate some tasks, both for the build scripts and for users
# or CI tools to update.
#
# All recipes extend this script, so may (and sometimes must) override variables
# and functions.
#
# Global variables access to recipes are:
#  REC_UTIL_DIR: the recipe's utility directory (for content not kept in recipe)
#  REC_SRC_DIR: the recipe's source directory
#  REC_WORK_DIR: the recipe's work directory (where builds are performed)
#  ENV_WORKING_DIR: the parent directory; should only be used by functions here
#  ENV_DEPLOY_DIR: the deploy directory; should only be used by functions here
#

#
# Recipes override the GIT or WGET configurations (GIT takes precedence).
# If GIT_REPO and WGET_URL are both empty, the recipe is a "meta" recipe.
#

export GIT_REPO=""
export GIT_REV=""
export GIT_BRANCH=""

export WGET_URL=""
export WGET_OUTPUT=""
export WGET_OUTPUT_MD5=""

# Some recipes may only provide sources (e.g., then used by meta recipes)
# Functions do_fetch and do_post_fetch are executed, but not do_late_fetch.
# Finally, do_deploy is executed in REC_SRC_DIR rather than REC_WORK_DIR.
export DO_FETCH_ONLY=0

# When out of source, REC_SRC_DIR isn't automatically copied to REC_WORK_DIR.
export DO_BUILD_OUT_OF_SOURCE=0

# By default, REC_WORK_DIR is cleaned after fetch, but recipes can override
# Users can still force the work directory to be cleaned
export DO_CLEAN_AFTER_FETCH=1

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
