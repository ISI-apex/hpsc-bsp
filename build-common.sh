#!/bin/bash
#
# Build scripts use this file for common functions.
#

function build_work_dirs()
{
    WORKING_DIR=$1
    mkdir -p "${WORKING_DIR}"
    mkdir -p "${WORKING_DIR}/src"
    mkdir -p "${WORKING_DIR}/work"
    mkdir -p "${WORKING_DIR}/env"
    mkdir -p "${WORKING_DIR}/stage"
}
