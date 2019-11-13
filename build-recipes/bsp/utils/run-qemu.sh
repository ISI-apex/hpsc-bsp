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
#   * Python 3 with following modules (provided by python36u-libs on CentOS):
#      - telnetlib : for communication with Qemu via QMP interface
#      - configparse : for config INI->BIN compiler (cfgc)
#      - json : for QMP and for cfgc

set -e
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Size of off-chip memory connected to TRCH SMC SRAM port,
# this size is here because this script creates the image.
LSIO_SRAM_SIZE0=0x02000000           #  32MB
LSIO_SRAM_SIZE2=0x02000000           #  32MB

run() {
    echo "$@"
    "$@"
}

create_kern_image() {
    echo Packing the kernel binary into a U-boot image...
    run mkimage -C gzip -A arm64 -d "${HPPS_KERN_BIN}" -a "${HPPS_KERN_LOAD_ADDR}" "${HPPS_KERN}"
}

create_syscfg_image()
{
    echo Compiling system config from INI to binary format...
    run "${SDK_TOOLS}/cfgc" -s "${SYSCFG_SCHEMA}" "${SYSCFG}" "${SYSCFG_BIN}"
}

syscfg_get()
{
    python3 -c "import configparser as cp; c = cp.ConfigParser(); c.read('$SYSCFG'); print(c['$1']['$2'])"
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
    ARGS+=(-e "$env")
    source "$env"
done

ARGS+=(-d "${QEMU_DT}")

mkdir -p "${RUN_DIR}"

create_kern_image
create_syscfg_image

echo "Creating TRCH SMC SRAM image and adding boot images..."
SRAM_IMG_TOOL=${SDK_TOOLS}/sram-image-utils
run "${SRAM_IMG_TOOL}" create "${TRCH_SMC_SRAM0}" "${LSIO_SRAM_SIZE0}"
run "${SRAM_IMG_TOOL}" b "${TRCH_SMC_SRAM0}" "${TRCH_APP_BIN}" "${TRCH_APP_ADDR}" "${TRCH_APP_ENTRY_ADDR}"
run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${SYSCFG_BIN}"   "syscfg"  "${SYSCFG_ADDR}" 0x0
run "cp" "${TRCH_SMC_SRAM0}" "${TRCH_SMC_SRAM1}"

run "${SRAM_IMG_TOOL}" create "${TRCH_SMC_SRAM2}" "${LSIO_SRAM_SIZE2}"
run "${SRAM_IMG_TOOL}" b "${TRCH_SMC_SRAM2}" "${TRCH_APP_BIN}" "${TRCH_APP_ADDR}" "${TRCH_APP_ENTRY_ADDR}"
run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${SYSCFG_BIN}"   "syscfg"  "${SYSCFG_ADDR}" 0x0
run "cp" "${TRCH_SMC_SRAM2}" "${TRCH_SMC_SRAM3}"

# These config choices are not command-line switches, in order to eliminate the
# possibility of syscfg.ini being inconsistent with the command-line switch.
if [ "$(syscfg_get boot bin_loc)" = "DRAM" ]
then
    echo "System configured to load SW images from DRAM..." 
    ARGS+=(-m "${CONF_DIR}/sw-images.qemu.preload.mem.map")
else
    echo "System configured to load SW images from TRCH SMC SRAM. Adding images..."
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${RTPS_BL}"      "rtps-bl" "${RTPS_BL_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${RTPS_APP}"     "rtps-os" "${RTPS_APP_ADDR}" 0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${HPPS_BL}"      "hpps-bl" "${HPPS_BL_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${HPPS_BL_DT}"   "hpps-bl-dt" "${HPPS_BL_DT_ADDR}" 0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${HPPS_FW}"      "hpps-fw" "${HPPS_FW_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${HPPS_DT}"      "hpps-dt" "${HPPS_DT_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM0}" "${HPPS_KERN}"    "hpps-os" "${HPPS_KERN_ADDR}" 0x0
    run "cp" "${TRCH_SMC_SRAM0}" "${TRCH_SMC_SRAM1}"
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${RTPS_BL}"      "rtps-bl" "${RTPS_BL_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${RTPS_APP}"     "rtps-os" "${RTPS_APP_ADDR}" 0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${HPPS_BL}"      "hpps-bl" "${HPPS_BL_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${HPPS_BL_DT}"   "hpps-bl-dt" "${HPPS_BL_DT_ADDR}" 0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${HPPS_FW}"      "hpps-fw" "${HPPS_FW_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${HPPS_DT}"      "hpps-dt" "${HPPS_DT_ADDR}"	0x0
    run "${SRAM_IMG_TOOL}" add "${TRCH_SMC_SRAM2}" "${HPPS_KERN}"    "hpps-os" "${HPPS_KERN_ADDR}" 0x0
    run "cp" "${TRCH_SMC_SRAM2}" "${TRCH_SMC_SRAM3}"
fi

if [ "$(syscfg_get HPPS rootfs_loc)" = "HPPS_DRAM" ]
then
    ARGS+=(-m "${CONF_DIR}/hpps-ramdisk.qemu.preload.mem.map")
fi

ARGS+=(-m "${CONF_DIR}/trch.qemu.preload.mem.map")

run "${SRAM_IMG_TOOL}" show "${TRCH_SMC_SRAM0}"
run "${SRAM_IMG_TOOL}" show "${TRCH_SMC_SRAM1}"

# Networking: userspace mode, forward ports
ARGS+=(-n user -p 22 -p 2345)

# launch-qemu SDK tool assumes the SDK has been loaded into env
export PATH="${SDK}:${SDK_TOOLS}:$PATH"

run exec "${SDK_TOOLS}/launch-qemu" "${ARGS[@]}" "$@"
