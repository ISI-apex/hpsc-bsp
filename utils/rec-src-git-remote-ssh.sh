#!/bin/bash
#
# Change the remote URL from https to ssh for a recipe's src clone.
# Note that when the 'fetch' action is re-run by the BSP build scripts, the
# src clone's remote URL will be reset to what's specified in the build recipe.
#

function git_remote_upstream_get()
{
    local ref
    ref=$(git rev-parse --abbrev-ref @{u}) || return $?
    echo "$ref" | cut -d'/' -f1
}

function git_remote_url_get()
{
    git config --get "remote.${1}.url" $ # $1 = remote
}

function git_remote_url_set()
{
    git remote set-url "$1" "$2" # $1 = remote, $2 = url
}

function https_to_ssh_github()
{
    echo "${1/https:\/\/github\.com\//git@github.com:}"
}

function is_https_github()
{
    [[ "$1" =~ ^https://github.com/ ]] || return 1
}

function is_ssh_github()
{
    [[ "$1" =~ ^git@github.com: ]] || return 1
}

function set_remote_url_ssh_github()
{
    local remote=$1
    local url_orig url_ssh
    url_orig=$(git_remote_url_get "$remote") || return $?
    if is_https_github "$url_orig"; then
        echo "Found HTTPS URL: $url_orig"
        url_ssh=$(https_to_ssh_github "$url_orig")
        echo "Setting SSH URL: $url_ssh"
        git_remote_url_set "$remote" "$url_ssh" || return $?
    elif is_ssh_github "$url_orig"; then
        echo "Found (and keeping) SSH URL: $url_orig"
    else
        >&2 echo "Unexpected URL format: $url_orig"
        return 1
    fi
}

function usage()
{
    echo "Change the remote URL from https to ssh for a recipe's src clone."
    echo ""
    echo "WARNING: Typically this is only useful when auto-upgrading Yocto layers, e.g.,"
    echo "         after using 'upgrade-recipe-yocto.sh'."
    echo "         Don't forget to use the correct value with \"-w\" (e.g., \"-w DEVEL\")."
    echo ""
    echo "Usage: $0 -r RECIPE -w DIR [-n REMOTE] [-h]"
    echo "    -r RECIPE: the recipe to change remote URL for in the src clone"
    echo "    -w DIR: set the working directory"
    echo "    -n REMOTE: remote name (remote must already be defined)"
    echo "               by default, checks for current branch's upstream"
    echo "               'origin' is usually the only remote, unless you added others"
    echo "    -h: show this message and exit"
}

RECIPE=
WORKING_DIR=
REMOTE_NAME=
while getopts "r:w:n:h?" o; do
    case "$o" in
        r)
            RECIPE=$OPTARG
            ;;
        w)
            WORKING_DIR=$OPTARG
            ;;
        h)
            usage
            exit
            ;;
        n)
            REMOTE_NAME=$OPTARG
            ;;
        *)
            >&2 usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$RECIPE" ] || [ -z "$WORKING_DIR" ]; then
    >&2 usage
    exit 1
fi

SRC_DIR="${WORKING_DIR}/src/${RECIPE}"
if [ ! -d "$SRC_DIR" ]; then
    >&2 echo "Recipe src directory not found: $SRC_DIR"
    exit 1
fi
(
    cd "$SRC_DIR" || exit $?
    if [ -z "$REMOTE_NAME" ]; then
        REMOTE_NAME=$(git_remote_upstream_get) || exit $?
    fi
    if ! git_remote_url_get "$REMOTE_NAME" > /dev/null; then
        >&2 echo "Remote not defined, or no URL: $REMOTE_NAME"
        exit 1
    fi
    set_remote_url_ssh_github "$REMOTE_NAME"
)
