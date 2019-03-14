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
#

#
# Recipes override the GIT or WGET configurations (GIT takes precedence).
#

export GIT_REPO=""
export GIT_REV=""
export GIT_BRANCH=""

export WGET_URL=""
export WGET_OUTPUT=""
export WGET_OUTPUT_MD5=""

#
# The following build steps should be overridden as appropriate.
# Functions operate in REC_WORK_DIR unless otherwise specified.
#

# perform operations that require internet
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

#
# The following are meant to be used by recipes (and may be overridden).
#

# run make using all available CPUs
function make_parallel()
{
    make -j "$(nproc)" "$@"
}

function get_dependency()
{
    # $1 = dependency
    (
        cd "${ENV_WORKING_DIR}/work/$1" && pwd
    )
}
