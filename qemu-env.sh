#!/bin/bash
# Paths to target binaries run-qemu.sh.
# Relative paths are relative to directory from where run-qemu.sh is invoked.

THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ "$(basename "$THIS_DIR")" == "BSP" ]; then
    # SDK configuration
    BSP_DIR=.
else
    # development configuration
    BSP_DIR=${THIS_DIR}/BUILD/deploy/BSP
fi

# ID affects port assignments and screen session names
: "${ID:=0}"

: "${RUN_DIR:=${THIS_DIR}/run}"

: "${LOG_FILE:=${RUN_DIR}/qemu.log}"

: "${QEMU_DT:=${BSP_DIR}/hpsc-arch.dtb}"

# System configuration interpreted by TRCH
: "${CONF_DIR:=${THIS_DIR}/conf}"
: "${SYSCFG:=${CONF_DIR}/syscfg.ini}"
: "${SYSCFG_SCHEMA:=${BSP_DIR}/conf/syscfg-schema.json}"
: "${SYSCFG_BIN:=${RUN_DIR}/syscfg.bin}"

: "${TRCH_SMC_SRAM:=${RUN_DIR}/trch_sram.bin}"
: "${TRCH_SMC_SRAM_OVERWRITE:=1}"

: "${TRCH_APP:=${BSP_DIR}/trch/trch.elf}"

: "${RTPS_APP:=${BSP_DIR}/rtps-r52/rtps-r52.img}"
: "${RTPS_BL:=${BSP_DIR}/rtps-r52/u-boot.bin}"

: "${HPPS_FW:=${BSP_DIR}/hpps/arm-trusted-firmware.bin}"
: "${HPPS_BL:=${BSP_DIR}/hpps/u-boot.bin}"
: "${HPPS_DT:=${BSP_DIR}/hpps/hpsc.dtb}"
: "${HPPS_RAMDISK:=${BSP_DIR}/hpps/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot}"
: "${HPPS_KERN_BIN:=${BSP_DIR}/hpps/Image.gz}"
: "${HPPS_KERN:=${RUN_DIR}/uImage}"

# Cannot modify these, so no point in including them here.
# Instead, simply fallback on the compiled-in/bundled versions.
#
# If wanted, then add the source to BSP and add the {mkenvimage, dtc,
# cpio+busybox_make_install+gzip+mkimage} commands for generating these
# binaries to run-qemu.sh script.
#
# export HPPS_BL_DT=${BSP_DIR}/hpps/u-boot.dtb
# export HPPS_BL_ENV=${BSP_DIR}/hpps/uboot.env.bin
# export HPPS_INITRAMFS=$BSP_DIR/hpps/initramfs.uimg

SYSCFG_ADDR=0x000ff000 # no export b/c never preloaded, always loaded from NV mem

RTPS_BL_ADDR=0x60000000       # load address for R52 u-boot
RTPS_APP_ADDR=0x68000000      # address of baremetal app binary file

HPPS_FW_ADDR=0x80000000
HPPS_BL_ADDR=0x80020000
HPPS_KERN_ADDR=0x80064000
HPPS_KERN_LOAD_ADDR=0x80680000
HPPS_DT_ADDR=0x80060000

# Not included (see comment above)
# export HPPS_BL_ENV_ADDR=0x8005_f000
# export HPPS_INITRAMFS_ADDR=0x8050_0000
