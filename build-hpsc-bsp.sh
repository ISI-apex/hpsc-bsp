#!/bin/bash
#
# Parent build script
#

# Fail-fast
set -e

# Additional artifacts for BSP directory
BSP_ARTIFACTS_TOP=("qemu-env.sh"
                   "run-qemu.sh"
                   "conf/")

function usage()
{
    local rc=${1:-0}
    echo "Usage: $0 [-a ACTION]... [-p PREFIX] [-w DIR] [-h]"
    echo "    -a ACTION: one of:"
    echo "       all: (default) execute all actions"
    echo "       fetch: download toolchains and sources"
    echo "       build: compile pre-downloaded sources"
    echo "       stage: stage artifacts into a directory before packaging"
    echo "       package: create binary BSP archive from staged artifacts"
    echo "       package-sources: create source BSP archive"
    echo "    -p PREFIX: set the release stage/package prefix (default=\"SNAPSHOT\")"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit "$rc"
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
IS_STAGE=0
IS_PACKAGE=0
IS_PACKAGE_SOURCES=0
PREFIX="SNAPSHOT"
WORKING_DIR="BUILD"
while getopts "a:p:w:h?" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "stage" ]; then
                IS_STAGE=1
            elif [ "${OPTARG}" == "package" ]; then
                IS_PACKAGE=1
            elif [ "${OPTARG}" == "package-sources" ]; then
                IS_PACKAGE_SOURCES=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage 1
            fi
            ;;
        p)
            PREFIX="${OPTARG}"
            ;;
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    # do everything
    IS_FETCH=1
    IS_BUILD=1
    IS_STAGE=1
    IS_PACKAGE=1
    IS_PACKAGE_SOURCES=1
fi

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
METRICS_CSV=${WORKING_DIR}/log/build-bsp-metrics.csv

function action_fetch()
{
    echo "Fetching sources..."
    "${BSP_DIR}/build-hpsc-host.sh" -w "$WORKING_DIR" -a fetch
    "${BSP_DIR}/build-hpsc-bare.sh" -w "$WORKING_DIR" -a fetch
    "${BSP_DIR}/build-hpsc-rtems.sh" -w "$WORKING_DIR" -a fetch
    "${BSP_DIR}/build-hpsc-yocto.sh" -w "$WORKING_DIR" -a fetch
}

function action_build()
{
    echo "Building..."
    "${BSP_DIR}/build-hpsc-host.sh" -w "$WORKING_DIR" -a build
    "${BSP_DIR}/build-hpsc-bare.sh" -w "$WORKING_DIR" -a build
    "${BSP_DIR}/build-hpsc-rtems.sh" -w "$WORKING_DIR" -a build
    "${BSP_DIR}/build-hpsc-yocto.sh" -w "$WORKING_DIR" -a build
}

function action_stage()
{
    echo "Staging..."
    local STAGE_DIR="${WORKING_DIR}/stage/${PREFIX}"
    mkdir -p "$STAGE_DIR"
    # artifacts deployed by recipes
    cp -r "${WORKING_DIR}"/deploy/* "$STAGE_DIR"
    # remaining artifacts
    cp -r "${BSP_ARTIFACTS_TOP[@]/#/${BSP_DIR}/}" "${STAGE_DIR}/"
}

function action_package()
{
    local RELEASE_BIN_TGZ=${WORKING_DIR}/${PREFIX}_bin.tar.gz
    echo "Packaging: $RELEASE_BIN_TGZ"
    tar czf "$RELEASE_BIN_TGZ" -C "${WORKING_DIR}/stage" "$PREFIX"
    echo "md5: $RELEASE_BIN_TGZ"
    md5sum "$RELEASE_BIN_TGZ" | sed "s,${WORKING_DIR}/,," \
        > "${RELEASE_BIN_TGZ}.md5"
}

function action_package_sources()
{
    local RELEASE_SRC_TAR=${WORKING_DIR}/${PREFIX}_src.tar
    local RELEASE_SRC_TGZ=${RELEASE_SRC_TAR}.gz
    echo "Packaging: $RELEASE_SRC_TGZ"

    # Links to makefiles that transcend any individual component repo, but are
    # versioned controlled in some component repo (because where else); save
    # the user from having to specify -f for every make invocation. Needed to
    # build components in $srcdir not part of the binary release.
    local srcdir="${WORKING_DIR}/src"
    ln -sf "ssw/hpsc-utils/make/Makefile.hpsc" "${srcdir}/Makefile"
    ln -sf "hpsc-utils/make/Makefile.ssw" "${srcdir}/ssw/Makefile"
    ln -sf "hpsc-sdk-tools/make/Makefile.sdk" "${srcdir}/sdk/Makefile"

    # Add build scripts, then append sources within the BSP directory structure
    # while maintaining the base working directory name.
    local bsp_files=(".git")
    while read f; do
        bsp_files+=("$f")
    done< <(git --git-dir="${BSP_DIR}/.git" ls-tree --name-only --full-tree HEAD)
    tar -cf "${RELEASE_SRC_TAR}" -C "$BSP_DIR" \
        --transform "s,^,${PREFIX}/,rS" "${bsp_files[@]}"
    local workdir_base
    workdir_base=$(basename "$(cd "$WORKING_DIR" && pwd)")
    tar -rf "${RELEASE_SRC_TAR}" -C "$WORKING_DIR" \
        --transform "s,^,${PREFIX}/${workdir_base}/,rS" src
    gzip -f "$RELEASE_SRC_TAR"

    echo "md5: $RELEASE_SRC_TGZ"
    md5sum "$RELEASE_SRC_TGZ" | sed "s,${WORKING_DIR}/,," \
        > "${RELEASE_SRC_TGZ}.md5"
}

function action_with_metrics()
{
    local start end elapsed
    local rc=0
    start=$(date +%s.%N)
    "$@" || rc=$?
    end=$(date +%s.%N)
    elapsed=$(echo "$start $end" | awk '{printf "%f", $2 - $1}')
    if [ ! -f "$METRICS_CSV" ]; then
        echo "DATETIME,ACTION,RC,ELAPSED" > "$METRICS_CSV"
    fi
    echo "$(date +'%F %T'),${1/"action_"/},$rc,$elapsed" \
        >> "$METRICS_CSV"
    return $rc
}

function bsp_build_lifecycle()
{
    # not specifying a recipe just builds the working directory structure
    "${BSP_DIR}/build-recipe.sh" -w "$WORKING_DIR"
    if [ $IS_FETCH -ne 0 ]; then
        action_with_metrics action_fetch
    fi
    if [ $IS_BUILD -ne 0 ]; then
        action_with_metrics action_build
    fi
    if [ $IS_STAGE -ne 0 ]; then
        action_with_metrics action_stage
    fi
    if [ $IS_PACKAGE -ne 0 ]; then
        action_with_metrics action_package
    fi
    if [ $IS_PACKAGE_SOURCES -ne 0 ]; then
        action_with_metrics action_package_sources
    fi
}

bsp_build_lifecycle
