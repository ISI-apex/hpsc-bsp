#!/bin/bash

function usage()
{
    local rc=${1:-0}
    echo "Usage: $0 [-w DIR] [-h] -- [args]"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    echo "    args: arguments to forward (see '$0 -- -h')"
    exit "$rc"
}

WORKING_DIR="BUILD"
while getopts "w:h?" o; do
    case "$o" in
        w)
            WORKING_DIR="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage 1
            ;;
    esac
done
shift $((OPTIND-1))

"${WORKING_DIR}/deploy/test.sh" "$@"
