#!/bin/bash

# Fail-fast
set -e

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
fi

REC_DIR="${PWD}/build-recipes"
export ENV_WORKING_DIR="${PWD}/${WORKING_DIR}"
source ./build-common.sh
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

# recipes extend the ENV script
source "${REC_DIR}/ENV.sh"

function build_recipe_fetch()
{
    local recname=$1
    local src=$2
    if [ -n "$GIT_REPO" ]; then
        git_clone_fetch_checkout "$GIT_REPO" "$src" "$GIT_REV"
    else
        mkdir -p "$src"
        if [ -n "$WGET_URL" ]; then
            wget_and_md5 "$WGET_URL" "${src}/${WGET_OUTPUT}" \
                         "$WGET_OUTPUT_MD5"
        else
            echo "$recname: nothing to fetch"
        fi
    fi
}

for recname in "${RECIPES[@]}"; do
    export REC_UTIL_DIR="${REC_DIR}/${recname}"
    export REC_SRC_DIR="${PWD}/src/${recname}"
    export REC_WORK_DIR="${PWD}/work/${recname}"
    (
        source "${REC_DIR}/${recname}.sh"

        # fetch is broken up to allow custom clean and extract
        if [ $IS_FETCH -ne 0 ]; then
            echo "$recname: fetch"
            build_recipe_fetch "$recname" "$REC_SRC_DIR"
            echo "$recname: post_fetch"
            (
                cd "$REC_SRC_DIR"
                do_post_fetch
            )
        fi
        # if this is a source-only recipe, we're finished
        if [ "$DO_FETCH_ONLY" -ne 0 ]; then
            echo "$recname: DO_FETCH_ONLY is set, nothing left to do"
            continue
        fi
        # clean if requested or clean-after-fetch not overridden by recipe
        if [ $IS_CLEAN -ne 0 ] || 
           [ $IS_FETCH -ne 0 ] && [ "$DO_CLEAN_AFTER_FETCH" -eq 1 ]; then
            echo "$recname: clean"
            rm -rf "$REC_WORK_DIR"
        fi
        # extract to (or create) work dir
        if [ ! -d "$REC_WORK_DIR" ]; then
            if [ "$DO_BUILD_OUT_OF_SOURCE" -eq 0 ]; then
                echo "$recname: extract"
                cp -r "$REC_SRC_DIR" "$REC_WORK_DIR"
            else
                mkdir -p "$REC_WORK_DIR"
            fi
        fi
        if [ $IS_FETCH -ne 0 ]; then
            # late fetch is for fetching that requires a work dir first
            echo "$recname: late_fetch"
            (
                cd "$REC_WORK_DIR"
                do_late_fetch
            )
        fi

        if [ $IS_BUILD -ne 0 ]; then
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'build'"
                exit 1
            fi
            echo "$recname: build"
            (
                cd "$REC_WORK_DIR"
                do_build && RC=0 || RC=$?
                if [ $RC -eq 0 ]; then
                    echo "$recname: build successful"
                else
                    echo "$recname: Error: build failed with exit code: $RC"
                    exit $RC
                fi
            )
        fi

        if [ $IS_TEST -ne 0 ]; then
            if [ ! -d "$REC_WORK_DIR" ]; then
                echo "$recname: Error: must 'fetch' before 'test'"
                exit 1
            fi
            echo "$recname: test"
            (
                cd "$REC_WORK_DIR"
                do_test
            )
        fi
    )
done

