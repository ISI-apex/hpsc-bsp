HPSC Chiplet Board Support Package
==================================

This provides scripts to build a distributable binary release of the BSP for
the HPSC Chiplet shipped alongside the source release tarball. The binary
release supports one configuration of the HW emulator and the SSW software
stack out of many possible configurations supported by the source release, e.g.
the source release (but not the binary release) supports building images to
boot from non-volatile memory, boot from preloaded binaries, boot with BL0
bootloader or without, boot with or without power-on test suite, boot into
Yocto Linux or into bare Busybox, boot only a subset of subsystems, boot
on ZeBu and HAPS emulators, etc. To develop, build, run, and test BSP
components in place with dependency tracking for incremental builds that build
only components needed for a given configuration, in all supported
configurations (and to build on other distributions, or build without root),
build from source in `BUILD/src` directory according to instructions in
`BUILD/src/README.md`.

This repository includes:

1. `build-hpsc-bsp.sh` - top-level build script.
1. `build-hpsc-bare.sh` - builds artifacts with the bare metal compiler, including the TRCH firmware for the Cortex-M4 and u-boot for the Cortex-R52s.
1. `build-hpsc-host.sh` - builds artifacts for the host development system, including QEMU and associated utilities, and developer tools like the HPSC Eclipse distribution.
1. `build-hpsc-rtems.sh` - builds the RTEMS BSP and reference software for the RTPS Cortex-R52s, and an unused BSP for the TRCH.
1. `build-hpsc-yocto.sh` - builds Yocto Linux SDK for the HPPS Cortex-A53 clusters, including the reference root filesystem and Linux test utilities.
1. `build-hpsc-private.sh` - builds private sources.
1. `build-recipe.sh` - build individual component recipes; wrapped by other build scripts.
1. `run-qemu.sh` - runs QEMU using artifacts deployed by the build scripts (prior to packaging).

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

BSP QEMU configuration files and scripts are managed by the `bsp` build recipe and are source-controlled in `build-recipes/bsp/utils/`.


BSP Build
---------

The top-level `build-hpsc-bsp.sh` script wraps the other build scripts documented below and packages the BSP's binary and source tarballs.

By default, it will run through the following steps, which may be run independently using the `-a` flag so long as previous steps are complete:

* `fetch` - download toolchains and fetch all sources required to build offline
* `build` - build sources for the binary release
* `stage` - stage artifacts into the directory structure to be packaged
* `package` - package the staged directory structure into the BSP binary release archive
* `package-sources` - package sources into the BSP source release archive

To perform a build:

	./build-hpsc-bsp.sh

All files are downloaded and built in a working directory, which defaults to `BUILD`.
You may optionally specify a different working directory using `-w`.


Host Build
----------

To independently fetch and build host development system artifacts:

	./build-hpsc-host.sh

The build generates in `${WORKING_DIR}/deploy`:
1. `conf` - QEMU configuration directory
1. `qemu-env.sh` - QEMU configuration parameters
1. `run-qemu.sh` - QEMU launch script
1. `test.sh` - Pytest launch script

and in `${WORKING_DIR}/deploy/sdk`:

1. `qemu-devicetrees` - QEMU device tree directory
1. `qemu-bridge-helper` - QEMU utility for creating TAP devices
1. `qemu-system-aarch64` - QEMU binary
1. `hpsc-eclipse-cpp-2018-09-linux-gtk-x86_64.tar.gz` - HPSC Eclipse installer
1. `tools` - a directory with host utility scripts and binaries

and _non-relocatable_ SDKs in `${WORKING_DIR}/env`:

1. `RSB-5` - RTEMS Source Builder SDK
1. `RT-5` - RTEMS Tools


Bare Metal Build
----------------

To independently fetch and build the bare metal toolchain and dependent artifacts:

	./build-hpsc-bare.sh

The build generates in `${WORKING_DIR}/sdk/toolchains`:

1. `gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2` - ARM bare metal toolchain

and in `${WORKING_DIR}/deploy/ssw/trch`:

1. `trch.bin` - TRCH firmware
1. `syscfg-schema.json` - schema for system configuration parsed by TRCH

and in `${WORKING_DIR}/deploy/ssw/rtps/r52`:

1. `u-boot.bin` - u-boot for the RTPS R52s

The bare metal toolchain is also installed locally at `${WORKING_DIR}/env/gcc-arm-none-eabi-7-2018-q2-update`.


RTEMS Build
-----------

To independently fetch and build the RTEMS TRCH and R52 BSPs, and dependent artifacts:

	./build-hpsc-rtems.sh

The build generates _non-relocatable_ BSPs in `${WORKING_DIR}/env`:

1. `RTEMS-5-RTPS-R52` - RTPS R52 RTEMS BSP for building RTEMS applications
1. `RTEMS-5-TRCH` - RTPS R52 RTEMS BSP for building RTEMS applications

and in `${WORKING_DIR}/deploy/ssw/rtps/r52`:

1. `rtps-r52.img` - RTPS R52 firmware


Yocto Build
-----------

To independently fetch and build the Yocto SDK and dependent artifacts:

	./build-hpsc-yocto.sh

The build generates in `${WORKING_DIR}/deploy/sdk/toolchains`:

1. `poky-glibc-x86_64-core-image-hpsc-aarch64-hpsc-chiplet-toolchain-2.7.1.sh` - the Yocto SDK installer

and in `${WORKING_DIR}/deploy/ssw/hpps/`:

1. `arm-trusted-firmware.bin` - the Arm Trusted Firmware binary
1. `core-image-hpsc-hpsc-chiplet.cpio.gz.u-boot` - the Linux root file system for booting the dual A53 cluster
1. `hpsc.dtb` - the Chiplet device tree for SMP Linux
1. `Image.gz` - the Linux kernel binary image
1. `u-boot.dtb` - the U-boot device tree
1. `u-boot-nodtb.bin` - the U-boot bootloader for the dual A53 cluster

and in `${WORKING_DIR}/deploy/ssw/`:

1. `tests` - a directory with the pytest test infrastructure

The Yocto SDK is also installed locally at `${WORKING_DIR}/env/yocto-hpps-sdk`.


Booting QEMU
------------

After the builds complete, developers can execute the top-level `run-qemu.sh` script to launch QEMU.
This approach uses the artifacts in the working `deploy` directory, avoiding the need to always create and extract the BSP release tarball during development.

***WARNING: Do not edit files in the working directory `${WORKING_DIR}` (such as `deploy/qemu-env.sh`)!***
`${WORKING_DIR}` is managed exclusively by the build scripts.
To override the default QEMU configuration, create and use a custom environment file outside the working directory.
For example:

	./run-qemu.sh -- -e /path/to/qemu-env-override.sh
