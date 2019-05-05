#!/bin/bash
#
# This script invokes Qemu on software binaries from the BSP,
# either from the binary release of BSP, or from a BSP built
# from a source release, using ./build-hpsc-bsp.sh. This script
# uses the launch-qemu tool from the Chiplet SDK.
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
#   * Python 2: with the following modules
#      - telnetlib : for communication with Qemu via QMP interface
#      - configparse : for config INI->BIN compiler (cfgc)
#      - json : for QMP and for cfgc

set -e

# Size of off-chip memory connected to TRCH SMC SRAM port,
# this size is here because this script creates the image.
LSIO_SRAM_SIZE=0x04000000           #  64MB

run() {
    echo "$@"
    "$@"
}

create_kern_image() {
    echo Packing the kernel binary into a U-boot image...
    run mkimage -C gzip -A arm64 -d "${HPPS_KERN_BIN}" -a ${HPPS_KERN_LOAD_ADDR} "${HPPS_KERN}"
}

create_syscfg_image()
{
    echo Compiling system config from INI to binary format...
    run ${SDK_TOOLS}/cfgc -s "${SYSCFG_SCHEMA}" "${SYSCFG}" "${SYSCFG_BIN}"
}

syscfg_get()
{
    python -c "import configparser as cp; c = cp.ConfigParser(); c.read('$SYSCFG'); print(c['$1']['$2'])"
}

function usage()
{
    echo "Usage: $0 [-h] [-i id] [ args ]" 1>&2
    echo "    args: arguments to forward to launch-qemu SDK tool" 1>&2
    echo "    -i id: numeric ID to identify the Qemu instance" 1>&2
    echo "    -h : show this message" 1>&2
}

ID=0

while getopts "h?i:" o; do
    case "${o}" in
        i)
            ID="$OPTARG"
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

QEMU_ENV=qemu-env.sh
source ${QEMU_ENV}
SDK_TOOLS=${BSP_DIR}/host-utils

mkdir -p "${RUN_DIR}"

ARGS+=(-i ${ID}) # we both use it here (via qemu-env.sh) and foward it

create_kern_image
create_syscfg_image

echo Creating TRCH SMC SRAM image and adding boot images...
SRAM_IMG_TOOL=${SDK_TOOLS}/sram-image-utils
run "${SRAM_IMG_TOOL}" create "${TRCH_SMC_SRAM}" ${LSIO_SRAM_SIZE}
run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${SYSCFG_BIN}"   "syscfg"  ${SYSCFG_ADDR}

# These config choices are not command-line switches, in order to eliminate the
# possibility of syscfg.ini being inconsistent with the command-line switch.
if [ "$(syscfg_get boot bin_loc)" = "DRAM" ]
then
    ARGS+=(-m "${CONF_DIR}/sw-images.qemu.preload.mem.map")
else
    echo "System configured to load SW images from TRCH SMC SRAM. Adding images..."
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${RTPS_BL}"      "rtps-bl" ${RTPS_BL_ADDR}
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${RTPS_APP}"     "rtps-os" ${RTPS_APP_ADDR}
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${HPPS_BL}"      "hpps-bl" ${HPPS_BL_ADDR}
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${HPPS_FW}"      "hpps-fw" ${HPPS_FW_ADDR}
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${HPPS_DT}"      "hpps-dt" ${HPPS_DT_ADDR}
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM}" "${HPPS_KERN}"    "hpps-os" ${HPPS_KERN_ADDR}
fi

if [ "$(syscfg_get HPPS rootfs_loc)" = "HPPS_DRAM" ]
then
    ARGS+=(-m "${CONF_DIR}/hpps-ramdisk.qemu.preload.mem.map")
fi

ARGS+=(-m "${CONF_DIR}/trch.qemu.preload.mem.map")

run "${SRAM_IMG_TOOL}" show "${TRCH_SMC_SRAM}"

# Networking: userspace mode, forward ports
ARGS+=(-n user -p 22 -p 2345)

# launch-qemu SDK tool assumes the SDK has been loaded into env
export PATH="${BSP_DIR}:${SDK_TOOLS}:$PATH"

run ${SDK_TOOLS}/launch-qemu -e ${QEMU_ENV} -d ${QEMU_DT} "${ARGS[@]}" "$@"
