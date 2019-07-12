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
    md5sum_out=$(md5sum "$file") || return $?
    md5=$(echo "$md5sum_out" | awk '{print $1}')
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
    local name
    name=$(basename "$output")
    if [ ! -e "$output" ]; then
        echo "$name: downloading from: $url"
        wget --progress=dot:mega -O "$output" "$url" || return $?
        env_check_md5sum "$output" "$md5_expected"
    fi
}
