HPSC Chiplet Board Support Package
==================================

This repository includes:

1. `build-hpsc-bsp.sh` - top-level build script.
1. `build-hpsc-yocto.sh` - uses the Yocto framework to build the bulk of the Chiplet artifacts, particularly those for Linux on the HPPS.
1. `build-hpsc-other.sh` - builds additional artifacts.
Uses the ARM bare metal toolchain to build the TRCH and R52 firmware and u-boot for the R52s.
Uses the Yocto SDK toolchain to build test utilities.
Uses the host compiler to build QEMU.
1. `build-recipe.sh` - used to build individual components; wrapped by other build scripts.
1. `run-qemu.sh` - uses the output from the build scripts above to boot QEMU.

Scripts must be run from the same directory.
Most scripts support the `-h` flag to print usage help.

Build scripts download from the git repositories located at:
https://github.com/orgs/ISI-apex/teams/hpsc/repositories

Updating the BSP
----------------

To update the sources that the BSP build scripts use, you must modify the build recipes, located in `build-recipes/`.

Some sources (ATF, linux, and u-boot for the HPPS) are managed by Yocto recipes.
These recipes are found in the [meta-hpsc](https://github.com/ISI-apex/meta-hpsc) project and must be configured there.
The `meta-hpsc` project revision is then configured locally in `build-config.sh` and fetched by the `build-hpsc-yocto.sh` script.

There are some helper scripts in `utils/` to automate upgrading dependencies.

BSP Build
---------

The top-level `build-hpsc-bsp.sh` script wraps the other build scripts, so please read their documentation below before proceeding.

By default, it will run through fetch, build, stage, package, and package-sources steps.
The following steps may be run independently using the `-a` flag so long as previous steps are complete.

* `fetch` - download/build toolchains and fetch build sources
* `build` - build all pre-downloaded sources.
* `stage` - stage sources and binaries into the directory structure to be packaged
* `package` - package the staged directory structure into the final BSP archive
* `package-sources` - package the sources into an archive for offline builds

To perform a build:

	./build-hpsc-bsp.sh

All files are downloaded and built in a working directory, which defaults to `BUILD`.
You may optionally specify a different working directory using `-w`.
Use the `-p` flag to set the stage/release name, otherwise the default name is "SNAPSHOT".

Yocto Build
-----------

Before starting the Yocto build, ensure that your system has python3 installed, which is needed to run bitbake.

For example to perform a build, then create the SDK:

	./build-hpsc-yocto.sh -a fetch -a build
	./build-hpsc-yocto.sh -a populate_sdk

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
1. `hpsc-baremetal/rtps/bld/rtps.uimg` - RTPS R52 firmware
1. `u-boot-r52/u-boot.bin` - u-boot for the RTPS R52s

The host compiler is used to build:

1. `qemu/BUILD/aarch64-softmmu/qemu-system-aarch64` - the QEMU binary
1. `qemu-devicetrees/LATEST/SINGLE_ARCH/hpsc-arch.dtb` - the QEMU device tree
1. `hpsc-utils/host/qemu-nand-creator` - QEMU NAND flash image creator
1. `hpsc-utils/host/sram-image-utils` - SRAM image creation utility

The Poky SDK must be installed to build test utilities.
Set `POKY_SDK` to the install location, e.g. (using the default location):

	export POKY_SDK=/opt/poky/2.6.1

The Poky SDK is used to build:

1. `hpsc-utils/linux/mboxtester` - mailbox test utility
1. `hpsc-utils/linux/rtit-tester` - RTI timer test utility
1. `hpsc-utils/linux/shm-standalone-tester` - shared memory standalone test utility
1. `hpsc-utils/linux/shm-tester` - shared memory test utility
1. `hpsc-utils/linux/wdtester` - watchdog test utility

The HPSC Eclipse distribution is also built:

1. `hpsc-eclipse/hpsc-eclipse.tar.gz` - TRCH firmware

To run a build:

	./build-hpsc-other.sh

Booting QEMU
------------

After the builds complete, the user can run the `run-qemu.sh` script to launch QEMU.
