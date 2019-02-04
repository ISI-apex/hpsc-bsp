HPSC Chiplet Board Support Package
==================================

This repository includes:

1. `build-hpsc-bsp.sh` - top-level build script
1. `build-common.sh` - common utilities, including configuration for development and release builds.
1. `build-hpsc-yocto.sh` - uses the Yocto framework to build the bulk of the Chiplet artifacts, particularly those for Linux on the HPPS.
1. `build-hpsc-other.sh` - builds additional artifacts.
Uses the ARM bare metal toolchain to build the TRCH and R52 firmware and u-boot for the R52s.
Uses the Yocto SDK toolchain to build test utilities.
Uses the host compiler to build QEMU.
1. `build-hpsc-eclipse.sh` - downloads and builds the HPSC Eclipse distribution.
1. `run-qemu.sh` - uses the output from the build scripts above to boot QEMU.

Scripts must be run from the same directory.
Most scripts support the `-h` flag to print usage help.

Build scripts download from the git repositories located at:
https://github.com/orgs/ISI-apex/teams/hpsc/repositories

BSP Build
---------

The top-level `build-hpsc-bsp.sh` script wraps the other build scripts, so please read their documentation below before proceeding.

By default, it will run through fetch, build, stage, package, and package-sources steps.
The following steps may be run independently using the `-a` flag so long as previous steps are complete.

* `fetch` - download/build toolchains and fetch build sources
* `build` - build all pre-downloaded sources.
Note: Yocto may still attempt to fetch sources when doing a development build.
* `stage` - stage sources and binaries into the directory structure to be packaged
* `package` - package the staged directory structure into the final BSP archive
* `package-sources` - package the sources into an archive for offline builds

To perform a release build for `hpsc-2.0`:

	./build-hpsc-bsp.sh -b hpsc-2.0

To run a development build, specify `-b HEAD` instead.
Other build scripts follow this same pattern.

	./build-hpsc-bsp.sh -b HEAD

All files are downloaded and built in a working directory, which defaults to the value from `-b`.
You may optionally specify a different working directory using `-w`.

Yocto Build
-----------

Before starting the Yocto build, ensure that your system has python3 installed, which is needed to run bitbake.

For example to perform a development build, then create the SDK:

	./build-hpsc-yocto.sh -b HEAD
	./build-hpsc-yocto.sh -b HEAD -a populate_sdk

The generated files needed to run QEMU are located in: `${WORKING_DIR}/work/poky_build/tmp/deploy/images/hpsc-chiplet`.
Specifically:

1. `arm-trusted-firmware.bin` - the Arm Trusted Firmware binary
1. `core-image-minimal-hpsc-chiplet.cpio.gz.u-boot` - the Linux root file system for booting the dual A53 cluster
1. `Image.gz` - the Linux kernel binary image
1. `hpsc.dtb` - the Chiplet device tree for SMP Linux
1. `u-boot.bin` - the U-boot bootloader for the dual A53 cluster

The actual build directories for these files are located in the directory: `${WORKING_DIR}/work/poky_build/tmp/work`.

Other Build
-----------

Building the remaining components has additional prerequisites.
First, the ARM bare metal toolchain bin directory must be on `PATH`, e.g. in `/opt`:

	export PATH=$PATH:/opt/gcc-arm-none-eabi-7-2018-q2-update/bin

The bare metal toolchain is used to build (within `${WORKING_DIR}/work/`):

1. `hpsc-baremetal/trch/bld/trch.elf` - TRCH firmware
1. `hpsc-baremetal/rtps/bld/rtps.elf` - RTPS R52 firmware
1. `u-boot-r52/u-boot.bin` - u-boot for the RTPS R52s

The host compiler is used to build:

1. `qemu/BUILD/aarch64-softmmu/qemu-system-aarch64` - the QEMU binary
1. `qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb` - the QEMU device tree
1. `hpsc-utils/host/qemu-nand-creator` - QEMU NAND flash image creator
1. `hpsc-utils/host/sram-image-utils` - SRAM image creation utility

Finally, the Poky SDK must be installed to build test utilities.
Set `POKY_SDK` to the install location, e.g. (using the default location):

	export POKY_SDK=/opt/poky/2.6

The Poky SDK is used to build:

1. `hpsc-utils/linux/mboxtester` - mailbox test utility
1. `hpsc-utils/linux/wdtester` - watchdog test utility

To run a development build:

	./build-hpsc-other.sh -b HEAD

Booting QEMU
------------

After the builds complete, the user can run the `run-qemu.sh` script to launch QEMU.

Eclipse
-------

To download eclipse, install additional plugins, and package up again:

	./build-hpsc-eclipse.sh

There is no concept of a development or release build for Eclipse, as there's no additional source control involved, so you must specify `-w` explicitly for a value other than `HEAD`.
The final artifact is `hpsc-eclipse.tar.gz`.
