#!/bin/bash

ECLIPSE_URL="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2018-09/R/eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz&r=1"
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
    echo "Usage: $0 [-a <all|fetchall|buildall>] [-h]"
    echo "    -a ACTION"
    echo "       all: (default) download sources and build"
    echo "       fetchall: download sources"
    echo "       buildall: build eclipse package"
    echo "    -h: show this message and exit"
    exit 1
}

# Script options
IS_ONLINE=1
IS_BUILD=1
while getopts "h?a:" o; do
    case "$o" in
        a)
            if [ "${OPTARG}" == "fetchall" ]; then
                IS_BUILD=0
            elif [ "${OPTARG}" == "buildall" ]; then
                IS_ONLINE=0
            elif [ "${OPTARG}" != "all" ]; then
                echo "Error: no such action: ${OPTARG}"
                usage
            fi
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

if [ $IS_ONLINE -ne 0 ]; then
    if [ ! -e "$ECLIPSE_TGZ" ]; then
        echo "Downloading eclipse..."
        wget -O "$ECLIPSE_TGZ" "$ECLIPSE_URL" || exit $?
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
