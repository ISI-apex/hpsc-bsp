#!/bin/bash

export GIT_REPO="https://github.com/ISI-apex/rtems-source-builder.git"
export GIT_REV=e8e01f169f57b10719660079663864df253e4854
export GIT_BRANCH="hpsc"

export DO_BUILD_OUT_OF_SOURCE=1

# Builds take a long time
export DO_CLEAN_AFTER_FETCH=0

RSB_ENV_DIR=${REC_ENV_DIR}/RSB-5
export PATH="${RSB_ENV_DIR}/bin:$PATH" # exported for other recipes

RSB_CONFIGDIRS="${REC_SRC_DIR}/rtems/config:${REC_SRC_DIR}/source-builder/config:${REC_SRC_DIR}/bare/config"
function do_post_fetch()
{
    ./source-builder/sb-set-builder --without-rtems \
                                    --source-only-download \
                                    --configdir="$RSB_CONFIGDIRS" \
                                    --no-install \
                                    5/rtems-arm
}

function do_toolchain_uninstall()
{
    if [ -e "$RSB_ENV_DIR" ]; then
        unlink "$RSB_ENV_DIR"
    fi
}

RSB_PREFIX="${REC_WORK_DIR}/RSB-5"
function do_build()
{
    # RSB doesn't do incremental builds, and it's quite slow to build...
    # Try to optimize: parse any prior build to see if we have a new RSB version
    # NOTE: Assumes this recipe is otherwise static - does NOT rebuild if this
    #       recipe changes in ANY way other than updating GIT_REV!
    #       Force a clean of the working directory to test other changes
    local RSB_SOURCEDIR="${REC_SRC_DIR}/sources"
    local RSB_PATCHDIR="${REC_SRC_DIR}/patches"
    if grep -sq "$GIT_REV" "${RSB_PREFIX}"/share/rtems/rsb/arm-rtems5-gcc-*-newlib-*.txt; then
        echo "No change in GIT_REV since last build; skipping..."
        echo "Clean this recipe to force a rebuild"
    else
        # clean so we don't accumulate old artifacts (including file grep'd above)
        rm -rf "$RSB_PREFIX"
        "${REC_SRC_DIR}/source-builder/sb-set-builder" \
            --without-rtems \
            --prefix="$RSB_PREFIX" \
            --configdir="$RSB_CONFIGDIRS" \
            --sourcedir="$RSB_SOURCEDIR" \
            --patchdir="$RSB_PATCHDIR" \
            --no-download \
            5/rtems-arm
    fi
}

function do_toolchain_install()
{
    # TODO: Can we break up build/install step above so we don't have to link to working dir?
    do_toolchain_uninstall # re-install every time
    ln -s "$RSB_PREFIX" "$RSB_ENV_DIR"
}
