#!/bin/bash

run() {
    echo "$@"
    "$@"
}

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export RUN_DIR=$PWD/run # export for run-qemu.sh

# Some tests connect to the target via SSH. Must be configured in .ssh/config:
#       Host hpsc-hpps-qemu
#            HostName localhost
#            User root
#            Port 3088 # take from output of run target
#            StrictHostKeyChecking no
#            UserKnownHostsFile=/dev/null
TARGET_HOST=hpsc-hpps-qemu

# The binary release is a build of one particular configuration. As any one
# configuration, this configuration supports only a subset of tests.
#
# To build and run all configurations, build from source in BUILD/src
# (see instructions in BUILD/src/ssw/hpsc-utils/doc/README.md).

TESTS_FILTER="\
       TestDMA \
    or TestCPUHotplug \
    or TestIntAffinity \
    or TestMailbox \
    or TestMailboxMultiSystem \
    or TestSharedMem \
    or TestRTITimer \
"
# These tests require reboot, but the binary release build configuration
# preloads binaries so can't reboot. To run these tests, build from source (see
# comment above) and invoke these tests against a configuration profile that
# has them enabled.
#   TestSRAM
#   TestWDTimer
#   TestNAND

SDK_TOOLS="${BSP_DIR}/sdk/tools"
TESTS_DIR="${BSP_DIR}/ssw/tests"

export PYTHONPATH="${SDK_TOOLS}:$PYTHONPATH"

echo "Monitor each serial console log file with 'tail -f ${RUN_DIR}/logs/PORT.log"
cd "${TESTS_DIR}"
pytest -sv --durations=0 --host "$TARGET_HOST" \
    --run-dir="${RUN_DIR}" \
    --qemu-cmd="${BSP_DIR}/run-qemu.sh -e ${BSP_DIR}/qemu-env.sh -- -S -D" \
    -k "${TESTS_FILTER[@]}" "$@"
