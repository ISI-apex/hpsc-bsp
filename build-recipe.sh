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
             "${wdir}/stage" \
             "${wdir}/log"
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

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REC_DIR="${THIS_DIR}/build-recipes"
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"
METRICS_CSV=${PWD}/log/build-recipe-metrics.csv

function build_recipe_export_env_base()
{
    local recname=$1
    # recipes extend the ENV script
    source "${REC_DIR}/ENV.sh" || return $?
    # variables for recipes
    export ENV_WORKING_DIR="${PWD}"
    export ENV_DEPLOY_DIR="${ENV_WORKING_DIR}/deploy"
    export REC_UTIL_DIR="${REC_DIR}/${recname}/utils"
    export REC_SRC_DIR="${ENV_WORKING_DIR}/src/${recname}"
    export REC_WORK_DIR="${ENV_WORKING_DIR}/work/${recname}"
    export REC_ENV_DIR="${ENV_WORKING_DIR}/env" # shared b/w recipes, shhh... ;)
    source "${REC_DIR}/${recname}.sh"
}

function build_recipe_export_env_with_deps()
{
    local recname=$1
    # we really just want DEPENDS_ENVIRONMENT to begin with
    build_recipe_export_env_base "$recname" || return $?
    # cache DEPENDS_ENVIRONMENT since it will be overridden by dependencies
    IFS=':' read -ra DEP_ENV_CACHE <<< "$DEPENDS_ENVIRONMENT"
    for de in "${DEP_ENV_CACHE[@]}"; do
        echo "$recname: depends: $de"
        build_recipe_export_env_base "$de" || return $?
    done
    # now that we have exported from dependencies, we need our own environment
    build_recipe_export_env_base "$recname"
}

function build_step_fetch()
{
    echo "$1: fetch"
    cd "$REC_SRC_DIR" && do_fetch
}

function build_step_post_fetch()
{
    echo "$1: post_fetch"
    cd "$REC_SRC_DIR" && do_post_fetch
}

function build_step_late_fetch()
{
    echo "$1: late_fetch"
    cd "$REC_WORK_DIR" && do_late_fetch
}

function build_step_toolchain_uninstall()
{
    if [ "$DO_FETCH_ONLY" -ne 0 ]; then
        echo "$1: toolchain_uninstall"
        cd "$REC_SRC_DIR" && do_toolchain_uninstall
    elif [ -d "$REC_WORK_DIR" ]; then
        echo "$1: toolchain_uninstall"
        cd "$REC_WORK_DIR" && do_toolchain_uninstall
    fi # else nowhere to run uninstall from
}

function build_step_undeploy()
{
    if [ "$DO_FETCH_ONLY" -ne 0 ]; then
        echo "$1: undeploy"
        cd "$REC_SRC_DIR" && do_undeploy
    elif [ -d "$REC_WORK_DIR" ]; then
        echo "$1: undeploy"
        cd "$REC_WORK_DIR" && do_undeploy
    fi # else nowhere to run undeploy from
}

# TODO: Not a real build step
function build_step_clean()
{
    echo "$1: clean"
    cd "$ENV_WORKING_DIR" && rm -rf "$REC_WORK_DIR"
}

# TODO: Not a real build step
function build_step_extract()
{
    echo "$1: extract"
    mkdir -p "$(dirname "$REC_WORK_DIR")" && \
    cp -r "$REC_SRC_DIR" "$REC_WORK_DIR"
}

function build_step_build()
{
    if [ ! -d "$REC_WORK_DIR" ]; then
        echo "$1: Error: must 'fetch' before 'build'"
        return 1
    fi
    echo "$1: build"
    cd "$REC_WORK_DIR" && do_build
}

function build_step_test()
{
    if [ ! -d "$REC_WORK_DIR" ]; then
        echo "$1: Error: must 'fetch' before 'test'"
        return 1
    fi
    echo "$1: test"
    cd "$REC_WORK_DIR" && do_test
}

function build_step_deploy()
{
    local dir
    if [ "$DO_FETCH_ONLY" -ne 0 ]; then
        dir="$REC_SRC_DIR"
    else
        if [ ! -d "$REC_WORK_DIR" ]; then
            echo "$1: Error: must 'fetch' before 'deploy'"
            return 1
        fi
        dir="$REC_WORK_DIR"
    fi
    echo "$1: deploy"
    cd "$dir" && do_deploy
}

function build_step_toolchain_install()
{
    local dir
    if [ "$DO_FETCH_ONLY" -ne 0 ]; then
        dir="$REC_SRC_DIR"
    else
        if [ ! -d "$REC_WORK_DIR" ]; then
            echo "$1: Error: must 'fetch' before 'toolchain_install'"
            return 1
        fi
        dir="$REC_WORK_DIR"
    fi
    echo "$1: toolchain_install"
    cd "$dir" && do_toolchain_install
}

function build_step_with_metrics()
{
    local start end elapsed
    local rc=0
    start=$(date +%s.%N)
    "$@" || rc=$?
    end=$(date +%s.%N)
    elapsed=$(echo "$start $end" | awk '{printf "%f", $2 - $1}')
    if [ ! -f "$METRICS_CSV" ]; then
        echo "DATETIME,RECIPE,STEP,RC,ELAPSED" > "$METRICS_CSV"
    fi
    echo "$(date +'%F %T'),$2,${1/"build_step_"/},$rc,$elapsed" \
        >> "$METRICS_CSV"
    return $rc
}

function build_lifecycle()
{
    local recname=$1

    # setup build environment
    build_recipe_export_env_with_deps "$recname"

    # fetch is broken up to allow custom clean and extract
    if [ $IS_FETCH -ne 0 ]; then
        mkdir -p "$REC_SRC_DIR"
        build_step_with_metrics build_step_fetch "$recname"
        build_step_with_metrics build_step_post_fetch "$recname"
    fi

    # uninstall/undeploy on clean request or after fetch
    if [ $IS_CLEAN -ne 0 ] || [ $IS_FETCH -ne 0 ]; then
        build_step_with_metrics build_step_toolchain_uninstall "$recname"
        build_step_with_metrics build_step_undeploy "$recname"
    fi

    # some recipes are source-only
    if [ "$DO_FETCH_ONLY" -eq 0 ]; then
        # clean if requested or clean-after-fetch not overridden by recipe
        if [ $IS_CLEAN -ne 0 ] || 
           [[ $IS_FETCH -ne 0 && "$DO_CLEAN_AFTER_FETCH" -eq 1 ]]; then
            build_step_with_metrics build_step_clean "$recname"
        fi

        # extract to (or create) work dir
        if [ ! -d "$REC_WORK_DIR" ]; then
            if [ "$DO_BUILD_OUT_OF_SOURCE" -eq 0 ]; then
                build_step_with_metrics build_step_extract "$recname"
            else
                mkdir -p "$REC_WORK_DIR"
            fi
        fi

        # late fetch is for fetching that requires a work dir first
        if [ $IS_FETCH -ne 0 ]; then
            build_step_with_metrics build_step_late_fetch "$recname"
        fi

        if [ $IS_BUILD -ne 0 ]; then
            build_step_with_metrics build_step_build "$recname" && RC=0 || RC=$?
            if [ $RC -eq 0 ]; then
                echo "$recname: build successful"
            else
                echo "$recname: Error: build failed with exit code: $RC"
                return $RC
            fi
        fi

        if [ $IS_TEST -ne 0 ]; then
            build_step_with_metrics build_step_test "$recname"
        fi
    fi

    if [ $IS_DEPLOY -ne 0 ]; then
        build_step_with_metrics build_step_deploy "$recname"
    fi

    if [ $IS_TOOLCHAIN_INSTALL -ne 0 ]; then
        build_step_with_metrics build_step_toolchain_install "$recname"
    fi
}

function build_lifecycle_and_log()
{
    local recname=$1
    local rec_log_dir=${PWD}/log/${recname}
    local rec_log_file
    mkdir -p "$rec_log_dir"
    # wait for an available log file
    while [ -z "$rec_log_file" ] || [ -e "$rec_log_file" ]; do
        rec_log_file=${rec_log_dir}/build-recipe-$(date +'%F-%T').log
    done
    build_lifecycle "$recname" 2>&1 | tee "$rec_log_file"
    echo "Build log saved to: $rec_log_file"
}

for recname in "${RECIPES[@]}"; do
    # subshell isolates recipes from each other
    (
        build_lifecycle_and_log "$recname"
    )
done
