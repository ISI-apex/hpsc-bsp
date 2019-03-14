#!/bin/bash

# Fail-fast
set -e

function usage()
{
    echo "Usage: $0 [-r RECIPE] [-a <all|fetch|extract|build|test>] [-w DIR] [-h]"
    echo "    -r RECIPE: the recipe to use"
    echo "    -a ACTION"
    echo "       all: (default) fetch, extract, build, and test"
    echo "       fetch: download/update sources (forces clean)"
    echo "       extract: copy sources to working directory"
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
IS_EXTRACT=0
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
            elif [ "${OPTARG}" == "extract" ]; then
                IS_EXTRACT=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
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
    IS_EXTRACT=1
    IS_BUILD=1
    IS_TEST=1
fi

REC_DIR="${PWD}/build-recipes"
source ./build-common.sh
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

# recipes extend the ENV script
source "${REC_DIR}/ENV.sh"

for recname in "${RECIPES[@]}"; do
    src="src/${recname}"
    work="work/${recname}"
    (
        source "${REC_DIR}/${recname}.sh"

        if [ $IS_FETCH -ne 0 ]; then
            echo "$recname: fetch"
            (
                if [ -n "$GIT_REPO" ]; then
                    git_clone_fetch_checkout "$GIT_REPO" "$src" "$GIT_REV"
                else
                    mkdir -p "$src"
                    wget_and_md5 "$WGET_URL" "${src}/${WGET_OUTPUT}" \
                                 "$WGET_OUTPUT_MD5"
                fi
                echo "$recname: post_fetch"
                cd "$src"
                do_post_fetch
            )
            # clean to ensure that updates are built
            echo "$recname: clean"
            rm -rf "work/${recname}"
        fi

        if [ $IS_EXTRACT -ne 0 ]; then
            if [ ! -d "$src" ]; then
                echo "$recname: Error: must 'fetch' before 'extract'"
                exit 1
            fi
            if [ -d "$work" ]; then
                echo "$recname: extract: work directory already exists, skipping..."
            else
                echo "$recname: extract"
                cp -r "src/${recname}" "$work"
            fi
        fi

        if [ $IS_BUILD -ne 0 ]; then
            if [ ! -d "$work" ]; then
                echo "$recname: Error: must 'extract' before 'build'"
                exit 1
            fi
            echo "$recname: build"
            (
                cd "$work"
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
            if [ ! -d "$work" ]; then
                echo "$recname: Error: must 'extract' before 'test'"
                exit 1
            fi
            echo "$recname: test"
            (
                cd "$work"
                do_test
            )
        fi
    )
done

