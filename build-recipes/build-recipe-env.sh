#!/bin/bash
#
# Export a recipe's environment.
#
# This script is sourced prior to executing a recipe's build lifecycle.
# It may also be used to configure an interactive shell environment, e.g., to
# assist in recipe development or debugging.
#

# This script is sourced, it must not set -e
# set -e
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

function usage()
{
    echo "Usage: $0 -r RECIPE -w DIR [-h]"
    echo "    -r RECIPE: recipe to setup the environment for"
    echo "    -w DIR: set the working directory"
    echo "    -h: show this message and exit"
}

# Script options
RECIPE=""
WORKING_DIR=""
OPTIND=1 # reset since we're probably being sourced
while getopts "r:w:h?" o; do
    case "$o" in
        r)
            RECIPE="${OPTARG}"
            ;;
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            return
            ;;
        *)
            echo "Unknown option"
            usage
            return 1
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$RECIPE" ] || [ -z "$WORKING_DIR" ]; then
    usage
    return 1
fi
cd "$WORKING_DIR" || return $?

function build_recipe_export_env_base()
{
    local recname=$1
    # recipes extend the ENV script
    source "${THIS_DIR}/ENV.sh" || return $?
    # variables for recipes
    export ENV_WORKING_DIR="${PWD}"
    export ENV_DEPLOY_DIR="${ENV_WORKING_DIR}/deploy"
    export REC_UTIL_DIR="${THIS_DIR}/${recname}/utils"
    export REC_SRC_DIR="${ENV_WORKING_DIR}/src/${recname}"
    export REC_WORK_DIR="${ENV_WORKING_DIR}/work/${recname}"
    export REC_ENV_DIR="${ENV_WORKING_DIR}/env" # shared b/w recipes, shhh... ;)
    source "${THIS_DIR}/${recname}.sh"
}

function build_recipe_export_env_with_deps()
{
    local recname=$1
    # we really just want DEPENDS_ENVIRONMENT to begin with
    build_recipe_export_env_base "$recname" || return $?
    # cache DEPENDS_ENVIRONMENT since it will be overridden by dependencies
    IFS=':' read -ra DEP_ENV_CACHE <<< "$DEPENDS_ENVIRONMENT"
    for de in "${DEP_ENV_CACHE[@]}"; do
        echo "$recname: depends: $de"
        build_recipe_export_env_base "$de" || return $?
    done
    # now that we have exported from dependencies, we need our own environment
    build_recipe_export_env_base "$recname"
}

build_recipe_export_env_with_deps "$RECIPE"
