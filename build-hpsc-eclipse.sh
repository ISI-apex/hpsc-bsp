#!/bin/bash

ECLIPSE_URL="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2018-09/R/eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz&r=1"
ECLIPSE_MD5=6087e4def4382fd334de658f9bde190b
ECLIPSE_TGZ=eclipse_src.tar.gz
ECLIPSE_DIR=eclipse
ECLIPSE_HPSC=hpsc-eclipse.tar.gz

# Eclipse update sites
ECLIPSE_REPOSITORIES=("http://download.eclipse.org/releases/photon"
                      "http://download.eclipse.org/tm/updates/4.0/"
                      "http://gnu-mcu-eclipse.netlify.com/v4-neon-updates/"
                      "http://downloads.yoctoproject.org/releases/eclipse-plugin/2.5.0/oxygen")
# Plugins to install
ECLIPSE_PLUGIN_IUS=(org.yocto.doc.feature.group
                    org.yocto.sdk.feature.group
                    org.yocto.sdk.source.feature.group
                    ilg.gnumcueclipse.managedbuild.cross.arm
                    ilg.gnumcueclipse.core
                    ilg.gnumcueclipse.managedbuild.cross
                    ilg.gnumcueclipse.managedbuild.packs
                    ilg.gnumcueclipse.debug.core
                    ilg.gnumcueclipse.templates.cortexm
                    ilg.gnumcueclipse.packs.core
                    ilg.gnumcueclipse.packs.data
                    ilg.gnumcueclipse.templates.core)

function usage()
{
    echo "Usage: $0 [-a <all|fetchall|buildall>] [-h] [-w DIR]"
    echo "    -a ACTION"
    echo "       all: (default) download sources and build"
    echo "       fetchall: download sources"
    echo "       buildall: build eclipse package"
    echo "    -h: show this message and exit"
    echo "    -w DIR: Set the working directory (default=HEAD)"
    exit 1
}

# Script options
HAS_ACTION=0
IS_ALL=0
IS_ONLINE=0
IS_BUILD=0
WORKING_DIR="HEAD"
while getopts "h?a:w:" o; do
    case "$o" in
        a)
            HAS_ACTION=1
            if [ "${OPTARG}" == "fetchall" ]; then
                IS_ONLINE=1
            elif [ "${OPTARG}" == "buildall" ]; then
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
    IS_ONLINE=1
    IS_BUILD=1
fi

. ./build-common.sh

TOPDIR=${PWD}
mkdir -p "$WORKING_DIR" || exit 1
cd "$WORKING_DIR"

if [ $IS_ONLINE -ne 0 ]; then
    if [ ! -e "$ECLIPSE_TGZ" ]; then
        echo "Downloading eclipse..."
        wget -O "$ECLIPSE_TGZ" "$ECLIPSE_URL" || exit $?
        check_md5sum "$ECLIPSE_TGZ" "$ECLIPSE_MD5" || exit $?
    fi
fi

if [ $IS_BUILD -ne 0 ]; then
    # Verify prerequisites
    if [ ! -e "$ECLIPSE_TGZ" ]; then
        echo "Error: must fetch sources before build"
        exit 1
    fi

    # Extract eclipse
    if [ ! -d "$ECLIPSE_DIR" ]; then
        echo "Extracting eclipse..."
        tar xzf "$ECLIPSE_TGZ"
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
    RC=$?
    if [ $RC -ne 0 ]; then
        echo "Eclipse configuration failed with exit code: $RC"
        exit $RC
    fi

    # Create distribution archive
    echo "Creating HPSC eclipse distribution: $ECLIPSE_HPSC"
    tar czf "$ECLIPSE_HPSC" "$ECLIPSE_DIR"
fi

cd "$TOPDIR"
