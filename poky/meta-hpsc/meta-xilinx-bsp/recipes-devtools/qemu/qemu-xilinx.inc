QEMU_TARGETS = "aarch64"

require recipes-devtools/qemu/qemu.inc

SUMMARY = "Xilinx's fork of a fast open source processor emulator"
HOMEPAGE = "https://github.com/xilinx/qemu/"

LIC_FILES_CHKSUM = " \
		file://COPYING;md5=441c28d2cf86e15a37fa47e15a72fbac \
		file://COPYING.LIB;endline=24;md5=c04def7ae38850e7d3ef548588159913 \
		"

PV = "${XILINX_QEMU_VERSION}-xilinx-${XILINX_RELEASE_VERSION}+git${SRCPV}"

# SRC_URI should be coordinated with SRCREV in qemu-xilinx_2017.3.bb.
# If using "hpsc-0.9", set SRC_URI to use "nobranch"
# Otherwise, use "branch=hpsc"
SRC_URI = "git://github.com/ISI-apex/qemu.git;protocol=git;nobranch=1"
#SRC_URI = "git://github.com/ISI-apex/qemu.git;protocol=git;branch=hpsc"

S = "${WORKDIR}/git"

DISABLE_STATIC_pn-${PN} = ""

PTEST_ENABLED = ""

do_configure() {
	${S}/configure --target-list="aarch64-softmmu" --enable-fdt --disable-kvm --disable-xen 
}
