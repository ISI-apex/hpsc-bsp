#!/bin/bash
#
# Requires the bitbake environment to be active and working directory to be
# the poky build directory (where sourcing oe-init-build-env leaves us).
#
set -e

# Parse test module JSON file to get its recipe dependencies
function get_json_dependent_recipes()
{
    python -c "import sys, json
json = json.load(sys.stdin)
print '\n'.join([json[j]['pkg'] for j in json])" < "$1"
}

# Search layer for test module JSON files
function find_layer_test_mod_jsons()
{
    # per Yocto documentation, test cases always in: lib/oeqa/runtime/cases
    local tcdir="$1/lib/oeqa/runtime/cases"
    if test -d "$tcdir"; then
        find "$tcdir" -maxdepth 1 -name "*.json"
    fi
}

# Search layer for JSON-specified test dependencies
function find_layer_test_recipes_for_suites()
{
    local laydir=$1
    shift
    # grep expression replaces "suite1 suite2 ..." with "suite1|suite2|..." so
    # JSONS only matches specified test modules
    # NOTE: assumes no newline characters or leading/trailing whitespace
    local suite_e=$(echo "$*" | tr "[:blank:]" "|")
    if [ -z "$(echo "$suite_e" | tr -d "|")" ]; then
        # no test modules (or specified as empty string or whitespace) causes
        # function to match on all JSON files when we actually want to filter
        return 
    fi
    local JSONS=($(find_layer_test_mod_jsons "$laydir" | grep -E "$suite_e"))
    local RECIPES=()
    for f in "${JSONS[@]}"; do
        RECIPES+=($(get_json_dependent_recipes "$f"))
    done
    echo "${RECIPES[@]}" # note: may contain duplicate entries
}

function yocto_get_test_recipes()
{
    local TEST_SUITES=($(grep TEST_SUITES conf/local.conf | cut -d'=' -f2- | tr -d '"' | xargs))
    local LAYERS=($(bitbake-layers show-layers | tail -n +4 | awk '{print $2}'))
    local TRS=()
    for l in "${LAYERS[@]}"; do
        TRS+=($(find_layer_test_recipes_for_suites "$l" "${TEST_SUITES[@]}"))
    done
    # filter duplicate entries
    TEST_RECIPES=($(echo "${TRS[@]}" | tr ' ' '\n' | sort -u))
    echo "${TEST_RECIPES[@]}"
}

yocto_get_test_recipes
