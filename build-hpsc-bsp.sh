#!/bin/bash
#
# Parent build script
#

# Fail-fast
set -e

TC_BM_DIR=env/gcc-arm-none-eabi-7-2018-q2-update
TC_POKY_DIR=env/poky

BM_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2"
BM_MD5=299ebd3f1c2c90930d28ab82e5d8d6c0
BM_TC_TBZ2=src/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2

# Paths generated as part of build
POKY_DEPLOY_DIR=work/poky_build/tmp/deploy
POKY_IMAGE_DIR=${POKY_DEPLOY_DIR}/images/hpsc-chiplet
POKY_TC_INSTALLER=${POKY_DEPLOY_DIR}/sdk/poky-glibc-x86_64-core-image-hpsc-aarch64-toolchain-2.6.sh
BAREMETAL_DIR=work/hpsc-baremetal
UTILS_DIR=work/hpsc-utils
RTPS_R52_UBOOT_DIR=work/u-boot-rtps-r52
ECLIPSE_INSTALLER=work/hpsc-eclipse/hpsc-eclipse.tar.gz

# Generated artifacts for BSP directory
BSP_ARTIFACTS_TOP=("cfgc"
                   "qemu-env.sh"
                   "qmp.py"
                   "run-qemu.sh"
                   "syscfg.ini"
                   "syscfg-schema.json")
BSP_ARTIFACTS_QEMU=("work/qemu/BUILD/aarch64-softmmu/qemu-system-aarch64"
                    "work/qemu/BUILD/qemu-bridge-helper"
                    "work/qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb")
BSP_ARTIFACTS_HPPS=("${POKY_IMAGE_DIR}/arm-trusted-firmware.bin"
                    "${POKY_IMAGE_DIR}/u-boot.bin"
                    "${POKY_IMAGE_DIR}/hpsc.dtb"
                    "${POKY_IMAGE_DIR}/Image.gz"
                    "${POKY_IMAGE_DIR}/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot")
BSP_ARTIFACTS_AARCH64_UTIL=("${UTILS_DIR}/linux/mboxtester"
                            "${UTILS_DIR}/linux/rtit-tester"
                            "${UTILS_DIR}/linux/shm-standalone-tester"
                            "${UTILS_DIR}/linux/shm-tester"
                            "${UTILS_DIR}/linux/wdtester")
BSP_ARTIFACTS_HOST_UTIL=("${UTILS_DIR}/host/qemu-nand-creator"
                         "${UTILS_DIR}/host/sram-image-utils")
BSP_ARTIFACTS_RTPS_R52=("${BAREMETAL_DIR}/rtps/bld/rtps.uimg"
                        "${RTPS_R52_UBOOT_DIR}/u-boot.bin")
BSP_ARTIFACTS_TRCH=("${BAREMETAL_DIR}/trch/bld/trch.elf")

# Toolchain installers for toolchains directory
TOOLCHAIN_ARTIFACTS=("$BM_TC_TBZ2"
                     "$POKY_TC_INSTALLER")

function sdk_bm_setup()
{
    local INSTALL_TBZ2=$1
    local INSTALL_DIR=$2
    if [ ! -e "$INSTALL_TBZ2" ]; then
        echo "Bare metal toolchain installer not found: $INSTALL_TBZ2"
        exit 1
    fi
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "Installing bare metal toolchain..."
        tar xjf "$INSTALL_TBZ2" -C "$(dirname "$INSTALL_DIR")"
    fi
}

function sdk_poky_setup()
{
    local INSTALL_SH=$1
    local INSTALL_DIR=$2
    if [ ! -e "$INSTALL_SH" ]; then
        echo "Poky toolchain installer not found: $INSTALL_SH"
        exit 1
    fi
    # always set +x - even if we don't extract it here, we deliver it in the BSP
    chmod +x "$INSTALL_SH"
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "Installing poky toolchain..."
        "$INSTALL_SH" <<EOF
$INSTALL_DIR
y
EOF
    fi
}

function stage_artifacts()
{
    local dest=$1
    shift
    mkdir -p "$dest"
    echo "Staging: $dest"
    for s in "$@"; do
        echo "  $(basename "$s")"
        cp "$s" "${dest}/"
    done
}

function transform_qemu_env()
{
    local script=$1
    local userscripts=("$@")
    # TODO: Would be nice if we could just get relative paths from above
    local RUN_QEMU_REPLACE=(
        HPPS_FW=hpps/arm-trusted-firmware.bin
        HPPS_BL=hpps/u-boot.bin
        HPPS_DT=hpps/hpsc.dtb
        HPPS_KERN_BIN=hpps/Image.gz
        HPPS_RAMDISK=hpps/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot

        TRCH_APP=trch/trch.elf
        RTPS_APP=rtps-r52/rtps.uimg

        RTPS_BL=rtps-r52/u-boot.bin

        QEMU_DIR=.
        QEMU_BIN_DIR=.
        QEMU_DT_FILE=hpsc-arch.dtb

        HPSC_HOST_UTILS_DIR=host-utils
    )
    for repl in "${RUN_QEMU_REPLACE[@]}"; do
        prop=$(echo "$repl" | cut -d= -f1)
        val=$(echo "$repl" | cut -d= -f2)
        sed -i 's,'"$prop=.*"','"$prop=\"$val\""',' "$script"
    done
    local RUN_QEMU_DELETE=(WORKING_DIR
                           YOCTO_DEPLOY_DIR
                           BAREMETAL_DIR
                           RTPS_BL_DIR)
    for del in "${RUN_QEMU_DELETE[@]}"; do
        sed -i "/${del}=/d" "$script"
    done
    # this is a clumsy attempt to catch changes that break our transformation
    for del in "${RUN_QEMU_DELETE[@]}"; do
        if grep "$del" "${userscripts[@]}"; then
            echo "scripts using '$script' changed, 'transform_qemu_env' needs updating!"
            echo "  found: '$del'"
            exit 1
        fi
    done
}

function usage()
{
    echo "Usage: $0 [-a <all|fetch|build|stage|package|package-sources>] [-p PREFIX] [-w DIR] [-h]"
    echo "    -a ACTION"
    echo "       all: (default) fetch, build, stage, package, and package-sources"
    echo "       fetch: download toolchains and sources"
    echo "       build: compile pre-downloaded sources"
    echo "       stage: stage artifacts into a directory before packaging"
    echo "       package: create binary BSP archive from staged artifacts"
    echo "       package-sources: create source BSP archive"
    echo "    -p PREFIX: set the release stage/package prefix (default=\"SNAPSHOT\")"
    echo "    -w DIR: set the working directory (default=\"BUILD\")"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
IS_STAGE=0
IS_PACKAGE=0
IS_PACKAGE_SOURCES=0
PREFIX="SNAPSHOT"
WORKING_DIR="BUILD"
while getopts "h?a:p:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "stage" ]; then
                IS_STAGE=1
            elif [ "${OPTARG}" == "package" ]; then
                IS_PACKAGE=1
            elif [ "${OPTARG}" == "package-sources" ]; then
                IS_PACKAGE_SOURCES=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        p)
            PREFIX="${OPTARG}"
            ;;
        w)
            WORKING_DIR="${OPTARG}"
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
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    # do everything
    IS_FETCH=1
    IS_BUILD=1
    IS_STAGE=1
    IS_PACKAGE=1
    IS_PACKAGE_SOURCES=1
fi

. ./build-common.sh

TOPDIR=${PWD}
build_work_dirs "$WORKING_DIR"

if [ $IS_FETCH -ne 0 ]; then
    # get toolchains
    echo "Fetching toolchains..."
    if [ ! -e "${WORKING_DIR}/${BM_TC_TBZ2}" ]; then
        echo "Downloading bare metal toolchain installer..."
        wget -O "${WORKING_DIR}/${BM_TC_TBZ2}" "$BM_URL"
        check_md5sum "${WORKING_DIR}/${BM_TC_TBZ2}" "$BM_MD5"
    fi
    # fetch sources
    echo "Fetching sources..."
    ./build-hpsc-yocto.sh -w "$WORKING_DIR" -a fetch
    ./build-hpsc-other.sh -w "$WORKING_DIR" -a fetch
    ./build-hpsc-eclipse.sh -w "$WORKING_DIR" -a fetch
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Building..."
    # build Yocto
    ./build-hpsc-yocto.sh -w "$WORKING_DIR" -a build
    ./build-hpsc-yocto.sh -w "$WORKING_DIR" -a populate_sdk
    # build other packages
    sdk_bm_setup "${WORKING_DIR}/${BM_TC_TBZ2}" "${WORKING_DIR}/${TC_BM_DIR}"
    sdk_poky_setup "${WORKING_DIR}/${POKY_TC_INSTALLER}" \
                   "${WORKING_DIR}/${TC_POKY_DIR}"
    export PATH=$PATH:${PWD}/${WORKING_DIR}/${TC_BM_DIR}/bin
    export POKY_SDK="${PWD}/${WORKING_DIR}/${TC_POKY_DIR}"
    ./build-hpsc-other.sh -w "$WORKING_DIR" -a extract -a build
    # build Eclipse
    ./build-hpsc-eclipse.sh -w "$WORKING_DIR" -a build
fi

cd "$WORKING_DIR"

if [ $IS_STAGE -ne 0 ]; then
    # top-level
    STAGE_DIR="stage/${PREFIX}"
    stage_artifacts "$STAGE_DIR" "$ECLIPSE_INSTALLER"

    # BSP
    BSP_DIR=${STAGE_DIR}/BSP
    stage_artifacts "$BSP_DIR" "${BSP_ARTIFACTS_TOP[@]/#/${TOPDIR}/}" \
                               "${BSP_ARTIFACTS_QEMU[@]}"
    # Qemu environment needs to be updated with new paths
    transform_qemu_env "${BSP_DIR}/qemu-env.sh" \
                       "${BSP_DIR}/run-qemu.sh"

    stage_artifacts "${BSP_DIR}/hpps" "${BSP_ARTIFACTS_HPPS[@]}"
    stage_artifacts "${BSP_DIR}/rtps-r52" "${BSP_ARTIFACTS_RTPS_R52[@]}"
    stage_artifacts "${BSP_DIR}/trch" "${BSP_ARTIFACTS_TRCH[@]}"
    stage_artifacts "${BSP_DIR}/aarch64-poky-linux-utils" \
                    "${BSP_ARTIFACTS_AARCH64_UTIL[@]}"
    stage_artifacts "${BSP_DIR}/host-utils" "${BSP_ARTIFACTS_HOST_UTIL[@]}"

    # toolchains
    stage_artifacts "${STAGE_DIR}/toolchains" "${TOOLCHAIN_ARTIFACTS[@]}"
fi

if [ $IS_PACKAGE -ne 0 ]; then
    RELEASE_BIN_TGZ=${PREFIX}_bin.tar.gz
    echo "Packaging: $RELEASE_BIN_TGZ"
    tar czf "$RELEASE_BIN_TGZ" -C "stage" "$PREFIX"
    echo "md5: $RELEASE_BIN_TGZ"
    md5sum "$RELEASE_BIN_TGZ" > "${RELEASE_BIN_TGZ}.md5"
fi

if [ $IS_PACKAGE_SOURCES -ne 0 ]; then
    RELEASE_SRC_TGZ=${PREFIX}_src.tar.gz
    # This packaging is dirty and disgusting and makes me sick, but oh well
    echo "Packaging: $RELEASE_SRC_TGZ"
    # get the build scripts
    basedir=$(basename "$TOPDIR")
    bsp_files=("${basedir}/.git")
    while read f; do
        bsp_files+=("${basedir}/${f}")
    done< <(git ls-tree --name-only --full-tree HEAD)
    # cd'ing up seems to be the only way to get TOPDIR as the root directory
    # using --transform with tar broke symlinks in poky
    (
        cd "${TOPDIR}/.."
        tar czf "${basedir}/${WORKING_DIR}/${RELEASE_SRC_TGZ}" \
            "${bsp_files[@]}" "${basedir}/${WORKING_DIR}/src"
    )
    echo "md5: $RELEASE_SRC_TGZ"
    md5sum "$RELEASE_SRC_TGZ" > "${RELEASE_SRC_TGZ}.md5"
fi
