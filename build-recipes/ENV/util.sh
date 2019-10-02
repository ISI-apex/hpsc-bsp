#!/bin/bash

# Assert that a string is not empty
function assert_str()
{
    if [ -z "$1" ]; then
        echo "String assertion failed!"
        exit 1
    fi
}

function env_git_clone_fetch_checkout()
{
    local repo=$1
    local dir=$2
    local checkout=$3
    assert_str "$repo"
    assert_str "$dir"
    assert_str "$checkout"
    if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir")" ]; then
        echo "git clone: $repo $dir"
        git clone "$repo" "$dir" || return $?
    fi
    (
        cd "$dir" || return $?
        # in case remote URI changed
        echo "git set-url origin: $repo"
        git remote set-url origin "$repo" || return $?
        echo "git fetch origin"
        git fetch origin --prune --force || return $?
        echo "git checkout: $checkout"
        git checkout "$checkout" -- || return $?
        # pull, if needed
        local is_detached
        is_detached=$(git status | grep -c detached) || return $?
        if [ "$is_detached" -eq 0 ]; then
            echo "git pull: $repo"
            git pull origin || return $?
        fi
    )
}

function env_check_md5sum()
{
    local file=$1
    local md5_expected=$2
    assert_str "$file"
    assert_str "$md5_expected"
    # must check md5sum return code, which awk ignores if we pipe directly;
    # can't rely on PIPESTATUS since code is lost due to "md5" var assignment
    local md5sum_out
    local md5
    echo "checking md5sum: $file"
    md5sum_out=$(md5sum "$file") || return $?
    md5=$(echo "$md5sum_out" | awk '{print $1}')
    if [ "$md5" != "$md5_expected" ]; then
        echo "md5sum mismatch for: $file"
        echo "  got: $md5"
        echo "  expected: $md5_expected"
        return 1
    fi
}

function env_check_sha256sum()
{
    local file=$1
    local sha256_expected=$2
    assert_str "$file"
    assert_str "$sha256_expected"
    # must check sha256sum return code, which awk ignores if we pipe directly;
    # can't rely on PIPESTATUS since code is lost due to "sha256" var assignment
    local sha256sum_out
    local sha256
    echo "checking sha256sum: $file"
    sha256sum_out=$(sha256sum "$file") || return $?
    sha256=$(echo "$sha256sum_out" | awk '{print $1}')
    if [ "$sha256" != "$sha256_expected" ]; then
        echo "sha256sum mismatch for: $file"
        echo "  got: $sha256"
        echo "  expected: $sha256_expected"
        return 1
    fi
}

function env_maybe_wget()
{
    local url=$1
    local output=$2
    assert_str "$url"
    assert_str "$output"
    if [ ! -e "$output" ]; then
        echo "wget from: $url"
        wget --progress=dot:mega -O "$output" "$url" || return $?
    fi
}
