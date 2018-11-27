#!/bin/bash

# The following variable needs to be updated:
MY_IP_ADDR=192.168.127.168

# Output files from the Yocto build
YOCTO_DEPLOY_DIR=~/yocto/poky/build/DK/BSP/tmp2
YOCTO_QEMU_DIR=~/WORK/qemu-build-github/aarch64-softmmu
QEMU_UTIL_DIR=${YOCTO_DEPLOY_DIR}
ARM_TF_FILE=${YOCTO_DEPLOY_DIR}/arm-trusted-firmware.elf # TODO: consider renaming this to bl31.elf or atf-bl31.elf to show that we're only using stage 3.1
ROOTFS_FILE=${YOCTO_DEPLOY_DIR}/yocto-rootfs.u-boot	# slow, but doesn't have the ssh-key issue each time
KERNEL_FILE=${YOCTO_DEPLOY_DIR}/Image
LINUX_DT_FILE=${YOCTO_DEPLOY_DIR}/hpsc.dtb
QEMU_DT_FILE=${YOCTO_DEPLOY_DIR}/hpsc-arch.dtb
BL_FILE=~/WORK/u-boot-R52/HPPS-u-boot

# Output files from the hpsc-baremetal build
BAREMETAL_DIR=~/WORK/hpsc-baremetal
TRCH_FILE=${BAREMETAL_DIR}/trch/bld/trch.elf
RTPS_FILE=${BAREMETAL_DIR}/rtps/bld/rtps.elf

# Nand and rootfs files
ROOTFS_NAND_FILE=${YOCTO_DEPLOY_DIR}/rootfs_nand.img
ROOTFS_CPIO=${YOCTO_DEPLOY_DIR}/yocto-rootfs.cpio
ROOTFS_TAR_FILE_NAME=rootfs.tar
ROOTFS_TAR_FILE=${YOCTO_DEPLOY_DIR}/${ROOTFS_TAR_FILE_NAME}
TMP_CPIO_DIR=/tmp/ROOTFS

# Controlling boot mode of HPPS (ramdisk or rootfs in NAND)
# how to use:
#	-device loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE,data-len=4,cpu-num=3 \
BOOT_MODE_ADDR=0x80000000	# memory location to store boot mode code for U-boot
BOOT_MODE=0x00000000	# rootfs in RAM
#BOOT_MODE=0x0000f000	# rootfs in NAND (MTD device)

# See QEMU User Guide in HPSC release for explanation of the command line arguments
# NOTE: order of -device args may matter, must load ATF last, because loader also sets PC
KERNEL_ADDR=0x80080000
LINUX_DT_ADDR=0x84000000
ROOTFS_ADDR=0x90000000

# port forwarding for a VM
PORT=10099

# 1. Create empty nand image
# qemu-nand-creator <page size=2k> <OOB size=64> <num of pages per block = 128k/2k> <num_block=256M/128k = 2k> <ecc size = 12> <empty nand = 1>
echo "Create empty nand image"
${QEMU_UTIL_DIR}/qemu-nand-creator 2048 64 64 2048 12 1
mv qemu_nand.bin $ROOTFS_NAND_FILE

# 2. Launch a VM 
echo "Launch a VM"
${YOCTO_QEMU_DIR}/qemu-system-aarch64 \
	-machine arm-generic-fdt \
	-nographic \
	-serial udp:${MY_IP_ADDR}:4441@:4451 \
	-serial udp:${MY_IP_ADDR}:4442@:4452 \
	-serial udp:${MY_IP_ADDR}:4443@:4453 \
	-hw-dtb $QEMU_DT_FILE \
	-device loader,addr=$LINUX_DT_ADDR,file=$LINUX_DT_FILE,force-raw,cpu-num=3 \
	-device loader,addr=$KERNEL_ADDR,file=$KERNEL_FILE,force-raw,cpu-num=3 \
	-device loader,file=$BL_FILE,cpu-num=3 \
	-device loader,file=$ARM_TF_FILE,cpu-num=3 \
	-device loader,file=$RTPS_FILE,cpu-num=2 \
	-device loader,file=$RTPS_FILE,cpu-num=1 \
	-device loader,file=$TRCH_FILE,cpu-num=0  \
	-device loader,addr=$ROOTFS_ADDR,file=$ROOTFS_FILE,force-raw,cpu-num=3 \
	-drive file=$ROOTFS_NAND_FILE,if=pflash,format=raw,index=3 \
	-device loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE,data-len=4,cpu-num=3 \
        -net nic,vlan=0 -net user,vlan=0,hostfwd=tcp:127.0.0.1:2345-10.0.2.15:2345,hostfwd=tcp:127.0.0.1:$PORT-10.0.2.15:22  &

QEMU_PID=$!

# 3. Prepare rootfs
echo "Prepare rootfs"
BASE_WD=${PWD}
mkdir -p $TMP_CPIO_DIR
rm -rf $TMP_CPIO_DIR/*
cd $TMP_CPIO_DIR
cpio -idmv < $ROOTFS_CPIO
tar -cvf $ROOTFS_TAR_FILE *
cd ${BASE_WD}

# 4. Wait for VM's boot
echo "Wait for VM's boot"
maxattempt=20
waitseconds=20
counter=1

# wait
sleep 200

while [ $counter -lt $maxattempt ]; do
  echo "attempt :" $counter
  ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 ls
  case $? in
    (0) break ;;
    (*) echo "Waiting ${waitseconds} seconds." ;;
  esac
  sleep $waitseconds
  counter=$(( $counter + 1 ))
done

# 5. Mount nand
echo "Mount nand"
ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 << EOF
	mkdir mnt;
	mount -t jffs2 /dev/mtdblock0 mnt;
EOF

# 6. Copy rootfs to nand 
echo "Copy rootfs to nand"
scp -P $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" $ROOTFS_TAR_FILE root@127.0.0.1:/tmp
ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 << EOF
	cd mnt;
	tar -xvf /tmp/$ROOTFS_TAR_FILE_NAME;
	chown -R root *;
	chgrp -R root *;
	cd ../;
	umount mnt;
EOF

sleep 10
echo "kill qemu process " $QEMU_PID
kill $QEMU_PID
echo "Done"
