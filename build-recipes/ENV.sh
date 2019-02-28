#!/bin/bash
#
# The point of having this templated build infrastructure is that it makes it
# it easier to automate some tasks, both for the build scripts and for users
# or CI tools to update.
#
# All recipes extend this script, so may (and sometimes must) override variables
# and functions.
#

#
# The following must be overridden
#

export GIT_REPO=""
export GIT_REV=""

#
# The following build steps should be overridden as appropriate.
#

# perform operations that require internet
function do_post_fetch()
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
