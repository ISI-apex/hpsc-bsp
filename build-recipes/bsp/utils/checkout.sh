#!/bin/bash

# This script reproduces the functionality provided by 'git checkout' in the
# parent repository ( https://github.com/acolinisi/hpsc.git ), not included in
# the source release, for switching between snapshots of HPSC SSW stack in
# BUILD/src, for subsequent building in-place according to BUILD/src/README.md
# (not with ./build-hpsc-*.sh). A snapshot is a consistent set of component
# versions that implements a particular feature that is not the default choice
# in the release, e.g. an updated Qemu, etc.

set -e

RCP_DIR=build-recipes
SRC_DIR=BUILD/src

usage() {
    echo "Usage: $0 -dhl [-s <snapshots_file>] [snapshot]"
    echo "  snapshot: name of tag to checkout (default release if none)"
    echo "      -d: dry run"
    echo "      -l: list available snapshots"
    echo "      -s path: file with git refs for the snapshots"
    echo "      -h: show help"
}

DRY=0
LIST=0
SNAPSHOTS_FILE=""
while getopts "dh?ls:" o; do
    case "$o" in
        d)
            DRY=1
            ;;
        l)
            LIST=1
            ;;
        s)
            SNAPSHOTS_FILE="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: invalid option" 1>&2
            usage 1>&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

# Table with the git refs for each snapshot
source "${SNAPSHOTS_FILE}"

if [ "$LIST" -eq 1 ]
then
    echo "Available snapshot bases: ${!SNAPSHOTS[@]}"
    exit 0
fi

if [ "$#" -gt 1 ]
then
    echo "ERROR: invalid arguments." 1>&2
    exit 1
fi
snapshot=$1

run() {
    echo "$@"
    if [ "$DRY" -eq 0 ]
    then
        "$@"
    fi
}

# Gather master refs to be overriden

declare -A refs
for rcp_file in $RCP_DIR/{sdk,ssw}/**.sh
do
    rcp=$(echo $rcp_file | sed "s@$RCP_DIR/\(.*\)\.sh@\1@")
    source $rcp_file
    if [ -n "$GIT_BRANCH" ]
    then
        refs[$rcp]=$GIT_BRANCH
    fi
done

#  Override repos modified in the snapshot

if [ -n "$snapshot" ] # else checkout default release
then
    if [ -z "${SNAPSHOTS[$snapshot]}" ]
    then
        echo "ERROR: no ref info for snapshot base: $snapshot" 1>&2
        exit 1
    fi
    for repo in ${SNAPSHOTS[$snapshot]}
    do
        echo "Overriding: $repo"
        refs[$repo]=$snapshot
    done
fi

for repo in "${!refs[@]}"
do
    ref="${refs[$repo]}"
    if [ -n "$ref" ]
    then
        (run cd $SRC_DIR/$repo && run git checkout ${refs[$repo]})
    fi
done
