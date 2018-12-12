HPSC Chiplet Board Support Package
==================================

This repository includes:

1. `build-common.sh` - configuration for development and release builds lives here.
1. `build-hpsc-yocto.sh` - uses the Yocto framework to build the bulk of the Chiplet artifacts, particularly those for Linux on the HPPS.
1. `build-hpsc-other.sh` - builds additional artifacts.
Uses the ARM bare metal toolchain to build the TRCH and R52 firmware and u-boot for the R52s.
Uses the Yocto SDK toolchain to build test utilities.
Uses the host compiler to build QEMU.
1. `run-qemu.sh` - uses the output from the build scripts above to boot QEMU.
1. `create_rootfs_nand.sh` - creates nand image file and put root filesystem in the nand image file.

Build scripts download from the git repositories located at:
https://github.com/orgs/ISI-apex/teams/hpsc/repositories

Release builds are created by default, as specified by the `GIT_RELEASE_TAG` value in `build-common.sh`.
To build a development release instead (using the latest `HEAD` of the `hpsc` branches, set the environment variable `HPSC_BUILD_DEVELOPMENT=1`.

Yocto Build
-----------

Before starting the Yocto build, ensure that your system has python3 installed, which is needed to run bitbake.

To simply fetch sources:

	./build-hpsc-yocto.sh fetchall

To run a development build, then create the SDK:

	HPSC_BUILD_DEVELOPMENT=1 ./build-hpsc-yocto.sh
	HPSC_BUILD_DEVELOPMENT=1 ./build-hpsc-yocto.sh populate_sdk

The generated files needed to run QEMU are located in: `poky/build/tmp/deploy/images/hpsc-chiplet`.
Specifically:

1. `arm-trusted-firmware.elf` - the Arm Trusted Firmware binary
1. `core-image-minimal-hpsc-chiplet.cpio.gz.u-boot` - the Linux root file system for booting the dual A53 cluster
1. `Image` - the Linux kernel binary image
1. `hpsc.dtb` - the Chiplet device tree for SMP Linux
1. `u-boot.elf` - the U-boot bootloader for the dual A53 cluster

The actual build directories for these files are located in the directory: `poky/build/tmp/work`.

Other Build
-----------

Building the remaining components has additional prerequisites.
First, the ARM baremetal toolchain bin directory must be on `PATH`, e.g.:

	export PATH=$PATH:/opt/gcc-arm-none-eabi-7-2018-q2-update/bin

The bare metal toolchain is used to build:

1. `hpsc-baremetal/trch/bld/trch.elf` - TRCH firmware
1. `hpsc-baremetal/rtps/bld/rtps.elf` - RTPS R52 firmware
1. `u-boot-r52/u-boot.elf` - u-boot for the RTPS R52s

The host compiler is used to build:

1. `qemu/BUILD/aarch64-softmmu/qemu-system-aarch64` - the QEMU binary
1. `qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb` - the QEMU device tree

Finally, the Poky SDK must be installed to build test utilities.
Set `POKY_SDK` to the install location, e.g.:

	export POKY_SDK=/opt/poky/2.4.3

To run a development build:

	HPSC_BUILD_DEVELOPMENT=1 ./build-hpsc-other.sh

Booting QEMU
------------

After the builds complete, the user can run the `run-qemu.sh` script to launch QEMU.

Creating nand image with root file system
------------

Nand image generation can be done when all the above steps are done. 
Several of the other needed files are located in the following directory:

1. `core-image-minimal-hpsc-chiplet.cpio` - archive file of the root file system
1. `qemu-nand-creator` - The binary file which generates empty nand image

Eclipse
-------

To download eclipse, install additional plugins, and package up again:

	./build-hpsc-eclipse.sh

There is no concept of a development build for Eclipse.
The final artifact is `hpsc-eclipse.tar.gz`.
