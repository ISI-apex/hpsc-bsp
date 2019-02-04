#!/bin/bash

# The following variable needs to be updated:
# Nand and rootfs files

YOCTO_DEPLOY_DIR=${PWD}/poky/build/tmp/deploy/images/hpsc-chiplet
HPSC_HOST_UTILS_DIR=${PWD}/hpsc-utils/host
ROOTFS_CPIO=${YOCTO_DEPLOY_DIR}/core-image-minimal-hpsc-chiplet.cpio
ROOTFS_TAR_FILE_NAME=rootfs.tar
ROOTFS_TAR_FILE=${YOCTO_DEPLOY_DIR}/${ROOTFS_TAR_FILE_NAME}
TMP_CPIO_DIR=/tmp/ROOTFS

# these variables must be the same that in run-qemu.sh file
# nand image name to be destroyed and created freshly
HPPS_NAND_IMAGE=${YOCTO_DEPLOY_DIR}/rootfs_nand.bin
# port forwarding for a VM
PORT=10022

# 1. Create empty nand image
# qemu-nand-creator <page size=2k> <OOB size=64> <num of pages per block = 128k/2k> <num_block=256M/128k = 2k> <ecc size = 12> <empty nand = 1>
echo "Create empty nand image"
"${HPSC_HOST_UTILS_DIR}/qemu-nand-creator" 2048 64 64 2048 12 1
mv qemu_nand.bin "$HPPS_NAND_IMAGE"

./run-qemu.sh -c nand_create &
QEMU_PID=$!

# 3. Prepare rootfs
echo "Prepare rootfs"
BASE_WD=${PWD}
mkdir -p $TMP_CPIO_DIR
rm -rf $TMP_CPIO_DIR/*
cd $TMP_CPIO_DIR
cpio -idm < "$ROOTFS_CPIO"
tar -cf "$ROOTFS_TAR_FILE" ./*
cd "${BASE_WD}"

# 4. Wait for VM's boot
echo "Wait for VM's boot"
maxattempt=20
waitseconds=20

# wait
sleep 200

for i in $(seq 1 $maxattempt); do
  echo "attempt : $i"
  ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 ls
  case $? in
    (0) break ;;
    (*) echo "Waiting ${waitseconds} seconds." ;;
  esac
  sleep $waitseconds
done

# 5. Mount nand
echo "Mount nand"
ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 << EOF
	mkdir mnt;
	mount -t jffs2 /dev/mtdblock0 mnt;
EOF

# 6. Copy rootfs to nand 
echo "Copy rootfs to nand"
scp -P $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" "$ROOTFS_TAR_FILE" root@127.0.0.1:/tmp
ssh -p $PORT -o "StrictHostKeyChecking no" -o "UserKnownHostsFile /dev/null" root@127.0.0.1 << EOF
	cd mnt;
	tar -xvf /tmp/$ROOTFS_TAR_FILE_NAME;
	chown -R root *;
	chgrp -R root *;
	cd ../;
	umount mnt;
EOF

sleep 10
echo "kill qemu process " "$QEMU_PID"
kill "$QEMU_PID"
echo "Done"
exit
