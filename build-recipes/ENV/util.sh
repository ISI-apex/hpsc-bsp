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
    (
        set -e
        if [ ! -d "$dir" ] || [ -z "$(ls -A "$dir")" ]; then
            echo "git clone: $repo $dir"
            git clone "$repo" "$dir"
        fi
        cd "$dir"
        # in case remote URI changed
        echo "git set-url origin: $repo"
        git remote set-url origin "$repo"
        echo "git fetch origin"
        git fetch origin --prune --force
        echo "git checkout: $checkout"
        git checkout "$checkout" --
        # pull, if needed
        local is_detached=$(git status | grep -c detached)
        if [ "$is_detached" -eq 0 ]; then
            echo "git pull: $repo"
            git pull origin
        fi
    )
}

function env_check_md5sum()
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

function env_wget_and_md5()
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
        wget -O "$output" "$url" || return $?
        env_check_md5sum "$output" "$md5_expected"
    fi
}
