require recipes-bsp/u-boot/u-boot.inc

DEPENDS += "bc-native dtc-native"

# SRC_URI should be coordinated with SRCREV in u-boot-xlnx_2017.3.bb.
# If using "hpsc-0.9", set SRC_URI to use "nobranch"
# Otherwise, use "branch=hpsc"
SRC_URI = "git://github.com/ISI-apex/u-boot.git;protocol=git;nobranch=1"
#SRC_URI = "git://github.com/ISI-apex/u-boot.git;protocol=git;branch=hpsc"

S = "${WORKDIR}/git"

FILESEXTRAPATHS_prepend := "${THISDIR}/u-boot:"
FILESEXTRAPATHS_prepend := "${THISDIR}/u-boot-xlnx:"
FILESEXTRAPATHS_prepend := "${@'${THISDIR}/u-boot-xlnx/${XILINX_RELEASE_VERSION}:' if d.getVar('XILINX_RELEASE_VERSION') else ''}"

do_deploy_append_zcu102-zynqmp () {
	# deploy u-boot-spl.bin for use by runqemu/QEMU
	install -Dm 0644 ${B}/spl/u-boot-spl.bin ${DEPLOYDIR}/u-boot-spl.bin
}
