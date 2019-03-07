#!/bin/bash
#
# Build scripts use this file for common functions.
#

# Assert that a string is not empty
function assert_str()
{
    if [ -z "$1" ]; then
        echo "String assertion failed!"
        exit 1
    fi
}

function build_work_dirs()
{
    WORKING_DIR=$1
    mkdir -p "${WORKING_DIR}"
    mkdir -p "${WORKING_DIR}/src"
    mkdir -p "${WORKING_DIR}/work"
    mkdir -p "${WORKING_DIR}/env"
    mkdir -p "${WORKING_DIR}/stage"
}

function git_clone_fetch_checkout()
{
    local repo=$1
    local dir=$2
    local checkout=$3
    assert_str "$repo"
    assert_str "$dir"
    assert_str "$checkout"
    (
        set -e
        if [ ! -d "$dir" ]; then
            echo "$dir: clone: $repo"
            git clone "$repo" "$dir"
        fi
        cd "$dir"
        # in case remote URI changed
        echo "$dir: set-url origin: $repo"
        git remote set-url origin "$repo"
        echo "$dir: fetch"
        git fetch origin --prune --force
        echo "$dir: checkout: $checkout"
        git checkout "$checkout" --
        # pull, if needed
        local is_detached=$(git status | grep -c detached)
        if [ "$is_detached" -eq 0 ]; then
            echo "$dir: pull: $repo"
            git pull origin
        fi
    )
}

function check_md5sum()
{
    local file=$1
    local md5_expected=$2
    assert_str "$file"
    assert_str "$md5_expected"
    local md5=$(md5sum "$file" | awk '{print $1}') || return $?
    if [ "$md5" != "$md5_expected" ]; then
        echo "md5sum mismatch for: $file"
        echo "  got: $md5"
        echo "  expected: $md5_expected"
        return 1
    fi
}

function wget_and_md5()
{
    local url=$1
    local output=$2
    local md5_expected=$3
    assert_str "$url"
    assert_str "$output"
    assert_str "$md5_expected"
    local name=$(basename "$output")
    if [ ! -e "$output" ]; then
        echo "$name: downloading from: $url"
        wget -O "$output" "$url"
        check_md5sum "$output" "$md5_expected"
    fi
}
