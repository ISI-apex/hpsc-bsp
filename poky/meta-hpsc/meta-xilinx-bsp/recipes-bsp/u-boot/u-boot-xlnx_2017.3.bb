include u-boot-xlnx.inc
include u-boot-spl-zynq-init.inc

XILINX_RELEASE_VERSION = "v2017.3"

# this is for tag "hpsc-0.9"
SRCREV = "hpsc-0.9"

PV = "v2017.01-xilinx-${XILINX_RELEASE_VERSION}+git${SRCPV}"

SRC_URI_append = " \
		file://arm64-zynqmp-Setup-partid-for-QEMU-to-match-silicon.patch \
		"

LICENSE = "GPLv2+"
LIC_FILES_CHKSUM = "file://README;beginline=1;endline=6;md5=157ab8408beab40cd8ce1dc69f702a6c"

# u-boot-xlnx has support for these
HAS_PLATFORM_INIT ?= " \
		xilinx_zynqmp_zcu102_rev1_0_config \
		hpsc_multi_config \
		"

