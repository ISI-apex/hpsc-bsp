#!/bin/bash

# Fail-fast
set -e

function build_work_dirs()
{
    local wdir=$1
    mkdir -p "${wdir}" \
             "${wdir}/src" \
             "${wdir}/work" \
             "${wdir}/deploy" \
             "${wdir}/env" \
             "${wdir}/stage"
}

function usage()
{
    echo "Usage: $0 [-r RECIPE] [-a <all|fetch|clean|build|test>] [-w DIR] [-h]"
    echo "    -r RECIPE: the recipe to use"
    echo "    -a ACTION"
    echo "       all: (default) fetch, build, and test"
    echo "       fetch: download/update sources"
    echo "       clean: force clean, even on recipes that don't autoclean"
    echo "       build: compile pre-downloaded sources"
    echo "       test: run tests"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
RECIPES=()
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_CLEAN=0
IS_BUILD=0
IS_TEST=0
IS_DEPLOY=0
IS_TOOLCHAIN_INSTALL=0
WORKING_DIR="BUILD"
while getopts "r:a:w:h?" o; do
    case "$o" in
        r)
            RECIPES+=("${OPTARG}")
            ;;
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
                IS_DEPLOY=1 # currently implied by build
                IS_TOOLCHAIN_INSTALL=1 # currently implied by build
            elif [ "${OPTARG}" == "clean" ]; then
                IS_CLEAN=1
            elif [ "${OPTARG}" == "test" ]; then
                IS_TEST=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    IS_FETCH=1
    IS_BUILD=1
    IS_TEST=1
    IS_DEPLOY=1
    IS_TOOLCHAIN_INSTALL=1
fi

REC_DIR="${PWD}/build-recipes"
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

function build_set_recipe_env()
{
    local recname=$1
    # recipes extend the ENV script
    source "${REC_DIR}/ENV.sh"
    # variables for recipes
    export ENV_WORKING_DIR="${PWD}"
    export ENV_DEPLOY_DIR="${ENV_WORKING_DIR}/deploy"
    export REC_UTIL_DIR="${REC_DIR}/${recname}/utils"
    export REC_SRC_DIR="${ENV_WORKING_DIR}/src/${recname}"
    export REC_WORK_DIR="${ENV_WORKING_DIR}/work/${recname}"
    export REC_ENV_DIR="${ENV_WORKING_DIR}/env" # shared b/w recipes, shhh... ;)
    source "${REC_DIR}/${recname}.sh"
}

function build_lifecycle()
{
    local recname=$1
    # we really just want DEPENDS_ENVIRONMENT to begin with
    build_set_recipe_env "$recname"
    # cache DEPENDS_ENVIRONMENT since it will be overridden by dependencies
    IFS=':' read -ra DEP_ENV_CACHE <<< "$DEPENDS_ENVIRONMENT"
    for de in "${DEP_ENV_CACHE[@]}"; do
        echo "$recname: depends: $de"
        build_set_recipe_env "$de"
    done
    # now that we have exported from dependencies, we need our own environment
    build_set_recipe_env "$recname"

    # fetch is broken up to allow custom clean and extract
    if [ $IS_FETCH -ne 0 ]; then
        mkdir -p "$REC_SRC_DIR"
        echo "$recname: fetch"
        cd "$REC_SRC_DIR"
        do_fetch
        echo "$recname: post_fetch"
        cd "$REC_SRC_DIR"
        do_post_fetch
    fi

    # uninstall/undeploy on clean request or after fetch
    if [ $IS_CLEAN -ne 0 ] || [ $IS_FETCH -ne 0 ]; then
        if [ "$DO_FETCH_ONLY" -ne 0 ]; then
            echo "$recname: toolchain_uninstall"
            cd "$REC_SRC_DIR"
            do_toolchain_uninstall
            echo "$recname: undeploy"
            cd "$REC_SRC_DIR"
            do_undeploy
        elif [ -d "$REC_WORK_DIR" ]; then
            echo "$recname: toolchain_uninstall"
            cd "$REC_WORK_DIR"
            do_toolchain_uninstall
            echo "$recname: undeploy"
            cd "$REC_WORK_DIR"
            do_undeploy
        fi # else nowhere to run uninstall/undeploy from
    fi

    if [ "$DO_FETCH_ONLY" -eq 0 ]; then
        # clean if requested or clean-after-fetch not overridden by recipe
        if [ $IS_CLEAN -ne 0 ] || 
           [[ $IS_FETCH -ne 0 && "$DO_CLEAN_AFTER_FETCH" -eq 1 ]]; then
            echo "$recname: clean"
            cd "$ENV_WORKING_DIR"
            rm -rf "$REC_WORK_DIR"
        fi
        # extract to (or create) work dir
        if [ ! -d "$REC_WORK_DIR" ]; then
            if [ "$DO_BUILD_OUT_OF_SOURCE" -eq 0 ]; then
                echo "$recname: extract"
                mkdir -p "$(dirname $REC_WORK_DIR)"
                cp -r "$REC_SRC_DIR" "$REC_WORK_DIR"
            else
                mkdir -p "$REC_WORK_DIR"
            fi
        fi
        if [ $IS_FETCH -ne 0 ]; then
            # late fetch is for fetching that requires a work dir first
            echo "$recname: late_fetch"
            cd "$REC_WORK_DIR"
            do_late_fetch
        fi

        if [ $IS_BUILD -ne 0 ]; then
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'build'"
                return 1
            fi
            echo "$recname: build"
            cd "$REC_WORK_DIR"
            do_build && RC=0 || RC=$?
            if [ $RC -eq 0 ]; then
                echo "$recname: build successful"
            else
                echo "$recname: Error: build failed with exit code: $RC"
                return $RC
            fi
        fi

        if [ $IS_TEST -ne 0 ]; then
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'test'"
                return 1
            fi
            echo "$recname: test"
            cd "$REC_WORK_DIR"
            do_test
        fi
    fi

    if [ $IS_DEPLOY -ne 0 ]; then
        if [ "$DO_FETCH_ONLY" -ne 0 ]; then
            cd "$REC_SRC_DIR"
        else
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'deploy'"
                return 1
            fi
            cd "$REC_WORK_DIR"
        fi
        echo "$recname: deploy"
        do_deploy
    fi

    if [ $IS_TOOLCHAIN_INSTALL -ne 0 ]; then
        if [ "$DO_FETCH_ONLY" -ne 0 ]; then
            cd "$REC_SRC_DIR"
        else
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'toolchain_install'"
                return 1
            fi
            cd "$REC_WORK_DIR"
        fi
        echo "$recname: toolchain_install"
        do_toolchain_install
    fi
}

for recname in "${RECIPES[@]}"; do
    # subshell isolates recipes from each other
    (
        build_lifecycle "$recname"
    )
done
