HPSC Chiplet Board Support Package
==================================

This repository includes:

1. `build-hpsc-bsp.sh` - top-level build script.
1. `build-hpsc-bare.sh` - builds components with the bare metal compiler, including the TRCH firmware for the Cortex-M4 and u-boot for the Cortex-R52s.
1. `build-hpsc-host.sh` - builds components for the host development system, including QEMU and associated utilities, and developer tools like the HPSC Eclipse distribution.
1. `build-hpsc-rtems.sh` - builds the RTEMS SDK, BSP, and reference software for the RTPS Cortex-R52s.
1. `build-hpsc-yocto.sh` - builds Yocto Linux SDK for the HPPS Cortex-A53 clusters, including the reference root filesystem and Linux test utilities.
1. `build-recipe.sh` - build individual component recipes; wrapped by other build scripts.
1. `run-qemu.sh` - runs QEMU using the output from the build scripts.
1. `qemu-env.sh` - user-modifiable configuration for `run-qemu.sh`; do not execute directly.

Scripts must be run from the same directory.
Use the `-h` flag to print script usage help.

Build scripts download from the git repositories located at:
https://github.com/orgs/ISI-apex/teams/hpsc/repositories

Updating the BSP
----------------

To update the sources that the BSP build scripts use, you must modify the build recipes, located in `build-recipes/`.
There are some helper scripts in `utils/` to automate upgrading dependencies.

Some sources (ATF, linux, and u-boot for the HPPS) are managed by Yocto recipes, and are thus transitive dependencies.
These recipes are found in the [meta-hpsc](https://github.com/ISI-apex/meta-hpsc) project and must be configured there.
The `meta-hpsc` project revision is then configured with a local recipe in `build-recipes/`, like other BSP dependencies.

If you need to add new build recipes, read `build-recipes/README.md` and walk through `build-recipe.sh` and `build-recipes/ENV.sh`.
See existing recipes for examples.

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

For example to perform a build and create the SDK:

	./build-hpsc-yocto.sh

The build generates in `${WORKING_DIR}/deploy/BSP/hpps/`:

1. `arm-trusted-firmware.bin` - the Arm Trusted Firmware binary
1. `core-image-minimal-hpsc-chiplet.cpio.gz.u-boot` - the Linux root file system for booting the dual A53 cluster
1. `hpsc.dtb` - the Chiplet device tree for SMP Linux
1. `Image.gz` - the Linux kernel binary image
1. `u-boot.bin` - the U-boot bootloader for the dual A53 cluster

and in `${WORKING_DIR}/deploy/toolchains`:

1. `poky-glibc-x86_64-core-image-hpsc-aarch64-toolchain-2.6.1.sh` - the SDK installer

RTEMS Build
-----------

To build RTEMS-related sources and create the SDK and R52 BSP:

	./build-hpsc-rtems.sh

The build generates _non-relocatable_ toolchains/SDKs/BSPs in `${WORKING_DIR}/env/`:

1. `RSB-5` - RTEMS Source Builder SDK
1. `RT-5` - RTEMS Tools
1. `RTEMS-5-RTPS-R52` - RTPS R52 RTEMS BSP for building RTEMS applications

and in `${WORKING_DIR}/deploy/BSP/rtps-r52/`:

1. `rtps-r52.img` - RTPS R52 firmware

Other Build
-----------

To build the remaining (aka "other") artifacts, run:

	./build-hpsc-other.sh

The script fetches and deploys to `${WORKING_DIR}/deploy/toolchains`:

1. `gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2` - ARM bare metal toolchain

The bare metal toolchain is used to build in `${WORKING_DIR}/deploy/BSP/trch`:

1. `trch.elf` - TRCH firmware

and in `${WORKING_DIR}/deploy/BSP/rtps-r52`:

1. `u-boot.bin` - u-boot for the RTPS R52s

The host compiler is used to build in `${WORKING_DIR}/deploy/BSP`:

1. `hpsc-arch.dtb` - QEMU device tree
1. `qemu-bridge-helper` - QEMU utility for creating TAP devices
1. `qemu-system-aarch64` - QEMU binary

and in `${WORKING_DIR}/deploy/BSP/host-utils`:

1. `qemu-nand-creator` - QEMU NAND flash image creator
1. `sram-image-utils` - SRAM image creation utility

The Poky SDK is used to build in `${WORKING_DIR}/deploy/BSP/aarch64-poky-linux-utils/`:

1. `mboxtester` - mailbox test utility
1. `rtit-tester` - RTI timer test utility
1. `shm-standalone-tester` - shared memory standalone test utility
1. `shm-tester` - shared memory test utility
1. `wdtester` - watchdog test utility

The HPSC Eclipse distribution is also built and packaged in `${WORKING_DIR}/deploy/`:

1. `hpsc-eclipse.tar.gz` - HPSC Eclipse installer

Booting QEMU
------------

After the builds complete, the user can run the `run-qemu.sh` script to launch QEMU.
