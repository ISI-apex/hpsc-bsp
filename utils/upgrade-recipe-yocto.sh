#!/bin/bash
#
# Upgrade SRCREV for a bitbake recipe.
# This is like a primitive version of Yocto's auto-upgrade-helper (AUH), without
# the X11 dependency, email generation, or advanced configuration files.
# Instead, we use the lower-level devtool (which AUH also wraps) and assume the
# recipe uses git for its SRC_URI.
#

function find_srcuri()
{
    local recfile=$1
    local srcuri
    srcuri=$(grep SRC_URI "$recfile" | cut -d'=' -f2- | tr -d '"' | xargs)
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
    local srcbranch
    srcbranch=$(grep SRCBRANCH "$recfile" | cut -d'=' -f2 | tr -d '"' | xargs)
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
    local gituri
    gituri=$(echo "$srcuri" | cut -d';' -f1)
    if [ -z "$gituri" ]; then
        echo "Failed to determine git URI" >&2
        return 1
    fi
    # query for the HEAD of the branch
    local matches
    local srcrev
    matches=$(git ls-remote -h "$gituri" "$srcbranch") || return $?
    srcrev=$(echo "$matches" | awk '{print $1}')
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
    local layremote=$3
    (
        # must be in the recipe's git repo directory structure
        cd "$(dirname "$recfile")" || return $?
        if ! git diff-index --cached --quiet HEAD --; then
            echo "Recipe's repository has staged changes -" \
                 "commit or reset before proceeding" >&2
            return 1
        fi
        # the configure script likely checks out a detached HEAD, but we should
        # be on the HEAD of a branch when committing
        if ! git symbolic-ref --short -q HEAD > /dev/null; then
            echo "Recipe's repository has detached HEAD"
            if [ -z "$laybranch" ]; then
                echo "Need '-B LAYBRANCH' when layer is in detached HEAD state" >&2
                return 1
            fi
        fi
        if [ -n "$laybranch" ]; then
            # check that value is actually a branch, not a commit or tree-ish
            if ! git show-ref --verify --quiet "refs/heads/$laybranch"; then
                echo "Layer branch not found: $laybranch" >&2
                return 1
            fi
            echo "Checking out layer branch: $laybranch"
            git checkout "$laybranch" -- || return $?
        fi
        echo "Pulling from layer remote: $layremote"
        git pull --ff-only "$layremote" || return $?
    )
}

function usage()
{
    echo "Usage: $0 -r RECIPE [-s SRCREV] [-b SRCBRANCH] [-B LAYBRANCH]" \
         "[-B LAYREMOTE] [-a <build>] [-c 1|0] [-w DIR] [-h]"
    echo "    -r RECIPE: the name of the recipe to upgrade"
    echo "               e.g.: arm-trusted-firmware, linux-hpsc, u-boot-hpps"
    echo "    -s SRCREV: the git revision hash to upgrade to"
    echo "               if not specified, the latest HEAD revision is queried"
    echo "    -b SRCBRANCH: the git branch that SRCREV is on"
    echo "                  if not specified, uses the recipe's current branch"
    echo "                  if that cannot be determined, 'master' is assumed"
    echo "    -B LAYBRANCH: the layer branch"
    echo "                  (avoids working on detached HEAD from layer's BSP recipe)"
    echo "    -O LAYREMOTE: the layer remote to pull from, defaults to 'origin'"
    echo "    -a ACTION: additional actions to run:"
    echo "       build: test building the upgraded recipe (can be slow);"
    echo "              requires building cross-compiler, sysroot, and dependencies"
    echo "    -c 1|0: whether to commit changes (1), or not (0); default = 0"
    echo "    -w DIR: set the working directory (default=\"DEVEL\")"
    echo "            (should be different than the normal BSP build directory)"
    echo "    -h: show this message and exit"
}

UP_RECIPE=""
SRCREV=""
SRCBRANCH=""
LAYBRANCH=""
LAYREMOTE="origin"
IS_BUILD=0
IS_COMMIT=0
WORKING_DIR="DEVEL"
while getopts "r:s:b:B:a:c:w:h?" o; do
    case "$o" in
        r)
            UP_RECIPE="${OPTARG}"
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
        O)
            LAYREMOTE="${OPTARG}"
            ;;
        a)
            if [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage >&2
                exit 1
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
            exit
            ;;
        *)
            echo "Unknown option"
            usage >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$UP_RECIPE" ]; then
    usage >&2
    exit 1
fi

# initialize the environment for devtool
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "${THIS_DIR}/configure-hpsc-yocto-env.sh" -w "$WORKING_DIR" || exit $?

# devtool doesn't appear able to determine the latest revision on its own, so
# we have to parse the recipe to get the git remote, then query it
echo "Running 'find-recipe'..."
FIND_REC_OUT=$(devtool find-recipe "$UP_RECIPE") || {
    echo "$FIND_REC_OUT"
    exit 1
}
REC_FILE=$(echo "$FIND_REC_OUT" | tail -n 1)
echo "Using recipe file: $REC_FILE"

# verify current git status before we start making changes to files
verify_recipe_git_status "$REC_FILE" "$LAYBRANCH" "$LAYREMOTE" || exit $?

# get the 'SRC_URI' value from the recipe
SRC_URI=$(find_srcuri "$REC_FILE") || exit $?
echo "Using SRC_URI: $SRC_URI"

# a branch must be known if we have to query the remote for the latest HEAD
# also, devtool fails if it finds multiple branches with SRCREV
if [ -z "$SRCBRANCH" ]; then
    # check if 'SRCBRANCH' is specified in recipe
    SRCBRANCH=$(find_srcbranch "$REC_FILE" "$SRC_URI") || exit $?
fi
echo "Using SRCBRANCH: $SRCBRANCH"

# if not given SRCREV, we have to query the remote
if [ -z "$SRCREV" ]; then
    SRCREV=$(find_srcrev "$SRC_URI" "$SRCBRANCH") || exit $?
fi
echo "Using SRCREV: $SRCREV"

# now we can do the real work...

WORKSPACE="workspace/sources/${UP_RECIPE}" # to be created by devtool
function cleanup {
    # remove the recipe's workspace source tree to avoid error on next upgrade
    if [ -d "$WORKSPACE" ]; then
        echo "Cleaning up workspace: $WORKSPACE"
        rm -rf "$WORKSPACE"
    else
        echo "Workspace not found in expected location: $WORKSPACE" >&2
        echo "  Please clean up manually" >&2
    fi
}
function reset_cleanup {
    # A 'reset' aborts the workspace changes and removes the workspace entry.
    # It doesn't actually delete the source files in the workspace though.
    # If reset fails, it probably means the workspace wasn't created, so perform
    # cleanup anyway (don't let function abort).
    echo "Running 'reset'..."
    devtool reset -n "$UP_RECIPE" # ignore return code
    cleanup
}

trap reset_cleanup EXIT
# 'upgrade' creates a workspace entry for the recipe and tries to upgrade it
echo "Running 'upgrade'..."
devtool upgrade "$UP_RECIPE" -S "$SRCREV" -B "$SRCBRANCH" || exit $?
if [ $IS_BUILD -ne 0 ]; then
    # 'build' has a lot of dependencies, like building cross-compilers
    echo "Running 'build'..."
    devtool build "$UP_RECIPE" || exit $?
fi
# 'finish' copies changes to the original layer and removes the workspace entry
# it doesn't actually delete the source files in the workspace though
echo "Running 'finish'..."
devtool finish "$UP_RECIPE" "$(dirname "$REC_FILE")" || exit $?
# can't allow 'reset' anymore, just cleanup the old workspace source tree
trap - EXIT
cleanup

(
    cd "$(dirname "$REC_FILE")" || exit $?
    git add "$REC_FILE" || exit $?
    if git diff-index --cached --quiet HEAD -- "$REC_FILE"; then
        echo "No changes to recipe file: $REC_FILE"
    else
        echo "Recipe file upgraded: $REC_FILE"
        # commit change, if requested
        if [ "$IS_COMMIT" -ne 0 ]; then
            echo "Committing changes to recipe"
            shortrev=$(git rev-parse --short "$SRCREV") || {
                rc=$?
                echo "Failed to get short revision for commit message" >&2
                exit $rc
            }
            git commit -m "$UP_RECIPE: upgrade to rev: $shortrev" || {
                rc=$?
                echo "Commit failed" >&2
                exit $rc
            }
            # TODO: optional push?
        else
            echo "You may now commit changes"
        fi
    fi
)
