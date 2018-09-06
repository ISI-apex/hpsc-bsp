SUMMARY = "Xilinx's hardware device trees required for QEMU"
HOMEPAGE = "https://github.com/xilinx/qemu-devicetrees/"
LICENSE = "BSD"
DEPENDS += "dtc-native"

inherit deploy

LIC_FILES_CHKSUM = "file://Makefile;beginline=1;endline=27;md5=7348b6cbcae69912cb1dee68d6c68d99"

PV = "xilinx-${XILINX_RELEASE_VERSION}+git${SRCPV}"

# SRC_URI should be coordinated with SRCREV in qemu_devicetrees_2017.3.bb.
# If using "hpsc-0.9", set SRC_URI to use "nobranch"
# Otherwise, use "branch=hpsc"
SRC_URI = "git://github.com/ISI-apex/qemu-devicetrees.git;protocol=git;nobranch=1"
#SRC_URI = "git://github.com/ISI-apex/qemu-devicetrees.git;protocol=git;branch=hpsc"

S = "${WORKDIR}/git"

# Don't need to do anything
do_install() {
	:
}

do_deploy() {
	# single-arch dtbs
	for DTS_FILE in ${S}/LATEST/SINGLE_ARCH/*.dtb; do
		install -Dm 0644 $DTS_FILE ${DEPLOYDIR}/qemu-hw-devicetrees/$(basename $DTS_FILE .dtb).dtb
	done
}

addtask deploy after do_install
