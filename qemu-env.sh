#!/bin/bash
# Paths to host tools and target binaries for run-qemu.sh.
# Relative paths are relative to directory from where run-qemu.sh is invoked.

WORKING_DIR=${PWD}/BUILD/work
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
QEMU_DIR=${WORKING_DIR}/qemu/BUILD/aarch64-softmmu
QEMU_DT_FILE=${WORKING_DIR}/qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb

# Off-chip memory images. Created blank by run-qemu.sh if abscent.
HPPS_NAND_IMAGE=rootfs_nand.bin
HPPS_SRAM_FILE=hpps_sram.bin

# System configuration interpreted by TRCH
SYSCFG=syscfg.ini
SYSCFG_SCHEMA=syscfg-schema.json
