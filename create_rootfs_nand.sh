#!/bin/bash

# The following variable needs to be updated:
# Nand and rootfs files

source "$(dirname "$0")/qemu-env.sh"

# port forwarding for a VM
PORT=10022

# 1. Create empty nand image, attach it to the emulator, and boot Linux
./run-qemu.sh &
QEMU_PID=$!

# 3. Prepare rootfs
echo "Prepare rootfs"
BASE_WD=${PWD}
mkdir -p "$TMP_CPIO_DIR"
rm -rf "$TMP_CPIO_DIR"/*
cd "$TMP_CPIO_DIR"
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
