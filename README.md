hpsc-bsp
========

The "hpsc-bsp" repository includes:
1.  The "build-hpsc-yocto.sh" script, which uses the Yocto framework to build the necessary files for running the QEMU emulation of the Chiplet.  In the process, it downloads the needed source code from the ISI Github webpage.  Note the user can specify which commit of each repo should be downloaded within the script.
2.  The "build-hpsc-baremetal.sh" script, which uses a separate toolchain to build the firmware for the TRCH and R52.
3.  The "run-qemu.sh" script, which uses the output from the build scripts above to boot QEMU.

HPSC Yocto Build
----------------

Before starting the Yocto build:
1.  Verify that your system has python3 installed, which is needed to run bitbake.
2.  Verify that the desired version of each repository will be used for the build.  This can be done by modifying the appropriate SRCREV_* environment variables listed in build-yocto-hpsc.sh.  Currently, the script uses the HEAD of the hpsc branch for each of the github repositories, but this can be changed.

After the build completes, the QEMU executable is located in:
poky/build/tmp/work/x86_64-linux/qemu-native/2.11.1-r0/image/usr/local/bin

In addition, several of the other needed files are located in the following directory:
poky/build/tmp/deploy/images/hpsc-chiplet

Specifically, the above directory includes the following generated files:
1.  arm-trusted-firmware.elf
	- The Arm Trusted Firmware binary
2.  core-image-minimal-hpsc-chiplet.cpio.gz.u-boot
	- The Linux root file system for booting the dual A53 cluster
3.  Image
	- The Linux kernel binary image
4.  hpsc.dtb
	- The Chiplet device tree for SMP Linux
5.  qemu-hw-devicetrees/hpsc-arch.dtb
	- The HPSC Chiplet device tree for QEMU
6.  u-boot.elf
	- The U-boot bootloader for the dual A53 cluster

The actual build directories for these files are located in the directory:
poky/build/tmp/work

The Yocto BSP is designed to download from the github repositories located at:
https://github.com/orgs/ISI-apex/teams/hpsc/repositories

hpsc-baremetal Build
--------------------

Before starting the hpsc-baremetal build, verify that the BAREMETAL_TOOLCHAIN_DIR variable in the script is properly set.  The script will then build the following files:
1.  trch/bld/trch.elf
2.  rtps/bld/rtps.elf

Booting QEMU
------------

Finally, after the build completes, the user can run the "run-qemu.sh" script (with some additional files that need to be built manually) in order to boot QEMU.
