#!/bin/bash
# Paths to host tools and target binaries for run-qemu.sh.
# Relative paths are relative to directory from where run-qemu.sh is invoked.

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$THIS_DIR")" == "BSP" ]; then
    # SDK configuration
    BSP_DIR=.
else
    # development configuration
    BSP_DIR=${PWD}/BUILD/deploy/BSP
fi

QEMU_PREFIX=/usr/local
QEMU_DT_FILE=${BSP_DIR}/hpsc-arch.dtb

SRAM_IMAGE_UTILS=${BSP_DIR}/host-utils/sram-image-utils
NAND_CREATOR=${BSP_DIR}/host-utils/qemu-nand-creator

# System configuration interpreted by TRCH
SYSCFG=syscfg.ini
SYSCFG_SCHEMA=syscfg-schema.json

TRCH_APP=${BSP_DIR}/trch/trch.elf

RTPS_APP=${BSP_DIR}/rtps-r52/rtps-r52.img
RTPS_BL=${BSP_DIR}/rtps-r52/u-boot.bin

HPPS_FW=${BSP_DIR}/hpps/arm-trusted-firmware.bin
HPPS_BL=${BSP_DIR}/hpps/u-boot.bin
HPPS_DT=${BSP_DIR}/hpps/hpsc.dtb
HPPS_KERN_BIN=${BSP_DIR}/hpps/Image.gz
HPPS_RAMDISK=${BSP_DIR}/hpps/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot
