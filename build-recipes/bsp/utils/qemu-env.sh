#!/bin/bash
# Relative paths are relative to directory from where run-qemu.sh is invoked.

BSP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

SDK=${BSP_DIR}/sdk
SSW=${BSP_DIR}/ssw

# ID affects port assignments and screen session names
: "${ID:=0}"

: "${RUN_DIR:=run}"

: "${QEMU_DT_DIR:=${SDK}/qemu-devicetrees}"
: "${SDK_TOOLS:=${SDK}/tools}"

# System configuration interpreted by TRCH
: "${CONF_DIR:=${BSP_DIR}/conf}"
: "${SYSCFG:=${CONF_DIR}/syscfg.ini}"
: "${SYSCFG_SCHEMA:=${SSW}/trch/syscfg-schema.json}"
: "${SYSCFG_BIN:=${RUN_DIR}/syscfg.bin}"

: "${HPPS_KERN_BIN:=${SSW}/hpps/Image.gz}"
: "${HPPS_KERN:=${RUN_DIR}/uImage}"

# load the kernel after initramfs image (which is large about 128Mb)
HPPS_KERN_LOAD_ADDR=0x88080000 # (base + TEXT_OFFSET); base must be aligned to 2MB
# Must match value in U-Boot .config
HPPS_UBOOT_CONFIG_ENV_SIZE=0x1000


# Rename serial ports to correspond to how they are used by the software stack
SERIAL_PORT_NAMES[serial0]="trch"
SERIAL_PORT_NAMES[serial1]="rtps-r52"
SERIAL_PORT_NAMES[serial2]="hpps"
