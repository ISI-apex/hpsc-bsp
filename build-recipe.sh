#!/bin/bash

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
    local rc=${1:-0}
    echo "Usage: $0 [-a ACTION]... [-r RECIPE]... [-w DIR] [-h]"
    echo "    -a ACTION: one of:"
    echo "       clean-sources: clean pre-downloaded sources (implies 'clean')"
    echo "       all: (default) fetch, build, and test"
    echo "       fetch: download/update sources"
    echo "       clean: force clean, even on recipes that don't autoclean"
    echo "       build: compile pre-downloaded sources"
    echo "       test: run tests"
    echo "    -r RECIPE: a recipe to execute actions on"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit "$rc"
}

# Script options
RECIPES=()
HAS_ACTION=0
IS_ALL=0
IS_TOOLCHAIN_UNINSTALL=0
IS_UNDEPLOY=0
IS_CLEAN_SOURCES=0
IS_FETCH=0
IS_CLEAN=0
IS_BUILD=0
IS_TEST=0
IS_DEPLOY=0
IS_TOOLCHAIN_INSTALL=0
WORKING_DIR="BUILD"
while getopts "a:r:w:h?" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "clean-sources" ]; then
                IS_TOOLCHAIN_UNINSTALL=1 # implied
                IS_UNDEPLOY=1 # implied
                IS_CLEAN_SOURCES=1
                IS_CLEAN=1 # implied
            elif [ "${OPTARG}" == "fetch" ]; then
                IS_TOOLCHAIN_UNINSTALL=1 # implied
                IS_UNDEPLOY=1 # implied
                IS_FETCH=1
            elif [ "${OPTARG}" == "clean" ]; then
                IS_TOOLCHAIN_UNINSTALL=1 # implied
                IS_UNDEPLOY=1 # implied
                IS_CLEAN=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
                IS_DEPLOY=1 # currently implied by build
                IS_TOOLCHAIN_INSTALL=1 # currently implied by build
            elif [ "${OPTARG}" == "test" ]; then
                IS_TEST=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
                >&2 echo "Error: no such action: ${OPTARG}"
                >&2 usage 1
            fi
            ;;
        r)
            RECIPES+=("${OPTARG}")
            ;;
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            >&2 echo "Unknown option"
            >&2 usage 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    IS_TOOLCHAIN_UNINSTALL=1
    IS_UNDEPLOY=1
    IS_FETCH=1
    IS_BUILD=1
    IS_TEST=1
    IS_DEPLOY=1
    IS_TOOLCHAIN_INSTALL=1
fi

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
build_work_dirs "$WORKING_DIR" || exit $?
cd "$WORKING_DIR" || exit $?
METRICS_CSV=${PWD}/log/build-recipe-metrics.csv

# Choose REC_SRC_DIR or REC_WORK_DIR depending on recipe's DO_FETCH_ONLY config
function get_action_dir()
{
    [ "$DO_FETCH_ONLY" -ne 0 ] && echo "$REC_SRC_DIR" || echo "$REC_WORK_DIR"
}

function verify_dir_prereq()
{
    if [ ! -d "$1" ]; then
        >&2 echo "Error: missing required directory: $1"
        >&2 echo "Hint: probably need to execute prerequisite action(s) first"
        return 1
    fi
}

function build_step_toolchain_uninstall()
{
    local dir
    dir=$(get_action_dir)
    if [ -d "$dir" ]; then
        echo "$1: toolchain_uninstall"
        cd "$dir" && do_toolchain_uninstall
    fi
}

function build_step_undeploy()
{
    local dir
    dir=$(get_action_dir)
    if [ -d "$dir" ]; then
        echo "$1: undeploy"
        cd "$dir" && do_undeploy
    fi
}

function build_step_clean_sources()
{
    echo "$1: clean_sources"
    cd "$ENV_WORKING_DIR" && rm -rf "$REC_SRC_DIR"
}

function build_step_fetch()
{
    echo "$1: fetch"
    mkdir -p "$REC_SRC_DIR" && cd "$REC_SRC_DIR" && do_fetch
}

function build_step_post_fetch()
{
    echo "$1: post_fetch"
    cd "$REC_SRC_DIR" && do_post_fetch
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
    verify_dir_prereq "$REC_SRC_DIR" || return $?
    if [ "$DO_BUILD_OUT_OF_SOURCE" -eq 0 ]; then
        mkdir -p "$(dirname "$REC_WORK_DIR")" && \
        cp -r "$REC_SRC_DIR" "$REC_WORK_DIR"
    else
        mkdir -p "$REC_WORK_DIR"
    fi
}

function build_step_late_fetch()
{
    echo "$1: late_fetch"
    cd "$REC_WORK_DIR" && do_late_fetch
}

function build_step_build()
{
    echo "$1: build"
    verify_dir_prereq "$REC_WORK_DIR" && cd "$REC_WORK_DIR" && do_build
}

function build_step_test()
{
    local dir
    dir=$(get_action_dir "$1")
    echo "$1: test"
    verify_dir_prereq "$dir" && cd "$dir" && do_test
}

function build_step_deploy()
{
    local dir
    dir=$(get_action_dir "$1")
    echo "$1: deploy"
    verify_dir_prereq "$dir" && cd "$dir" && do_deploy
}

function build_step_toolchain_install()
{
    local dir
    dir=$(get_action_dir "$1")
    echo "$1: toolchain_install"
    verify_dir_prereq "$dir" && cd "$dir" && do_toolchain_install
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
    source "${THIS_DIR}/build-recipes/build-recipe-env.sh" \
        -r "$recname" -w . || return $?

    if [ $IS_TOOLCHAIN_UNINSTALL -ne 0 ]; then
        build_step_with_metrics build_step_toolchain_uninstall "$recname" || \
            return $?
    fi

    if [ $IS_UNDEPLOY -ne 0 ]; then
        build_step_with_metrics build_step_undeploy "$recname" || return $?
    fi

    if [ $IS_CLEAN_SOURCES -ne 0 ]; then
        build_step_with_metrics build_step_clean_sources "$recname" || return $?
    fi

    # fetch is broken up to allow custom clean and extract
    if [ $IS_FETCH -ne 0 ]; then
        build_step_with_metrics build_step_fetch "$recname" || return $?
        build_step_with_metrics build_step_post_fetch "$recname" || return $?
    fi

    # some recipes are source-only
    if [ "$DO_FETCH_ONLY" -eq 0 ]; then
        # clean if requested or clean-after-fetch not overridden by recipe
        if [ $IS_CLEAN -ne 0 ] || 
           [[ $IS_FETCH -ne 0 && "$DO_CLEAN_AFTER_FETCH" -eq 1 ]]; then
            build_step_with_metrics build_step_clean "$recname" || return $?
        fi

        # extract to (or create) work dir
        if [[ $IS_FETCH -ne 0 || $IS_BUILD -ne 0 ]] &&
           [ ! -d "$REC_WORK_DIR" ]; then
            build_step_with_metrics build_step_extract "$recname" || return $?
        fi

        # late fetch is for fetching that requires a work dir first
        if [ $IS_FETCH -ne 0 ]; then
            build_step_with_metrics build_step_late_fetch "$recname" || \
                return $?
        fi

        if [ $IS_BUILD -ne 0 ]; then
            build_step_with_metrics build_step_build "$recname" && RC=0 || RC=$?
            if [ $RC -eq 0 ]; then
                echo "$recname: build successful"
            else
                >&2 echo "$recname: Error: build failed with exit code: $RC"
                return $RC
            fi
        fi
    fi

    if [ $IS_TEST -ne 0 ]; then
        build_step_with_metrics build_step_test "$recname" || return $?
    fi

    if [ $IS_DEPLOY -ne 0 ]; then
        build_step_with_metrics build_step_deploy "$recname" || return $?
    fi

    if [ $IS_TOOLCHAIN_INSTALL -ne 0 ]; then
        build_step_with_metrics build_step_toolchain_install "$recname" || \
            return $?
    fi
}

function build_lifecycle_and_log()
{
    local recname=$1
    local rec_log_dir=${PWD}/log/${recname}
    local rec_log_file
    local rc
    mkdir -p "$rec_log_dir" || return $?
    # wait for an available log file
    while [ -z "$rec_log_file" ] || [ -e "$rec_log_file" ]; do
        rec_log_file=${rec_log_dir}/build-recipe-$(date +'%Y%m%d_%H%M%S').log
    done
    build_lifecycle "$recname" 2>&1 | tee "$rec_log_file"
    rc=${PIPESTATUS[0]}
    echo "Build log saved to: $rec_log_file"
    return "$rc"
}

for recname in "${RECIPES[@]}"; do
    # subshell isolates recipes from each other
    (
        build_lifecycle_and_log "$recname"
    ) || exit $?
done
