#!/bin/bash

# Note: Before running the following script, please make sure to:
#
# 1.  Run the "build-hpsc-yocto.sh" script with the "bitbake core-image-minimal"
#     option in order to generate many of the needed QEMU files.
#
# 2.  Run the "build-hpsc-baremetal.sh" script (with the proper toolchain
#     path) to create the baremetal firmware files "trch.elf" and "rtps.elf".

# Output files from the Yocto build
YOCTO_DEPLOY_DIR=${PWD}/poky/build/tmp/deploy/images/hpsc-chiplet
YOCTO_QEMU_DIR=${PWD}/poky/build/tmp/work/x86_64-linux/qemu-native/2.11.1-r0/image/usr/local/bin
ARM_TF_FILE=${YOCTO_DEPLOY_DIR}/arm-trusted-firmware.elf # TODO: consider renaming this to bl31.elf or atf-bl31.elf to show that we're only using stage 3.1
ROOTFS_FILE=${YOCTO_DEPLOY_DIR}/core-image-minimal-hpsc-chiplet.cpio.gz.u-boot
KERNEL_FILE=${YOCTO_DEPLOY_DIR}/Image
LINUX_DT_FILE=${YOCTO_DEPLOY_DIR}/hpsc.dtb
QEMU_DT_FILE=${YOCTO_DEPLOY_DIR}/qemu-hw-devicetrees/hpsc-arch.dtb
BL_FILE=${YOCTO_DEPLOY_DIR}/u-boot.elf

# Output files from the hpsc-baremetal build
BAREMETAL_DIR=${PWD}/hpsc-baremetal
TRCH_FILE=${BAREMETAL_DIR}/trch/bld/trch.elf
RTPS_FILE=${BAREMETAL_DIR}/rtps/bld/rtps.elf

# External storage (NAND, SRAM) devices
# how to use:
#	-drive file=$HPPS_NAND_IMAGE,if=pflash,format=raw,index=3 \
#	-drive file=$HPPS_SRAM_FILE,if=pflash,format=raw,index=2 \
#	-drive file=$TRCH_SRAM_FILE,if=pflash,format=raw,index=0 \

HPPS_NAND_IMAGE=${YOCTO_DEPLOY_DIR}/rootfs_nand.bin
HPPS_SRAM_FILE=${YOCTO_DEPLOY_DIR}/hpps_sram.bin
TRCH_SRAM_FILE=${YOCTO_DEPLOY_DIR}/trch_sram.bin

# Controlling boot mode of HPPS (ramdisk or rootfs in NAND)
# how to use:
#	-device loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE,data-len=4,cpu-num=3 \

BOOT_MODE_ADDR=0x9f000000	# memory location to store boot mode code for U-boot
BOOT_MODE=0x00000000	# rootfs in RAM
#BOOT_MODE=0x0000f000	# rootfs in NAND (MTD device)

KERNEL_ADDR=0x80080000
LINUX_DT_ADDR=0x84000000
ROOTFS_ADDR=0x90000000

# Labels are created by Qemu with the convention 'serialN'
SERIAL_PORTS=(serial0 serial1 serial2)
for port in ${SERIAL_PORTS[*]}
do
    SERIAL_PORT_ARGS+=" -serial pty "
done

CONSOLE_SCREEN_SESSION=hpsc-qemu-consoles
QMP_PORT=4433

function setup_consoles()
{
    screen -r -q -list $CONSOLE_SCREEN_SESSION
    RC=$?

    local KILL=0
    if [ $RC -gt 10 ] # >=11 = running but not resumable (i.e. not attached)
    then
        # We kill the detached session rather than asking user to attach,
        # because the splits would be lost. Splits are lost when the
        # windows die while detached.
        echo "Found a detached matching screen session: killing..."
        KILL=1
    fi
    if [ $(screen -list $CONSOLE_SCREEN_SESSION | grep $CONSOLE_SCREEN_SESSION | wc -l) -gt 1 ]
    then
        # This shouldn't happen, but in case the user somehow ended up with more than one,
        # screen process, kill them all and create a fresh one.
        echo "Found more than one matching screen sessions: killing..."
        KILL=1
    fi

    if [ $KILL -eq 1 ]
    then
        echo "Killing existing screen sessions matching '$CONSOLE_SCREEN_SESSION'"
        screen -list $CONSOLE_SCREEN_SESSION | grep $CONSOLE_SCREEN_SESSION | \
            sed -n "s/\([0-9]\+\).$CONSOLE_SCREEN_SESSION\s\+.*/\1/p" | xargs kill
    fi

    screen -r -q -list $CONSOLE_SCREEN_SESSION
    RC=$?
    if [ $RC -lt 10 ] # 10 = running but non-resumable, >=11 = n-10 sessions running and resumeable
    then
        echo "Created screen session with consoles: $CONSOLE_SCREEN_SESSION"
        screen -d -m -S $CONSOLE_SCREEN_SESSION

        # Create split regions in the new screen session
        # NOTE: The split command works only while the screen session is attached, so have to wait
        echo "Waiting for you to attach to screen session from another window with: screen -r $CONSOLE_SCREEN_SESSION"
        while true
        do
            screen -r -q -list $CONSOLE_SCREEN_SESSION
            if [ $? -eq 10 ]
            then
                break
            fi
            sleep 1
        done
        for port in $(seq 2 ${#SERIAL_PORTS[@]}) # -1
        do
            screen -S $CONSOLE_SCREEN_SESSION -X split -v
        done
    else
        if [ $RC -gt 10 ] # >=11 means session resumeable (i.e. not attached)
        then
            # The kill logic above should make this impossible, but just in case
            echo "ERROR: matching screen session is detached, kill it please:"
            screen -list $CONSOLE_SCREEN_SESSION
            exit
        else # $RC = 10 (i.e. exists and attached)
            echo "Will add consoles to attached screen session: $CONSOLE_SCREEN_SESSION"
        fi
    fi
}

function attach_consoles()
{
	echo "Waiting for Qemu to open QMP port and to query for PTY paths..."
	#while test $(lsof -ti :$QMP_PORT | wc -l) -eq 0
	while true
	do
		PTYS=$(./qmp.py -q localhost $QMP_PORT query-chardev ${SERIAL_PORTS[*]} 2>/dev/null)
		if [ -z "$PTYS" ]
		then
			#echo "Waiting for Qemu to open QMP port..."
			sleep 1
			ATTEMPTS+=" 1 "
			if [ $(echo $ATTEMPTS | wc -w) -eq 10 ]
			then
				echo "ERROR: failed to get PTY paths from Qemu via QMP port: giving up."
				echo "Here is what happened when we tried to get the PTY paths:"
				./qmp.py -q localhost $QMP_PORT query-chardev ${SERIAL_PORTS[*]}
				exit # give up to not accumulate waiting processes
			fi
		else
			break
		fi
	done

	for pty in $PTYS
	do
	    echo Adding console $pty to screen session $CONSOLE_SCREEN_SESSION
	    screen -S $CONSOLE_SCREEN_SESSION -X screen $pty
	    screen -S $CONSOLE_SCREEN_SESSION -X focus # switch to next region
	done

        echo "Commanding Qemu to reset the machine..."
        ./qmp.py localhost $QMP_PORT cont
}

# We accept a optional command argument in order to call this script from GDB
# to setup consoles.
if [ -n "$1" ]
then
    CMD=$1
else # default
    CMD=run
fi

echo Command: $CMD
case "$CMD" in
run)
setup_consoles
attach_consoles &
# keep going to the qemu launch cmd below
;;
gdb)
# setup/attach_consoles are called when gdb runs this script with 'console'
# cmd from the hook to the 'run' command defined below:
# NOTE: have to go through an actual file because -ex doesn't work since no way
# to give a multiline command (incl. multiple -ex), and bash-created file -x
# <(echo -e ...) doesn't work either (issue only with gdb).
GDB_CMD_FILE=$(mktemp)
cat >/$GDB_CMD_FILE <<EOF
define hook-run
shell $0 console
end
EOF
GDB_ARGS="gdb -x $GDB_CMD_FILE --args "
# keep going to the qemu launch cmd below
;;
console)
setup_consoles
attach_consoles &
exit # don't run qemu
;;
esac

function finish {
	if [ -n "$GDB_CMD_FILE" ]
	then
	    rm "$GDB_CMD_FILE"
	fi
}
trap finish EXIT

# See QEMU User Guide in HPSC release for explanation of the command line arguments
# Note: order of -device args may matter, must load ATF last, because loader also sets PC
# Note: If you want to see instructions and exceptions at a large performance cost, then add
# "in_asm,int" to the list of categories in -d.

$GDB_ARGS ${YOCTO_QEMU_DIR}/qemu-system-aarch64 \
	-machine arm-generic-fdt \
	-nographic \
	-monitor stdio \
	-qmp telnet::$QMP_PORT,server,nowait \
	-S -s -D /tmp/qemu.log -d fdt,guest_errors,unimp,cpu_reset \
	-hw-dtb ${QEMU_DT_FILE} \
	$SERIAL_PORT_ARGS \
	-device loader,addr=${ROOTFS_ADDR},file=${ROOTFS_FILE},force-raw,cpu-num=3 \
	-device loader,addr=${LINUX_DT_ADDR},file=${LINUX_DT_FILE},force-raw,cpu-num=3 \
	-device loader,addr=${KERNEL_ADDR},file=${KERNEL_FILE},force-raw,cpu-num=3 \
	-device loader,file=${BL_FILE},cpu-num=3 \
	-device loader,file=${ARM_TF_FILE},cpu-num=3 \
	-device loader,file=${RTPS_FILE},cpu-num=2 \
	-device loader,file=${RTPS_FILE},cpu-num=1 \
	-device loader,file=${TRCH_FILE},cpu-num=0  \
        -net nic,vlan=0 -net user,vlan=0,hostfwd=tcp:127.0.0.1:2345-10.0.2.15:2345,hostfwd=tcp:127.0.0.1:10022-10.0.2.15:22 \
