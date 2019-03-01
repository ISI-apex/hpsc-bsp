#!/bin/bash
#
# Upgrade GIT_REV for a BSP build recipe
#
set -e

function usage()
{
    echo "Usage: $0 -r RECIPE [-s SRCREV] [-h]"
    echo "    -r RECIPE: the name of the recipe to upgrade"
    echo "    -s SRCREV: the git revision hash to upgrade to;"
    echo "               if not specified, the latest 'hpsc' HEAD is queried"
    echo "    -h: show this message and exit"
    exit 1
}

RECIPE=""
SRCREV=""
SRCBRANCH="hpsc" # placeholder if we need to support other branches
while getopts "r:s:h?" o; do
    case "$o" in
        r)
            RECIPE="${OPTARG}"
            ;;
        s)
            SRCREV="${OPTARG}"
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

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd .. && pwd)"
REC_FILE="${BSP_DIR}/build-recipes/${RECIPE}.sh"
if [ ! -f "$REC_FILE" ]; then
    echo "Recipe not found: $REC_FILE"
    exit 1
fi
echo "Using recipe file: $REC_FILE"

# if not given SRCREV, we have to query the remote
if [ -z "$SRCREV" ]; then
    # locate the git repository
    GIT_URI=$(grep GIT_REPO "$REC_FILE" | cut -d'=' -f2 | tr -d '"')
    if [ -z "$GIT_URI" ]; then
        echo "Failed to determine git URI"
        exit 1
    fi
    # query for the HEAD of the branch
    SRCREV=$(git ls-remote "$GIT_URI" "$SRCBRANCH" | awk '{print $1}')
    if [ -z "$SRCREV" ]; then
        # branch doesn't exist?
        echo "Failed to get SRCREV from remote: $GIT_URI"
        exit 1
    fi
fi
echo "Using SRCREV: $SRCREV"

# update revision
if [ "$(grep -c GIT_REV "$REC_FILE")" -ne 1 ]; then
    echo "Exactly one instance of GIT_REV should exist in recipe"
    echo "Failed to upgrade recipe"
    exit 1
fi
sed -i "s/GIT_REV.*/GIT_REV=${SRCREV}/" "$REC_FILE"

echo "Recipe $RECIPE upgraded, you may now commit changes: $REC_FILE"
