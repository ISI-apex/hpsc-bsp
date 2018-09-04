include arm-trusted-firmware.inc

XILINX_RELEASE_VERSION = "v2017.3"

# this is for tag "hpsc-0.9"
SRCREV = "hpsc-0.9"

PV = "1.3-xilinx-${XILINX_RELEASE_VERSION}+git${SRCPV}"
