#!/bin/bash

export WGET_URL="https://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/2018-09/R/eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz&r=1"
export WGET_OUTPUT="eclipse.tar.gz"
export WGET_OUTPUT_MD5="6087e4def4382fd334de658f9bde190b"

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

DEFAULT_POKY_ROOT=/opt/poky/2.6
DEFAULT_BM_BINDIR=/opt/gcc-arm-none-eabi-7-2018-q2-update/bin

ECLIPSE_DIR=eclipse
ECLIPSE_HPSC=hpsc-eclipse.tar.gz

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

function do_build()
{
    echo "hpsc-eclipse: configuring plugins..."
    # Create and populate the plugin customization file, then point the eclipse.ini file to it
    cat > "${ECLIPSE_DIR}/plugin_customization.ini" << EOL
ilg.gnumcueclipse.managedbuild.cross.arm/toolchain.path.962691777=${DEFAULT_BM_BINDIR}
org.yocto.sdk.ide.1467355974/Sysroot=${DEFAULT_POKY_ROOT}/sysroots
org.yocto.sdk.ide.1467355974/toolChainRoot=${DEFAULT_POKY_ROOT}
org.yocto.sdk.ide.1467355974/SDKMode=true
org.yocto.sdk.ide.1467355974/TargetMode=false
org.yocto.sdk.ide.1467355974/toolchainTriplet=aarch64-poky-linux
EOL
    # if statement prevents inserting duplicate entries in subsequent builds
    if [ "$(grep -c "\-pluginCustomization" "${ECLIPSE_DIR}/eclipse.ini")" -eq 0 ]; then
        # TODO: relative path to plugin_customization.ini not respected if
        # eclipse is launched from a working dir other than eclipse's root
        sed -i "7i\-pluginCustomization\nplugin_customization.ini" \
            "${ECLIPSE_DIR}/eclipse.ini"
    fi

    # Create distribution archive
    echo "hpsc-eclipse: creating HPSC eclipse distribution: $ECLIPSE_HPSC"
    tar czf "$ECLIPSE_HPSC" "$ECLIPSE_DIR"
}

function do_deploy()
{
    deploy_artifacts "" "$ECLIPSE_HPSC"
}
