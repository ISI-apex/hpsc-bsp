#!/bin/bash
#
# Upgrade GIT_REV for a BSP build recipe
#

# Ensure we're in BSP directory structure so git always operates on BSP repo,
# since we don't know where the script was actually executed from
BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
cd "$BSP_DIR" || exit $?

function find_recipe()
{
    local file="${BSP_DIR}/build-recipes/$1.sh"
    if [ ! -f "$file" ]; then
        echo "Recipe not found: $file" >&2
        return 1
    fi
    echo "$file"
}

function find_srcbranch()
{
    local recfile=$1
    local srcbranch
    srcbranch=$(grep GIT_BRANCH "$recfile" | cut -d'=' -f2 | tr -d '"')
    if [ -z "$srcbranch" ]; then
        echo "Failed to get SRCBRANCH from recipe: $recfile" >&2
        return 1
    fi
    echo "$srcbranch"
}

function find_srcrev()
{
    local recfile=$1
    local srcbranch=$2
    # locate the git repository
    local git_uri
    git_uri=$(grep GIT_REPO "$recfile" | cut -d'=' -f2 | tr -d '"')
    if [ -z "$git_uri" ]; then
        echo "Failed to determine git URI" >&2
        return 1
    fi
    # query for the HEAD of the branch
    local matches
    local srcrev
    matches=$(git ls-remote -h "$git_uri" "$srcbranch") || return $?
    srcrev=$(echo "$matches" | awk '{print $1}')
    if [ -z "$srcrev" ]; then
        # branch doesn't exist?
        echo "Failed to get SRCREV from remote: $git_uri" >&2
        return 1
    fi
    echo "$srcrev"
}

function verify_recipe_git_status()
{
    if ! git diff-index --cached --quiet HEAD --; then
        echo "Repository has staged changes - commit or reset before proceeding" >&2
        return 1
    fi
    if ! git symbolic-ref --short -q HEAD > /dev/null; then
        echo "Repository is in detached HEAD state - switch to a branch HEAD before proceeding" >&2
        return 1
    fi
}

function usage()
{
    echo "Usage: $0 -r RECIPE [-s SRCREV] [-b SRCBRANCH] [-a ACTION] [-c 1|0] [-h]"
    echo "    -r RECIPE: the name of the recipe to upgrade"
    echo "    -s SRCREV: the git revision hash to upgrade to;"
    echo "               if not specified, the latest HEAD of SRCBRANCH is queried"
    echo "    -b SRCBRANCH: the git branch to use;"
    echo "                  if not specified, it is searched for in the recipe"
    echo "    -a ACTION"
    echo "       upgrade: (default) upgrade the recipe"
    echo "       find-recipe: print the recipe file and exit"
    echo "       find-srcbranch: print the branch to use and exit"
    echo "       find-srcrev: query for and print the HEAD revision and exit"
    echo "    -c 1|0: whether to commit changes (1), or not (0); default = 0"
    echo "    -h: show this message and exit"
}

RECIPE=""
SRCREV=""
SRCBRANCH=""
ACTION="upgrade"
IS_COMMIT=0
while getopts "r:s:b:a:c:p:h?" o; do
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
        a)
            ACTION="${OPTARG}"
            if [ "$ACTION" != "upgrade" ] &&
               [ "$ACTION" != "find-recipe" ] &&
               [ "$ACTION" != "find-srcbranch" ] &&
               [ "$ACTION" != "find-srcrev" ]; then
                echo "Error: no such action: ${OPTARG}"
                usage >&2
                exit 1
            fi
            ;;
        c)
            IS_COMMIT="${OPTARG}"
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option"
            usage >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$RECIPE" ]; then
    usage >&2
    exit 1
fi

# we always need the recipe file
REC_FILE=$(find_recipe "$RECIPE") || exit $?
if [ "$ACTION" == "find-recipe" ]; then
    echo "$REC_FILE"
    exit 0
fi

# perform some simple verification of recipe content
for var in "GIT_REPO" "GIT_REV" "GIT_BRANCH"; do
    if [ "$(grep -c "$var=" "$REC_FILE")" -ne 1 ]; then
        echo "Exactly one instance of $var should exist in recipe" >&2
        echo "Failed to upgrade recipe" >&2
        exit 1
    fi
done

# we need SRCBRANCH if it was requested or if SRCREV wasn't provided
if [ -z "$SRCBRANCH" ]; then
    SRCBRANCH=$(find_srcbranch "$REC_FILE") || exit $?
fi
if [ "$ACTION" == "find-srcbranch" ]; then
    find_srcbranch "$REC_FILE"
    exit $?
elif [ "$ACTION" == "find-srcrev" ]; then
    find_srcrev "$REC_FILE" "$SRCBRANCH"
    exit $?
fi
# else upgrade
echo "Using recipe file: $REC_FILE"

# verify current git status before we start making changes to files
if [ "$IS_COMMIT" -ne 0 ]; then
    verify_recipe_git_status || exit $?
fi

# if not given SRCREV, we have to query the remote
if [ -z "$SRCREV" ]; then
    SRCREV=$(find_srcrev "$REC_FILE" "$SRCBRANCH") || exit $?
fi
echo "Using SRCREV: $SRCREV"

# update revision
sed -i "s/GIT_REV=.*/GIT_REV=${SRCREV}/" "$REC_FILE"
sed -i "s/GIT_BRANCH=.*/GIT_BRANCH=${SRCBRANCH}/" "$REC_FILE"

# Sometimes have problems with `git diff-index --quiet HEAD -- "$REC_FILE"`
# returning bad exit code when $REC_FILE uncached? So add first, then check
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
        git commit -m "$RECIPE: upgrade to rev: $shortrev" || {
            rc=$?
            echo "Commit failed" >&2
            exit $rc
        }
        # TODO: optional push?
    else
        echo "You may now commit changes"
    fi
fi
