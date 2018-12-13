#!/bin/bash
#
# Parent build script
#

RELEASE_DIR=HPSC_2.0
RELEASE_TGZ=${RELEASE_DIR}.tar.gz

TC_TOP_DIR=${PWD}/sdk
TC_BM_DIR=${TC_TOP_DIR}/gcc-arm-none-eabi-7-2018-q2-update
TC_POKY_DIR=${TC_TOP_DIR}/poky
TC_REPO_DIR=${TC_TOP_DIR}/bsp_repositories

BM_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2"
BM_TC_TBZ2=${PWD}/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2

# Paths generated as part of build
POKY_DEPLOY_DIR=${PWD}/poky/build/tmp/deploy
POKY_IMAGE_DIR=${POKY_DEPLOY_DIR}/images/hpsc-chiplet
POKY_TC_INSTALLER=${POKY_DEPLOY_DIR}/sdk/poky-glibc-x86_64-core-image-minimal-aarch64-toolchain-2.4.3.sh
BAREMETAL_DIR=${PWD}/hpsc-baremetal
UTILS_DIR=${PWD}/hpsc-utils
R52_UBOOT_DIR=${PWD}/u-boot-r52

# Generated artifacts for BSP directory
BSP_ARTIFACTS_QEMU=("${PWD}/qemu/BUILD/aarch64-softmmu/qemu-system-aarch64"
                    "${PWD}/qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb"
                    "${PWD}/qmp.py"
                    "${PWD}/run-qemu.sh")
BSP_ARTIFACTS_HPPS=("${POKY_IMAGE_DIR}/arm-trusted-firmware.elf"
                    "${POKY_IMAGE_DIR}/core-image-minimal-hpsc-chiplet.cpio"
                    "${POKY_IMAGE_DIR}/core-image-minimal-hpsc-chiplet.cpio.gz.u-boot"
                    "${POKY_IMAGE_DIR}/hpsc.dtb"
                    "${POKY_IMAGE_DIR}/Image"
                    "${POKY_IMAGE_DIR}/u-boot.elf")
BSP_ARTIFACTS_UTIL=("${UTILS_DIR}/linux/mboxtester"
                    "${UTILS_DIR}/linux/wdtester")
BSP_ARTIFACTS_RTPS_R52=("${BAREMETAL_DIR}/rtps/bld/rtps.elf"
                        "${BAREMETAL_DIR}/rtps/bld/rtps.bin"
                        "${R52_UBOOT_DIR}/u-boot.elf"
                        "${R52_UBOOT_DIR}/u-boot.bin")
BSP_ARTIFACTS_TRCH=("${BAREMETAL_DIR}/trch/bld/trch.elf")
# target directories in BSP
BSP_DIR=${RELEASE_DIR}/BSP
BSP_DIR_HPPS=${BSP_DIR}/hpps
BSP_DIR_RTPS_R52=${BSP_DIR}/rtps-r52
BSP_DIR_TRCH=${BSP_DIR}/trch

# Sources for src directory
# TODO: Include poky, meta-hpsc, and meta-openembedded?
SRC_ARTIFACTS=("https://github.com/ISI-apex/arm-trusted-firmware.git"
               "https://github.com/ISI-apex/hpsc-baremetal.git"
               "https://github.com/ISI-apex/hpsc-bsp.git"
               "https://github.com/ISI-apex/hpsc-utils.git"
               "https://github.com/ISI-apex/linux-hpsc.git"
               "https://github.com/ISI-apex/qemu.git"
               "https://github.com/ISI-apex/qemu-devicetrees.git"
               "https://github.com/ISI-apex/u-boot.git")

# Toolchain installers for toolchains directory
TOOLCHAIN_ARTIFACTS=("${BM_TC_TBZ2}"
                     "${POKY_TC_INSTALLER}")

function sdk_bm_setup()
{
    if [ ! -d "$TC_BM_DIR" ]; then
        if [ ! -e "$BM_TC_TBZ2" ]; then
            echo "Bare metal toolchain installer not found: $BM_TC_TBZ2"
            exit 1
        fi
        tar xjf "$BM_TC_TBZ2" -C "$TC_TOP_DIR"
    fi
}

function sdk_poky_setup()
{
    if [ ! -e "$POKY_TC_INSTALLER" ]; then
        echo "Poky toolchain installer not found: $POKY_TC_INSTALLER"
        exit 1
    fi
    # always set +x - even if we don't extract it here, we deliver it in the BSP
    chmod +x "$POKY_TC_INSTALLER"
    if [ ! -d "$TC_POKY_DIR" ]; then
        "$POKY_TC_INSTALLER" <<EOF
$TC_POKY_DIR
y
EOF
    fi
}

function transform_run_qemu()
{
    script=$1
    local RUN_QEMU_REPLACE=(
        ARM_TF_FILE=${BSP_DIR_HPPS}/arm-trusted-firmware.elf
        ARM_TF_FILE_BIN=${BSP_DIR_HPPS}/arm-trusted-firmware.bin
        ROOTFS_FILE=${BSP_DIR_HPPS}/core-image-minimal-hpsc-chiplet.cpio.gz.u-boot
        KERNEL_FILE=${BSP_DIR_HPPS}/Image
        LINUX_DT_FILE=${BSP_DIR_HPPS}/hpsc.dtb
        BL_FILE=${BSP_DIR_HPPS}/u-boot.elf
        BL_FILE_BIN=${BSP_DIR_HPPS}/u-boot.bin

        TRCH_FILE=${BSP_DIR_TRCH}/trch.elf
        RTPS_FILE=${BSP_DIR_RTPS_R52}/rtps.elf
        RTPS_FILE_BIN=${BSP_DIR_RTPS_R52}/rtps.bin

        RTPS_BL_FILE=${BSP_DIR_RTPS_R52}/u-boot.elf
        RTPS_BL_FILE_BIN=${BSP_DIR_RTPS_R52}/u-boot.bin

        QEMU_DIR=.
        QEMU_DT_FILE=hpsc-arch.dtb

        HPPS_NAND_IMAGE=${BSP_DIR_HPPS}/rootfs_nand.bin
        HPPS_SRAM_FILE=${BSP_DIR_HPPS}/hpps_sram.bin
        TRCH_SRAM_FILE=${BSP_DIR_HPPS}/trch_sram.bin

        HPSC_HOST_UTILS_DIR=../src/hpsc-utils/host
    )
    for repl in "${RUN_QEMU_REPLACE[@]}"; do
        prop=$(echo "$repl" | cut -d= -f1)
        val=$(echo "$repl" | cut -d= -f2)
        sed -i 's,'"$prop=.*"','"$prop=\"$val\""',' "$script"
    done
    sed -i '/YOCTO_DEPLOY_DIR=/d' "$script"
    sed -i '/BAREMETAL_DIR=/d' "$script"
    sed -i '/R52_UBOOT_DIR=/d' "$script"
    sed -i '/PWD=/d' "$script"
    # this is a clumsy attempt to catch issues that break our transformation
    if grep YOCTO_DEPLOY_DIR "$script"||
       grep BAREMETAL_DIR "$script" ||
       grep R52_UBOOT_DIR "$script" ||
       grep PWD "$script"; then
        echo "run-qemu script changed, 'transform_run_qemu' needs updating!"
        exit 1
    fi
}

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetchall|buildall|package>] [-h]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) download sources, compile, and package"
    echo "       fetchall: download toolchains and sources"
    echo "       buildall: compile pre-downloaded sources"
    echo "       package: package everything into the BSP"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
IS_ONLINE=1
IS_BUILD=1
IS_PACKAGE=1
BUILD=""
while getopts "h?a:b:" o; do
    case "$o" in
        a)
            if [ "${OPTARG}" == "fetchall" ]; then
                IS_BUILD=0
                IS_PACKAGE=0
            elif [ "${OPTARG}" == "buildall" ]; then
                IS_ONLINE=0
                IS_PACKAGE=0
            elif [ "${OPTARG}" == "package" ]; then
                IS_ONLINE=0
                IS_BUILD=0
            elif [ "${OPTARG}" != "all" ]; then
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        b)
            BUILD="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            echo "Unknown option"
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "$BUILD" ]; then
    usage
fi
if [ $IS_PACKAGE -ne 0 ]; then
    if [ -d "$RELEASE_DIR" ]; then
        echo "Release directory already exists, please remove: $RELEASE_DIR"
        exit 1
    fi
    if [ -e "$RELEASE_TGZ" ]; then
        echo "Release artifact already exists, please remove: $RELEASE_TGZ"
        exit 1
    fi
fi

# Fail-fast
set -e

. ./build-common.sh
build_set_environment "$BUILD"

if [ $IS_ONLINE -ne 0 ]; then
    echo "Fetching toolchains..."
    # get toolchains
    if [ ! -e "$BM_TC_TBZ2" ]; then
        wget -O "$BM_TC_TBZ2" "$BM_URL"
    fi
    ./build-hpsc-yocto.sh -b "$BUILD" -a populate_sdk
    mkdir -p "$TC_TOP_DIR"
    sdk_bm_setup
    sdk_poky_setup
    echo "Fetching sources..."
    # fetch sources
    ./build-hpsc-yocto.sh -b "$BUILD" -a fetchall
    ./build-hpsc-other.sh -b "$BUILD" -a fetchall
    ./build-hpsc-eclipse.sh -a fetchall
    # fetch sources for BSP
    mkdir -p "$TC_REPO_DIR"
    for a in "${SRC_ARTIFACTS[@]}"; do
        dir=$(basename "$a" | cut -d. -f1)
        git_clone_pull "$a" "${TC_REPO_DIR}/${dir}"
    done
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Building..."
    # build Yocto
    ./build-hpsc-yocto.sh -b "$BUILD" -a buildall
    # build other packages
    export PATH=$PATH:$TC_BM_DIR
    export POKY_SDK="$TC_POKY_DIR"
    ./build-hpsc-other.sh -b "$BUILD" -a buildall
    # build Eclipse
    ./build-hpsc-eclipse.sh -a buildall
fi

if [ $IS_PACKAGE -ne 0 ]; then
    echo "Packaging $RELEASE_DIR..."
    mkdir "$RELEASE_DIR"

    #
    # BSP
    #
    echo "Copying BSP..."
    mkdir "$BSP_DIR"
    for a in "${BSP_ARTIFACTS_QEMU[@]}"; do
        cp "$a" "${BSP_DIR}/"
    done
    # run-qemu needs to be updated with new paths
    transform_run_qemu "${BSP_DIR}/run-qemu.sh"
    mkdir "$BSP_DIR_HPPS"
    for a in "${BSP_ARTIFACTS_HPPS[@]}"; do
        cp "$a" "${BSP_DIR_HPPS}/"
    done
    mkdir "$BSP_DIR_RTPS_R52"
    for a in "${BSP_ARTIFACTS_RTPS_R52[@]}"; do
        cp "$a" "${BSP_DIR_RTPS_R52}/"
    done
    mkdir "$BSP_DIR_TRCH"
    for a in "${BSP_ARTIFACTS_TRCH[@]}"; do
        cp "$a" "${BSP_DIR_TRCH}/"
    done
    mkdir "${BSP_DIR}/aarch64-poky-linux-utils"
    for a in "${BSP_ARTIFACTS_UTIL[@]}"; do
        cp "$a" "${BSP_DIR}/aarch64-poky-linux-utils/"
    done

    #
    # eclipse
    #
    echo "Copying eclipse..."
    cp hpsc-eclipse.tar.gz "$RELEASE_DIR"

    #
    # src
    #
    echo "Copying sources..."
    mkdir "${RELEASE_DIR}/src"
    # copy sources downloaded to toolchain dir
    for a in "${SRC_ARTIFACTS[@]}"; do
        dir=$(basename "$a" | cut -d. -f1)
        cp -r "${TC_REPO_DIR}/${dir}" "${RELEASE_DIR}/src/${dir}"
    done

    #
    # toolchains
    #
    echo "Copying toolchains..."
    mkdir "${RELEASE_DIR}/toolchains"
    for a in "${TOOLCHAIN_ARTIFACTS[@]}"; do
        cp "$a" "${RELEASE_DIR}/toolchains/"
    done

    #
    # Create final release archive
    #
    echo "Creating artifact: $RELEASE_TGZ..."
    tar czf "$RELEASE_TGZ" "$RELEASE_DIR"
fi
