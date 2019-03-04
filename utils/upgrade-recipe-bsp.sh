#!/bin/bash
#
# Upgrade GIT_REV for a BSP build recipe
#
set -e

# Ensure we're in BSP directory structure so git always operates on BSP repo,
# since we don't know where the script was actually executed from
BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
cd "$BSP_DIR"

function find_recipe()
{
    local file="${BSP_DIR}/build-recipes/$1.sh"
    if [ ! -f "$file" ]; then
        echo "Recipe not found: $file" >&2
        return 1
    fi
    echo "$file"
}

function find_srcrev()
{
    local recfile=$1
    local srcbranch=$2
    # locate the git repository
    local git_uri=$(grep GIT_REPO "$recfile" | cut -d'=' -f2 | tr -d '"')
    if [ -z "$git_uri" ]; then
        echo "Failed to determine git URI" >&2
        return 1
    fi
    # query for the HEAD of the branch
    local srcrev=$(git ls-remote "$git_uri" "$srcbranch" | awk '{print $1}')
    if [ -z "$srcrev" ]; then
        # branch doesn't exist?
        echo "Failed to get SRCREV from remote: $git_uri" >&2
        return 1
    fi
    echo "$srcrev"
}

function verify_recipe_git_status()
{
    if [ -n "$(git diff --name-only --cached)" ]; then
        echo "Repository has staged changes - commit or reset before proceeding"
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
    echo "                  if not specified, 'hpsc' is used"
    echo "    -a ACTION"
    echo "       upgrade: (default) upgrade the recipe"
    echo "       find-recipe: print the recipe file and exit"
    echo "       find-srcrev: query for and print the HEAD revision and exit"
    echo "    -c 1|0: whether to commit changes (1), or not (0); default = 0"
    echo "    -h: show this message and exit"
    exit 1
}

RECIPE=""
SRCREV=""
SRCBRANCH="hpsc"
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
               [ "$ACTION" != "find-srcrev" ]; then
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        c)
            IS_COMMIT="${OPTARG}"
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

# we always need the recipe file
REC_FILE=$(find_recipe "$RECIPE")
if [ "$ACTION" == "find-recipe" ]; then
    echo "$REC_FILE"
    exit 0
elif [ "$ACTION" == "find-srcrev" ]; then
    find_srcrev "$REC_FILE" "$SRCBRANCH"
    exit 0
fi
# else upgrade
echo "Using recipe file: $REC_FILE"

# verify current git status before we start making changes to files
if [ "$IS_COMMIT" -ne 0 ]; then
    verify_recipe_git_status
fi

# if not given SRCREV, we have to query the remote
if [ -z "$SRCREV" ]; then
    SRCREV="$(find_srcrev "$REC_FILE" "$SRCBRANCH")"
fi
echo "Using SRCREV: $SRCREV"

# update revision
if [ "$(grep -c GIT_REV "$REC_FILE")" -ne 1 ]; then
    echo "Exactly one instance of GIT_REV should exist in recipe"
    echo "Failed to upgrade recipe"
    exit 1
fi
sed -i "s/GIT_REV.*/GIT_REV=${SRCREV}/" "$REC_FILE"

if [ -n "$(git status -s "$REC_FILE")" ]; then
    echo "Recipe file upgraded: $REC_FILE"
    # commit change, if requested
    if [ "$IS_COMMIT" -ne 0 ]; then
        echo "Committing changes to recipe"
        git add "$REC_FILE"
        git commit -m "$RECIPE: upgrade to rev: $SRCREV"
        # TODO: optional push?
    else
        echo "You may now commit changes"
    fi
else
    echo "No changes to recipe file: $REC_FILE"
fi
