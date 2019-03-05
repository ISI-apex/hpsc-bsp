#!/bin/bash
#
# Upgrade SRCREV for a bitbake recipe.
# This is like a primitive version of Yocto's auto-upgrade-helper (AUH), without
# the X11 dependency, email generation, or advanced configuration files.
# Instead, we use the lower-level devtool (which AUH also wraps) and assume the
# recipe uses git for its SRC_URI.
#
set -e

function find_srcuri()
{
    local recfile=$1
    local srcuri=$(grep SRC_URI "$recfile" | cut -d'=' -f2- | tr -d '"' | xargs)
    if [ -z "$srcuri" ]; then
        echo "Failed to determine SRC_URI value from recipe" >&2
        return 1
    fi
    echo "$srcuri"
}

function find_srcbranch()
{
    local recfile=$1
    local srcuri=$2
    # check if 'SRCBRANCH' is specified in recipe
    local srcbranch=$(grep SRCBRANCH "$recfile" | cut -d'=' -f2 | tr -d '"' | xargs)
    if [ -z "$srcbranch" ]; then
        # try to parse branch from 'SRC_URI'
        IFS=';' read -ra TMPARR <<< "$(echo "$srcuri" | cut -d';' -f2-)"
        for prop in "${TMPARR[@]}"; do
            if [ "$(echo "$prop" | grep -c "branch=")" -eq 1 ]; then
                srcbranch=$(echo "$prop" | cut -d'=' -f2)
                break
            fi
        done
    fi
    if [ -z "$srcbranch" ]; then
        # fall back on default
        srcbranch=master
    fi
    echo "$srcbranch"
}

function find_srcrev()
{
    local srcuri=$1
    local srcbranch=$2
    # parse 'SRC_URI' for the git URI
    local gituri=$(echo "$srcuri" | cut -d';' -f1)
    if [ -z "$gituri" ]; then
        echo "Failed to determine git URI" >&2
        return 1
    fi
    # query for the HEAD of the branch
    local srcrev=$(git ls-remote "$gituri" "$srcbranch" | awk '{print $1}')
    if [ -z "$srcrev" ]; then
        # branch doesn't exist?
        echo "Failed to get SRCREV from remote: $gituri" >&2
        return 1
    fi
    echo "$srcrev"
}

function verify_recipe_git_status()
{
    local recfile=$1
    local laybranch=$2
    (
        # must be in the recipe's git repo directory structure
        cd "$(dirname "$recfile")"
        if [ -n "$(git diff --name-only --cached)" ]; then
            echo "Recipe's repository has staged changes -" \
                 "commit or reset before proceeding"
            return 1
        fi
        # the configure script likely checks out a detached HEAD, but we should
        # be on the HEAD of a branch when committing
        if ! git symbolic-ref --short -q HEAD > /dev/null; then
            echo "Recipe's repository has detached HEAD"
            # don't checkout "", we'll lose any local changes in the layer!
            if [ -z "$laybranch" ]; then
                echo "Need '-B LAYBRANCH' when layer is in detached HEAD state"
                return 1
            fi
            # check that what user requested is actually a branch
            if [ "$(git branch -a | cut -c 3- | grep -c "^${laybranch}$")" -ne 1 ]; then
                echo "LAYBRANCH did not match a known branch: $laybranch"
                echo "May need to pull layer branch from remote"
                return 1
            fi
            echo "Checking out layer branch: $laybranch"
            git checkout "$laybranch"
            # assert that we're now on a branch
            git symbolic-ref --short -q HEAD > /dev/null
        fi
    )
}

function usage()
{
    echo "Usage: $0 -r RECIPE [-s SRCREV] [-b SRCBRANCH] [-B LAYBRANCH] [-a <build>] [-c 1|0] [-w DIR] [-h]"
    echo "    -r RECIPE: the name of the recipe to upgrade"
    echo "               e.g.: arm-trusted-firmware, linux-hpsc, u-boot-hpps"
    echo "    -s SRCREV: the git revision hash to upgrade to"
    echo "               if not specified, the latest HEAD revision is queried"
    echo "    -b SRCBRANCH: the git branch that SRCREV is on"
    echo "                  if not specified, uses the recipe's current branch"
    echo "                  if that cannot be determined, 'master' is assumed"
    echo "    -B LAYBRANCH: the layer branch - usually required when committing"
    echo "                  (avoids committing on detached HEAD from layer's BSP recipe)"
    echo "    -a ACTION: additional actions to run:"
    echo "       build: test building the upgraded recipe (can be slow);"
    echo "              requires building cross-compiler, sysroot, and dependencies"
    echo "    -c 1|0: whether to commit changes (1), or not (0); default = 0"
    echo "    -w DIR: set the working directory (default=\"DEVEL\")"
    echo "            (should be different than the normal BSP build directory)"
    echo "    -h: show this message and exit"
    exit 1
}

RECIPE=""
SRCREV=""
SRCBRANCH=""
LAYBRANCH=""
IS_BUILD=0
IS_COMMIT=0
WORKING_DIR="DEVEL"
while getopts "r:s:b:B:a:c:w:h?" o; do
    case "$o" in
        r)
            RECIPE="${OPTARG}"
            ;;
        s)
            SRCREV="${OPTARG}"
            ;;
        b)
            SRCBRANCH="${OPTARG}"
            ;;
        B)
            LAYBRANCH="${OPTARG}"
            ;;
        a)
            if [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        c)
            IS_COMMIT="${OPTARG}"
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
if [ -z "$RECIPE" ]; then
    usage
fi

# initialize the environment for devtool
BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
source "${BSP_DIR}/configure-hpsc-yocto-env.sh" -w "$WORKING_DIR"

# devtool doesn't appear able to determine the latest revision on its own, so
# we have to parse the recipe to get the git remote, then query it
echo "Running 'find-recipe'..."
FIND_REC_OUT=$(devtool find-recipe "$RECIPE") || (
    echo "$FIND_REC_OUT"
    exit 1
)
REC_FILE=$(echo "$FIND_REC_OUT" | tail -n 1)
echo "Using recipe file: $REC_FILE"

# verify current git status before we start making changes to files
if [ "$IS_COMMIT" -ne 0 ]; then
    verify_recipe_git_status "$REC_FILE" "$LAYBRANCH"
fi

# get the 'SRC_URI' value from the recipe
SRC_URI=$(find_srcuri "$REC_FILE")
echo "Using SRC_URI: $SRC_URI"

# a branch must be known if we have to query the remote for the latest HEAD
# also, devtool fails if it finds multiple branches with SRCREV
if [ -z "$SRCBRANCH" ]; then
    # check if 'SRCBRANCH' is specified in recipe
    SRCBRANCH=$(find_srcbranch "$REC_FILE" "$SRC_URI")
fi
echo "Using SRCBRANCH: $SRCBRANCH"

# if not given SRCREV, we have to query the remote
if [ -z "$SRCREV" ]; then
    SRCREV=$(find_srcrev "$SRC_URI" "$SRCBRANCH")
fi
echo "Using SRCREV: $SRCREV"

# now we can do the real work...

WORKSPACE="workspace/sources/${RECIPE}" # to be created by devtool
function cleanup {
    # remove the recipe's workspace source tree to avoid error on next upgrade
    if [ -d "$WORKSPACE" ]; then
        echo "Cleaning up workspace: $WORKSPACE"
        rm -rf "$WORKSPACE"
    else
        echo "Workspace not found in expected location: $WORKSPACE"
        echo "  Please clean up manually"
    fi
}
function reset_cleanup {
    # A 'reset' aborts the workspace changes and removes the workspace entry.
    # It doesn't actually delete the source files in the workspace though.
    # If reset fails, it probably means the workspace wasn't created, so perform
    # cleanup anyway (don't let function abort).
    echo "Running 'reset'..."
    devtool reset -n "$RECIPE" || true
    cleanup
}

trap reset_cleanup EXIT
# 'upgrade' creates a workspace entry for the recipe and tries to upgrade it
echo "Running 'upgrade'..."
devtool upgrade "$RECIPE" -S "$SRCREV" -B "$SRCBRANCH"
if [ $IS_BUILD -ne 0 ]; then
    # 'build' has a lot of dependencies, like building cross-compilers
    echo "Running 'build'..."
    devtool build "$RECIPE"
fi
# 'finish' copies changes to the original layer and removes the workspace entry
# it doesn't actually delete the source files in the workspace though
echo "Running 'finish'..."
devtool finish "$RECIPE" "$(dirname "$REC_FILE")"
# can't allow 'reset' anymore, just cleanup the old workspace source tree
trap cleanup EXIT

if [ -n "$(git status -s "$REC_FILE")" ]; then
    echo "Recipe file upgraded: $REC_FILE"
    # commit change, if requested
    if [ "$IS_COMMIT" -ne 0 ]; then
        echo "Committing changes to recipe"
        (
            cd "$(dirname "$REC_FILE")"
            git add "$REC_FILE"
            git commit -m "$RECIPE: upgrade to rev: $SRCREV"
            # TODO: optional push?
        )
    else
        echo "You may now commit changes"
    fi
else
    echo "No changes to recipe file: $REC_FILE"
fi
