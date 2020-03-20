#!/bin/bash
#
# This script invokes Qemu on software binaries from the BSP, from the binary
# release of BSP obtained from a binary release tarball or built using
# ./build-hpsc-bsp.sh. This script is NOT used to run the HPSC source release
# built in-place in BUILD/src for development, according to instructions in
# BUILD/src/ssw/hpsc-utils/doc/README.md
#
# This script uses the launch-qemu tool from the Chiplet SDK.
#
# Qemu is invoked on memory image with compiled system configuration.  In order
# to change system settings, the system configuration and the memory image
# needs to be rebuilt from the modified source files.  In a source release, the
# build system peforms this rebuild task as part of the edit-build-run
# workflow. In a binary release, which does not include a build system, this
# rebuild task is performed by this script. This way, the binary release
# supports a (limited) set of run configurations.
#
# In addition, less importantly, this script also peforms some build steps
# which could be but are not done as part of building the binary release
# (namely, packaging the Linux kernel into a u-boot image).
#
# Dependencies:
#   * uboot-tools : for creating U-boot images
#   * screen : for display of forwarded serial UART ports
#   * Python 3 with following modules (provided by python36u-libs on CentOS):
#      - telnetlib : for communication with Qemu via QMP interface
#      - configparse : for config INI->BIN compiler (cfgc)
#      - json : for QMP and for cfgc

set -e
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

run() {
    echo "$@"
    "$@"
}

function usage()
{
    echo "Usage: $0 [-h] [-e file]... -- [ args ]" 1>&2
    echo "    args: arguments to forward to launch-qemu SDK tool" 1>&2
    echo "    -e file: environment script, e.g., qemu-env.sh" 1>&2
    echo "    -h : show this message" 1>&2
}

QEMU_ENV=()
while getopts "h?e:" o; do
    case "${o}" in
        e)
            QEMU_ENV+=("$OPTARG")
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            echo "Wrong option" 1>&2
            usage
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

ARGS=()

if [ ${#QEMU_ENV[@]} -eq 0 ]; then
    # Use default configuration
    QEMU_ENV+=("${THIS_DIR}/qemu-env.sh")
fi
for env in "${QEMU_ENV[@]}"; do
    ARGS+=(-e "$(realpath $env)")
    echo Loading env file: "$env"
    source "$env"
done

# The following steps should be part of the building, not running. But, in the
# context of this binary release, there's no other place for them than here
# (see comment at top for more).

run mkimage -C gzip -A arm64 -d "${HPPS_KERN_BIN}" -a "${HPPS_KERN_LOAD_ADDR}" \
    "${HPPS_KERN}"

run "${SDK_TOOLS}/cfgc" -s "${SYSCFG_SCHEMA}" "${SYSCFG}" "${SYSCFG_BIN}"

run mkenvimage -s $HPPS_UBOOT_CONFIG_ENV_SIZE -o "${RUN_DIR}/hpps-u-boot.env.bin" \
    "${CONF_DIR}/hpps-u-boot.env"

run cc -E -C -nostdinc -x assembler-with-cpp -I"${QEMU_DT_DIR}" \
    -o "${RUN_DIR}/hpsc-arch.cpp.dts" "${QEMU_DT_DIR}/hpsc-arch.dts" \
    -DCONFIG_LSIO_SMC=1 \
    -DCONFIG_LSIO_SMC_SRAM__NVRAM=1 -DCONFIG_LSIO_SMC=1 -DCONFIG_LSIO_SMC_NAND=1 \
    -DCONFIG_TRCH_WDTS=1 -DCONFIG_RTPS_R52=1 -DCONFIG_RTPS_R52_WDTS=1 \
    -DCONFIG_RTPS_A53=1 -DCONFIG_RTPS_A53_WDTS=1 -DCONFIG_HPPS_A53=1 \
    -DCONFIG_HPPS_WDTS=1 -DCONFIG_TRCH_DMA=1 -DCONFIG_LSIO_MAILBOX=1 \
    -DCONFIG_HPPS_MAILBOX_0=1 -DCONFIG_HPPS_MAILBOX_1=1 -DCONFIG_HPPS_DDR_HI=1 \
    -DCONFIG_RTPS_R52=1 -DCONFIG_RTPS_R52_WDTS=1 -DCONFIG_LSIO_MAILBOX=1 \
    -DCONFIG_HPPS_MAILBOX_1=1 -DCONFIG_HPPS_A53=1 -DCONFIG_HPPS_SMMU=1 \
    -DCONFIG_HPPS_WDTS=1 -DCONFIG_HPPS_RTI_TIMERS=1 -DCONFIG_HPPS_DMA=1 \
    -DCONFIG_HPPS_SMC=1 -DCONFIG_HPPS_SMC_NAND=1 -DCONFIG_HPPS_MAILBOXES=1 \
    -DCONFIG_HPPS_MAILBOX_0=1 -DCONFIG_HPPS_A53_CL0=1 -DCONFIG_HPPS_A53_CL1=1 \
    -DCONFIG_ETH_CDNS=1 -DCONFIG_HPPS_A53=1 -DCONFIG_HPPS_A53=1 -DCONFIG_HPPS_SMC=1 \
    -DCONFIG_HPPS_A53=1 -DCONFIG_HPPS_A53=1 -DCONFIG_RTPS_DMA=1 -DCONFIG_RTPS_R52_RTI_TIMERS=1 \
    -DCONFIG_RTPS_SMMU=1

run dtc -q -I dts -O dtb -o "${RUN_DIR}/hpsc.dtb" "${RUN_DIR}/hpsc-arch.cpp.dts"
ARGS+=(-d "hpsc.dtb" )

RUN_DIR="${RUN_DIR}" CONF_DIR="${CONF_DIR}" \
    run "${SDK_TOOLS}/expandvars" -o "${RUN_DIR}/test.sfs.exp.mem.map" \
        "${CONF_DIR}/test.sfs.mem.map"
run "${SDK_TOOLS}/mksfs" m "${RUN_DIR}/test.sfs.mem.bin" \
    "${CONF_DIR}/test.sfs.ini" "${RUN_DIR}/test.sfs.exp.mem.map"
run "${SDK_TOOLS}/mksfs" s "${RUN_DIR}/test.sfs.mem.bin"

PROF_BLD="${SSW}" run "${SDK_TOOLS}/expandvars" \
    -o "${RUN_DIR}/preload.exp.mem.map" "${CONF_DIR}/preload.mem.map"

run "${SDK_TOOLS}/qemu-preload-mem" --root . --run-dir . -c "${CONF_DIR}/mem.ini" \
    -o "${RUN_DIR}/preload.mem.args" "${RUN_DIR}/preload.exp.mem.map"

ARGS+=(-a "preload.mem.args")

run "${SDK_TOOLS}/mkmemimg" -m lsio.smc.sram.0 -o "${RUN_DIR}/lsio.smc.sram.0.bin" \
    -c "${CONF_DIR}/mem.ini" "${RUN_DIR}/preload.exp.mem.map"

# Networking: userspace mode, forward ports
ARGS+=(-n user -p 22 -p 2345)

# launch-qemu SDK tool assumes the SDK has been loaded into env
export PATH="${SDK}:${SDK_TOOLS}:$PATH"

cd "${RUN_DIR}"
run exec "${SDK_TOOLS}/launch-qemu" "${ARGS[@]}" "$@"
