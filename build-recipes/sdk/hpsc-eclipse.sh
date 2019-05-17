#!/bin/bash

export WGET_URL="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2018-09/R/eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz&r=1"
export WGET_OUTPUT="eclipse.tar.gz"
export WGET_OUTPUT_MD5="6087e4def4382fd334de658f9bde190b"

export DO_BUILD_OUT_OF_SOURCE=1

# Eclipse update sites
ECLIPSE_REPOSITORIES=("http://download.eclipse.org/releases/photon"
                      "http://download.eclipse.org/tm/updates/4.0/"
                      "http://gnu-mcu-eclipse.netlify.com/v4-neon-updates/"
                      "http://downloads.yoctoproject.org/releases/eclipse-plugin/2.5.0/oxygen"
                      "http://download.eclipse.org/linuxtools/update")

# Plugins to install
ECLIPSE_PLUGIN_IUS=(org.yocto.doc.feature.group/1.4.1.201804240009
                    org.yocto.sdk.feature.group/1.4.1.201804240009
                    ilg.gnumcueclipse.core/4.5.1.201901011632
                    ilg.gnumcueclipse.managedbuild.cross.arm/2.6.4.201901011632
                    ilg.gnumcueclipse.debug.core/1.2.2.201901011632
                    ilg.gnumcueclipse.templates.cortexm.feature.feature.group/1.4.4.201901011632
                    org.eclipse.linuxtools.perf.feature.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.perf.remote.feature.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.perf.feature.source.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.perf.remote.feature.source.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.profiling.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.profiling.remote.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.profiling.source.feature.group/7.1.0.201812121718
                    org.eclipse.linuxtools.profiling.remote.source.feature.group/7.1.0.201812121718)

ECLIPSE_DIR=eclipse
ECLIPSE_HPSC=hpsc-eclipse.tar.gz

DEPLOY_DIR=sdk
DEPLOY_ARTIFACTS=("$ECLIPSE_HPSC")

function do_post_fetch()
{
    # Extract eclipse
    if [ ! -d "$ECLIPSE_DIR" ]; then
        echo "hpsc-eclipse: extracting archive..."
        tar xzf "$WGET_OUTPUT"
    fi

    # Fetch additional plugins
    echo "hpsc-eclipse: fetching plugins..."
    # Get repos and IUs as comma-delimited lists
    local ECLIPSE_REPOSITORY_LIST=$(printf ",%s" "${ECLIPSE_REPOSITORIES[@]}")
    local ECLIPSE_REPOSITORY_LIST=${ECLIPSE_REPOSITORY_LIST:1}
    local ECLIPSE_PLUGIN_IU_LIST=$(printf ",%s" "${ECLIPSE_PLUGIN_IUS[@]}")
    local ECLIPSE_PLUGIN_IU_LIST=${ECLIPSE_PLUGIN_IU_LIST:1}
    "$ECLIPSE_DIR/eclipse" -application org.eclipse.equinox.p2.director \
                           -nosplash \
                           -repository "$ECLIPSE_REPOSITORY_LIST" \
                           -installIUs "$ECLIPSE_PLUGIN_IU_LIST"
}

function do_undeploy()
{
    undeploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}

function do_build()
{
    # Create distribution archive
    echo "hpsc-eclipse: creating HPSC eclipse distribution: $ECLIPSE_HPSC"
    tar -czf "$ECLIPSE_HPSC" -C "$REC_SRC_DIR" "$ECLIPSE_DIR"
}

function do_deploy()
{
    deploy_artifacts "$DEPLOY_DIR" "${DEPLOY_ARTIFACTS[@]}"
}
