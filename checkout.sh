#!/bin/bash

# Don't support overriding to keep CLI simple.
WORKING_DIR="BUILD"
SNAPSHOTS_FILE=snapshots.sh

"${WORKING_DIR}/deploy/checkout.sh" -s "${SNAPSHOTS_FILE}" "$@"
