#!/bin/bash

ECLIPSE_URL="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2018-09/R/eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz&r=1"
ECLIPSE_MD5=6087e4def4382fd334de658f9bde190b
ECLIPSE_TGZ=src/eclipse.tar.gz
ECLIPSE_DIR=work/eclipse
ECLIPSE_HPSC=work/hpsc-eclipse.tar.gz

# Eclipse update sites
ECLIPSE_REPOSITORIES=("http://download.eclipse.org/releases/photon"
                      "http://download.eclipse.org/tm/updates/4.0/"
                      "http://gnu-mcu-eclipse.netlify.com/v4-neon-updates/"
                      "http://downloads.yoctoproject.org/releases/eclipse-plugin/2.5.0/oxygen")
# Plugins to install
ECLIPSE_PLUGIN_IUS=(org.yocto.doc.feature.group/1.4.1.201804240009
                    org.yocto.sdk.feature.group/1.4.1.201804240009
                    ilg.gnumcueclipse.core/4.5.1.201901011632
                    ilg.gnumcueclipse.managedbuild.cross.arm/2.6.4.201901011632
                    ilg.gnumcueclipse.debug.core/1.2.2.201901011632
                    ilg.gnumcueclipse.templates.cortexm.feature.feature.group/1.4.4.201901011632)

function usage()
{
    echo "Usage: $0 [-a <all|fetch|build>] [-h] [-w DIR]"
    echo "    -a ACTION"
    echo "       all: (default) fetch and build"
    echo "       fetch: download sources"
    echo "       build: build eclipse package"
    echo "    -h: show this message and exit"
    echo "    -w DIR: set the working directory (default=HEAD)"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_FETCH=0
IS_BUILD=0
WORKING_DIR="HEAD"
while getopts "h?a:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetch" ]; then
                IS_FETCH=1
            elif [ "${OPTARG}" == "build" ]; then
                IS_BUILD=1
            elif [ "${OPTARG}" == "all" ]; then
                IS_ALL=1
            else
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
            ;;
        h)
            usage
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
if [ $HAS_ACTION -eq 0 ] || [ $IS_ALL -ne 0 ]; then
    # do everything
    IS_FETCH=1
    IS_BUILD=1
fi

# Fail-fast
set -e

. ./build-common.sh

TOPDIR=${PWD}
build_work_dirs "$WORKING_DIR"
cd "$WORKING_DIR"

if [ $IS_FETCH -ne 0 ]; then
    if [ ! -e "$ECLIPSE_TGZ" ]; then
        echo "Downloading eclipse..."
        wget -O "$ECLIPSE_TGZ" "$ECLIPSE_URL"
        check_md5sum "$ECLIPSE_TGZ" "$ECLIPSE_MD5"
    fi

    # Extract eclipse
    if [ ! -d "$ECLIPSE_DIR" ]; then
        echo "Extracting eclipse..."
        tar xzf "$ECLIPSE_TGZ" -C work
    fi

    # Configure plugins for eclipse
    echo "Configuring eclipse..."
    # Get repos and IUs as comma-delimited lists
    ECLIPSE_REPOSITORY_LIST=$(printf ",%s" "${ECLIPSE_REPOSITORIES[@]}")
    ECLIPSE_REPOSITORY_LIST=${ECLIPSE_REPOSITORY_LIST:1}
    ECLIPSE_PLUGIN_IU_LIST=$(printf ",%s" "${ECLIPSE_PLUGIN_IUS[@]}")
    ECLIPSE_PLUGIN_IU_LIST=${ECLIPSE_PLUGIN_IU_LIST:1}
    "$ECLIPSE_DIR/eclipse" -application org.eclipse.equinox.p2.director \
                           -nosplash \
                           -repository "$ECLIPSE_REPOSITORY_LIST" \
                           -installIUs "$ECLIPSE_PLUGIN_IU_LIST"
fi

if [ $IS_BUILD -ne 0 ]; then
    # Verify prerequisites
    if [ ! -d "$ECLIPSE_DIR" ]; then
        echo "Error: must fetch sources before build"
        exit 1
    fi

    # Create distribution archive
    echo "Creating HPSC eclipse distribution: $ECLIPSE_HPSC"
    (
        cd "$(dirname "$ECLIPSE_DIR")"
        tar czf "${TOPDIR}/${WORKING_DIR}/${ECLIPSE_HPSC}" \
                "$(basename "$ECLIPSE_DIR")"
    )
fi

cd "$TOPDIR"
