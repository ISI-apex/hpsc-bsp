#!/bin/bash
# Paths to host tools and target binaries for run-qemu.sh.

WORKING_DIR=${PWD}/BUILD/work
BSP_DIR=${PWD}
YOCTO_DEPLOY_DIR=${WORKING_DIR}/poky_build/tmp/deploy/images/hpsc-chiplet

HPSC_HOST_UTILS_DIR=${WORKING_DIR}/hpsc-utils/host
SRAM_IMAGE_UTILS=${HPSC_HOST_UTILS_DIR}/sram-image-utils
NAND_CREATOR=${HPSC_HOST_UTILS_DIR}/qemu-nand-creator

# Output files from the Yocto build
HPPS_FW=${YOCTO_DEPLOY_DIR}/arm-trusted-firmware.bin
HPPS_BL=${YOCTO_DEPLOY_DIR}/u-boot.bin
HPPS_DT=${YOCTO_DEPLOY_DIR}/hpsc.dtb
HPPS_KERN_BIN=${YOCTO_DEPLOY_DIR}/Image.gz
HPPS_RAMDISK=${YOCTO_DEPLOY_DIR}/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot

# Output files from the hpsc-baremetal build
BAREMETAL_DIR=${WORKING_DIR}/hpsc-baremetal
TRCH_APP=${BAREMETAL_DIR}/trch/bld/trch.elf
RTPS_APP=${BAREMETAL_DIR}/rtps/bld/rtps.uimg

# Output files from the hpsc-R52-uboot build
RTPS_BL_DIR=${WORKING_DIR}/u-boot-r52
RTPS_BL=${RTPS_BL_DIR}/u-boot.bin

# Output files from the qemu/qemu-devicetree builds
QEMU_DIR=${WORKING_DIR}/qemu/BUILD
QEMU_BIN_DIR=${QEMU_DIR}/aarch64-softmmu
QEMU_PREFIX=/usr/local
QEMU_DT_FILE=${WORKING_DIR}/qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb

# System configuration interpreted by TRCH
SYSCFG=${BSP_DIR}/syscfg.ini
SYSCFG_SCHEMA=${BSP_DIR}/syscfg-schema.json
