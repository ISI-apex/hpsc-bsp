#!/bin/bash
#
# Parent build script
#

TC_BM_DIR=env/gcc-arm-none-eabi-7-2018-q2-update
TC_POKY_DIR=env/poky

BM_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2"
BM_MD5=299ebd3f1c2c90930d28ab82e5d8d6c0
BM_TC_TBZ2=src/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2

# Paths generated as part of build
POKY_DEPLOY_DIR=work/poky/build/tmp/deploy
POKY_IMAGE_DIR=${POKY_DEPLOY_DIR}/images/hpsc-chiplet
POKY_TC_INSTALLER=${POKY_DEPLOY_DIR}/sdk/poky-glibc-x86_64-core-image-hpsc-aarch64-toolchain-2.6.sh
BAREMETAL_DIR=work/hpsc-baremetal
UTILS_DIR=work/hpsc-utils
R52_UBOOT_DIR=work/u-boot-r52
ECLIPSE_INSTALLER=work/hpsc-eclipse.tar.gz

# Generated artifacts for BSP directory
BSP_ARTIFACTS_TOP=("qmp.py"
                   "run-qemu.sh")
BSP_ARTIFACTS_QEMU=("work/qemu/BUILD/aarch64-softmmu/qemu-system-aarch64"
                    "work/qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb")
BSP_ARTIFACTS_HPPS=("${POKY_IMAGE_DIR}/arm-trusted-firmware.bin"
                    "${POKY_IMAGE_DIR}/u-boot.bin"
                    "${POKY_IMAGE_DIR}/hpsc.dtb"
                    "${POKY_IMAGE_DIR}/Image.gz"
                    "${POKY_IMAGE_DIR}/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot"
                    # plain cpio file not used by run-qemu, but used elsewhere
                    "${POKY_IMAGE_DIR}/core-image-hpsc-hpsc-chiplet.cpio")
BSP_ARTIFACTS_AARCH64_UTIL=("${UTILS_DIR}/linux/mboxtester"
                            "${UTILS_DIR}/linux/wdtester")
BSP_ARTIFACTS_HOST_UTIL=("${UTILS_DIR}/host/qemu-nand-creator"
                         "${UTILS_DIR}/host/sram-image-utils")
BSP_ARTIFACTS_RTPS_R52=("${BAREMETAL_DIR}/rtps/bld/rtps.elf"
                        "${R52_UBOOT_DIR}/u-boot.bin")
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

function transform_run_qemu()
{
    script=$1
    # TODO: Would be nice if we could just get relative paths from above
    local RUN_QEMU_REPLACE=(
        HPPS_FW=hpps/arm-trusted-firmware.bin
        HPPS_BL=hpps/u-boot.bin
        HPPS_DT=hpps/hpsc.dtb
        HPPS_KERN_BIN=hpps/Image.gz
        HPPS_KERN=hpps/uImage
        HPPS_RAMDISK=hpps/core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot

        TRCH_APP=trch/trch.elf
        RTPS_APP=rtps-r52/rtps.elf

        RTPS_BL=rtps-r52/u-boot.bin

        QEMU_DIR=.
        QEMU_DT_FILE=hpsc-arch.dtb

        HPPS_NAND_IMAGE=hpps/rootfs_nand.bin
        HPPS_SRAM_FILE=hpps/hpps_sram.bin
        TRCH_SRAM_FILE=trch/trch_sram.bin

        HPSC_HOST_UTILS_DIR=host-utils
    )
    for repl in "${RUN_QEMU_REPLACE[@]}"; do
        prop=$(echo "$repl" | cut -d= -f1)
        val=$(echo "$repl" | cut -d= -f2)
        sed -i 's,'"$prop=.*"','"$prop=\"$val\""',' "$script"
    done
    # this is a clumsy attempt to catch changes that break our transformation
    local RUN_QEMU_DELETE=(WORKING_DIR
                           YOCTO_DEPLOY_DIR
                           BAREMETAL_DIR
                           RTPS_BL_DIR
                           PWD)
    for del in "${RUN_QEMU_DELETE[@]}"; do
        sed -i "/${del}=/d" "$script"
    done
    for del in "${RUN_QEMU_DELETE[@]}"; do
        if grep "$del" "$script"; then
            echo "run-qemu script changed, 'transform_run_qemu' needs updating!"
            echo "  found: '$del'"
            exit 1
        fi
    done
}

function usage()
{
    echo "Usage: $0 -b ID [-a <all|fetch|build|stage|package>] [-h] [-p PREFIX] [-w DIR]"
    echo "    -b ID: build using git tag=ID"
    echo "       If ID=HEAD, a development release is built instead"
    echo "    -a ACTION"
    echo "       all: (default) fetch, build, stage, and package"
    echo "       fetch: download toolchains and sources"
    echo "       build: compile pre-downloaded sources"
    echo "       stage: stage artifacts into a directory before packaging"
    echo "       package: create binary and source BSP archives from staged artifacts"
    echo "    -h: show this message and exit"
    echo "    -p PREFIX: set the release stage/package prefix (default=HPSC_<gitrev>)"
    echo "    -w DIR: set the working directory (default=ID from -b)"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
IS_STAGE=0
IS_PACKAGE=0
BUILD=""
PREFIX="HPSC_$(git rev-parse --short HEAD)"
WORKING_DIR=""
while getopts "h?a:b:p:w:" o; do
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
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
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
        p)
            PREFIX="${OPTARG}"
            ;;
        w)
            WORKING_DIR="${OPTARG}"
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
WORKING_DIR=${WORKING_DIR:-"$BUILD"}
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    # do everything
    IS_FETCH=1
    IS_BUILD=1
    IS_STAGE=1
    IS_PACKAGE=1
fi
if [ $IS_STAGE -ne 0 ] && [ -d "${WORKING_DIR}/${PREFIX}" ]; then
    echo "Staging directory already exists, please remove: ${WORKING_DIR}/${PREFIX}"
    exit 1
fi

# Fail-fast
set -e

. ./build-common.sh
build_set_environment "$BUILD"

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
    ./build-hpsc-yocto.sh -b "$BUILD" -w "$WORKING_DIR" -a fetch
    ./build-hpsc-other.sh -b "$BUILD" -w "$WORKING_DIR" -a fetch
    ./build-hpsc-eclipse.sh -w "$WORKING_DIR" -a fetch
fi

if [ $IS_BUILD -ne 0 ]; then
    echo "Building..."
    # build Yocto
    ./build-hpsc-yocto.sh -b "$BUILD" -w "$WORKING_DIR" -a build
    ./build-hpsc-yocto.sh -b "$BUILD" -w "$WORKING_DIR" -a populate_sdk
    # build other packages
    sdk_bm_setup "${WORKING_DIR}/${BM_TC_TBZ2}" "${WORKING_DIR}/${TC_BM_DIR}"
    sdk_poky_setup "${WORKING_DIR}/${POKY_TC_INSTALLER}" \
                   "${WORKING_DIR}/${TC_POKY_DIR}"
    export PATH=$PATH:${PWD}/${WORKING_DIR}/${TC_BM_DIR}/bin
    export POKY_SDK="${PWD}/${WORKING_DIR}/${TC_POKY_DIR}"
    ./build-hpsc-other.sh -b "$BUILD" -w "$WORKING_DIR" -a build
    # build Eclipse
    ./build-hpsc-eclipse.sh -w "$WORKING_DIR" -a build
fi

cd "$WORKING_DIR"

if [ $IS_STAGE -ne 0 ]; then
    BSP_DIR=${PREFIX}/BSP
    echo "Staging $PREFIX..."
    mkdir "$PREFIX"

    # BSP
    echo "Staging BSP..."
    mkdir "$BSP_DIR"
    for a in "${BSP_ARTIFACTS_TOP[@]}"; do
        cp "${TOPDIR}/${a}" "${BSP_DIR}/"
    done
    # run-qemu needs to be updated with new paths
    transform_run_qemu "${BSP_DIR}/run-qemu.sh"
    for a in "${BSP_ARTIFACTS_QEMU[@]}"; do
        cp "$a" "${BSP_DIR}/"
    done
    mkdir "${BSP_DIR}/hpps"
    for a in "${BSP_ARTIFACTS_HPPS[@]}"; do
        cp "$a" "${BSP_DIR}/hpps/"
    done
    mkdir "${BSP_DIR}/rtps-r52"
    for a in "${BSP_ARTIFACTS_RTPS_R52[@]}"; do
        cp "$a" "${BSP_DIR}/rtps-r52/"
    done
    mkdir "${BSP_DIR}/trch"
    for a in "${BSP_ARTIFACTS_TRCH[@]}"; do
        cp "$a" "${BSP_DIR}/trch/"
    done
    mkdir "${BSP_DIR}/aarch64-poky-linux-utils"
    for a in "${BSP_ARTIFACTS_AARCH64_UTIL[@]}"; do
        cp "$a" "${BSP_DIR}/aarch64-poky-linux-utils/"
    done
    mkdir "${BSP_DIR}/host-utils"
    for a in "${BSP_ARTIFACTS_HOST_UTIL[@]}"; do
        cp "$a" "${BSP_DIR}/host-utils/"
    done

    # eclipse
    echo "Staging eclipse..."
    cp "$ECLIPSE_INSTALLER" "$PREFIX"

    # toolchains
    echo "Staging toolchains..."
    mkdir "${PREFIX}/toolchains"
    for a in "${TOOLCHAIN_ARTIFACTS[@]}"; do
        cp "$a" "${PREFIX}/toolchains/"
    done
fi

if [ $IS_PACKAGE -ne 0 ]; then
    RELEASE_TGZ=${PREFIX}_bin.tar.gz
    RELEASE_SRC_FETCH_TGZ=${PREFIX}_src.tar.gz

    echo "Packaging: $RELEASE_TGZ..."
    tar czf "$RELEASE_TGZ" "$PREFIX"
    md5sum "$RELEASE_TGZ" > "${RELEASE_TGZ}.md5"

    # This packaging is dirty and disgusting and makes me sick, but oh well
    echo "Packaging: $RELEASE_SRC_FETCH_TGZ..."
    # get the build scripts
    basedir=$(basename "$TOPDIR")
    bsp_files=("${basedir}/.git")
    while read f; do
        bsp_files+=("${basedir}/${f}")
    done< <(git ls-tree --name-only HEAD)
    # cd'ing up seems to be the only way to get TOPDIR as the root directory
    # using --transform with tar broke symlinks in poky
    (
        cd "${TOPDIR}/.."
        tar czf "${basedir}/${WORKING_DIR}/${RELEASE_SRC_FETCH_TGZ}" \
            "${bsp_files[@]}" "${basedir}/${WORKING_DIR}/src"
        cd "${TOPDIR}/${WORKING_DIR}"
        md5sum "$RELEASE_SRC_FETCH_TGZ" > "${RELEASE_SRC_FETCH_TGZ}.md5"
    )
fi

cd "$TOPDIR"
