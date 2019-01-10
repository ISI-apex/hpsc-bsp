#!/bin/bash
#
# Build scripts use this file to get build settings and for common functions.
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
}

# Set git revisions to use - takes one argument, either "HEAD" or a tag name
function build_set_environment()
{
    local BUILD="$1"
    assert_str "$BUILD"
    if [ "$BUILD" == "HEAD" ]; then
        # Anything goes - read from the environment, otherwise use the latest
        export GIT_CHECKOUT_DEFAULT=${GIT_CHECKOUT_DEFAULT:-"hpsc"}
        # HPSC repositories built by poky
        # The following SRCREV_* env vars specify the commit hash or tag
        # (e.g. 'hpsc-0.9') that will be checked out for each repository.
        # Specify "\${AUTOREV}" to pull and use the head of the hpsc branch.
        export SRCREV_DEFAULT=${SRCREV_DEFAULT:-"\${AUTOREV}"}
        export SRCREV_atf=${SRCREV_atf:-"$SRCREV_DEFAULT"}
        export SRCREV_linux_hpsc=${SRCREV_linux_hpsc:-"$SRCREV_DEFAULT"}
        export SRCREV_u_boot=${SRCREV_u_boot:-"$SRCREV_DEFAULT"}
        # BB_ENV_EXTRAWHITE allows additional variables to pass through from
        # the external environment into Bitbake's datastore
        export BB_ENV_EXTRAWHITE="SRCREV_atf \
                                  SRCREV_linux_hpsc \
                                  SRCREV_u_boot"
        echo "Performing development build"
        echo "You may override the following environment variables:"
    else
        # Force git revisions for release
        export GIT_CHECKOUT_DEFAULT="$BUILD"
        unset SRCREV_atf
        unset SRCREV_linux_hpsc
        unset SRCREV_u_boot
        unset BB_ENV_EXTRAWHITE
        echo "Performing release build"
        echo "The following environment variables are fixed:"
    fi
    echo "  GIT_CHECKOUT_DEFAULT = $GIT_CHECKOUT_DEFAULT"
    echo "  SRCREV_DEFAULT       = $SRCREV_DEFAULT"
    echo "  SRCREV_atf           = $SRCREV_atf"
    echo "  SRCREV_linux_hpsc    = $SRCREV_linux_hpsc"
    echo "  SRCREV_u_boot        = $SRCREV_u_boot"
    echo ""

    #
    # If you need to pick specific revisions for individual repositories, edit
    # the values below.
    #

    # Repositories used for poky and its layer configuration
    export GIT_CHECKOUT_META_HPSC="$GIT_CHECKOUT_DEFAULT"
    export GIT_CHECKOUT_POKY="thud-20.0.0" # tag
    # meta-oe doesn't tag releases - choose a known revision on "thud" branch
    export GIT_CHECKOUT_META_OE="6094ae18c8a35e5cc9998ac39869390d7f3bb1e2"

    # Repositories not built by poky
    export GIT_CHECKOUT_BM="$GIT_CHECKOUT_DEFAULT"
    export GIT_CHECKOUT_UBOOT_R52="$GIT_CHECKOUT_DEFAULT"
    export GIT_CHECKOUT_HPSC_UTILS="$GIT_CHECKOUT_DEFAULT"
    export GIT_CHECKOUT_QEMU="$GIT_CHECKOUT_DEFAULT"
    export GIT_CHECKOUT_QEMU_DT="$GIT_CHECKOUT_DEFAULT"
}

function git_clone_fetch_bare()
{
    local repo=$1
    local dir=$2
    assert_str "$repo"
    assert_str "$dir"
    (
        set -e
        # Don't ask for credentials if requests are bad
        export GIT_TERMINAL_PROMPT=0 # for git > 2.3
        export GIT_ASKPASS=/bin/echo
        if [ ! -d "$dir" ]; then
            echo "$dir: clone bare: $repo"
            git clone --bare "$repo" "$dir"
        fi
        cd "$dir"
        # in case remote URI changed
        echo "$dir: set-url origin: $repo"
        git --bare remote set-url origin "$repo"
        # by default, bare git repo won't fetch anything...
        git config remote.origin.fetch 'refs/heads/*:refs/heads/*'
        echo "$dir: fetch"
        git --bare fetch origin --prune
    )
}

function git_clone_fetch_checkout()
{
    # repo is expected to be a filesystem directory - the full path is needed
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
        # in case remote URI changed (e.g., moved sources to a new system/path)
        echo "$dir: set-url origin: $repo"
        git remote set-url origin "$repo"
        echo "$dir: fetch"
        git fetch origin --prune
        echo "$dir: checkout: $checkout"
        git checkout "$checkout"
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
