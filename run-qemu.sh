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
YOCTO_QEMU_DIR="$(find ${PWD}/poky/build/tmp/work/x86_64-linux/qemu-xilinx-native/ -name qemu-system-aarch64 | grep image | xargs $1 dirname)"
ARM_TF_FILE=${YOCTO_DEPLOY_DIR}/arm-trusted-firmware.elf # TODO: consider renaming this to bl31.elf or atf-bl31.elf to show that we're only using stage 3.1
ARM_TF_FILE_BIN=${YOCTO_DEPLOY_DIR}/arm-trusted-firmware.bin # TODO: consider renaming this to bl31.elf or atf-bl31.elf to show that we're only using stage 3.1
ROOTFS_FILE=${YOCTO_DEPLOY_DIR}/core-image-minimal-hpsc-chiplet.cpio.gz.u-boot
KERNEL_FILE=${YOCTO_DEPLOY_DIR}/Image
LINUX_DT_FILE=${YOCTO_DEPLOY_DIR}/hpsc.dtb
QEMU_DT_FILE=${YOCTO_DEPLOY_DIR}/qemu-hw-devicetrees/hpsc-arch.dtb
BL_FILE=${YOCTO_DEPLOY_DIR}/u-boot.elf
BL_FILE_BIN=${YOCTO_DEPLOY_DIR}/u-boot.bin

# Output files from the hpsc-baremetal build
BAREMETAL_DIR=${PWD}/hpsc-baremetal
TRCH_FILE=${BAREMETAL_DIR}/trch/bld/trch.elf
RTPS_FILE=${BAREMETAL_DIR}/rtps/bld/rtps.elf
RTPS_FILE_BIN=${BAREMETAL_DIR}/rtps/bld/rtps.bin

# Output files from the hpsc-R52-uboot build
R52_UBOOT_DIR=${PWD}/u-boot-r52
RTPS_BL_FILE=${R52_UBOOT_DIR}/u-boot.elf
RTPS_BL_FILE_BIN=${R52_UBOOT_DIR}/u-boot.bin

# External storage (NAND, SRAM) devices
# how to use:
#    -drive file=$HPPS_NAND_IMAGE,if=pflash,format=raw,index=3 \
#    -drive file=$HPPS_SRAM_FILE,if=pflash,format=raw,index=2 \
#    -drive file=$TRCH_SRAM_FILE,if=pflash,format=raw,index=0 \

HPPS_NAND_IMAGE=${YOCTO_DEPLOY_DIR}/rootfs_nand.bin
HPPS_SRAM_FILE=${YOCTO_DEPLOY_DIR}/hpps_sram.bin
TRCH_SRAM_FILE=${YOCTO_DEPLOY_DIR}/trch_sram.bin

# Controlling boot mode of HPPS (ramdisk or rootfs in NAND)
# how to use:
#    -device loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE,data-len=4,cpu-num=3 \

BOOT_MODE_ADDR=0x9f000000    # memory location to store boot mode code for HPPS U-boot
BOOT_MODE_DRAM=0x00000000    # HPPS rootfs in RAM
BOOT_MODE_NAND=0x0000f000    # HPPS rootfs in NAND (MTD device)

ARM_TF_ADDRESS=0x80000000
BL_ADDRESS=0x88000000
KERNEL_ADDR=0x80080000
LINUX_DT_ADDR=0x84000000
ROOTFS_ADDR=0x90000000

# RTPS
RTPS_FILE_ADDR=0x70000000		# load address for demo baremetal application
RTPS_BL_ADDR=0x60000000			# load address for R52 u-boot

# TRCH
HPSC_HOST_UTILS_DIR=${PWD}/hpsc-utils/host
SRAM_IMAGE_UTILS=${HPSC_HOST_UTILS_DIR}/sram-image-utils
SRAM_SIZE=0x4000000			# 64MB

# create non-volatile offchip sram image
function create_nvsram_image()
{
	set -e
	echo create_sram_image...
	# Create SRAM image to store boot images
	${SRAM_IMAGE_UTILS} create ${TRCH_SRAM_FILE} ${SRAM_SIZE}
	${SRAM_IMAGE_UTILS} add ${TRCH_SRAM_FILE} ${BL_FILE_BIN} 	"hpps-bl" ${BL_ADDRESS}
	${SRAM_IMAGE_UTILS} add ${TRCH_SRAM_FILE} ${ARM_TF_FILE_BIN} 	"hpps-fw" ${ARM_TF_ADDRESS}
	${SRAM_IMAGE_UTILS} add ${TRCH_SRAM_FILE} ${RTPS_BL_FILE_BIN} 	"rtps-bl" ${RTPS_BL_ADDR}
	${SRAM_IMAGE_UTILS} add ${TRCH_SRAM_FILE} ${RTPS_FILE_BIN} 	"rtps-os" ${RTPS_FILE_ADDR}
	${SRAM_IMAGE_UTILS} show ${TRCH_SRAM_FILE} 
	#${SRAM_IMAGE_UTILS} add ${TRCH_SRAM_FILE} ${KERNEL_FILE} ${KERNEL_ADDR}
	set +e
}

function usage()
{
    echo "Usage: $0 [-c < run | gdb | consoles | nand_create >] [-f < dram | nand >] [-b < dram | nvram >]" 1>&2
    echo "               -c run: command - start emulation (default)" 1>&2
    echo "               -c gdb: command - start emulation with gdb" 1>&2
    echo "               -c consoles: command - setup consoles of the subsystems at the host" 1>&2
    echo "               -c nand_create: command - create nand image with rootfs in it" 1>&2
    echo "               -b dram: boot images in dram (default)" 1>&2
    echo "               -b nvram: boot images in offchip non-volatile ram" 1>&2
    echo "               -f dram: HPPS rootfile system in ram, volatile (default)" 1>&2
    echo "               -f nand: HPPS rootfile system in nand image, non-volatile" 1>&2
    exit 1
}

# Labels are created by Qemu with the convention "serialN"
SCREEN_SESSIONS=(hpsc-trch hpsc-rtps-r52 hpsc-hpps)
SERIAL_PORTS=(serial0 serial1 serial2)
SERIAL_PORT_ARGS=()
for port in ${SERIAL_PORTS[*]}
do
    SERIAL_PORT_ARGS+=(-serial pty)
done

QMP_PORT=4433

function setup_screen()
{
    local SESSION=$1

    if [ $(screen -list "$SESSION" | grep -c "$SESSION") -gt 1 ]
    then
        # In case the user somehow ended up with more than one screen process,
        # kill them all and create a fresh one.
        echo "Found multiple screen sessions matching '$SESSION', killing..."
        screen -list "$SESSION" | grep "$SESSION" | \
            sed -n "s/\([0-9]\+\).$SESSION\s\+.*/\1/p" | xargs kill
    fi

    # There seem to be some compatibility issues between Linux distros w.r.t.
    # exit codes and behavior when using -r and -q with -ls for detecting if a
    # user is attached to a session, so we won't bother trying to wait for them.
    screen -q -list "$SESSION"
    # it's at least consistent that no matching screen sessions gives $? < 10
    if [ $? -lt 10 ]
    then
        echo "Creating screen session with console: $SESSION"
        screen -d -m -S "$SESSION"
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
            if [ $(echo "$ATTEMPTS" | wc -w) -eq 10 ]
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

    read -r -a PTYS_ARR <<< "$PTYS"
    for ((i = 0; i < ${#PTYS_ARR[@]}; i++))
    do
        # Need to start a new single-use $pty_sess screen session outside of the
        # persistent $sess one, then attach to $pty_sess from within $sess.
        # This is needed if $sess was previously attached, then detached (but
        # not terminated) after QEMU exited.
        local pty=${PTYS_ARR[$i]}
        local sess=${SCREEN_SESSIONS[$i]}
        local pty_sess="hpsc-pts$(basename "$pty")"
        echo "Adding console $pty to screen session $sess"
        screen -d -m -S "$pty_sess" "$pty"
        # TODO: Make this work without using "stuff" command
        screen -S "$sess" -X stuff "^C screen -m -r $pty_sess\r"
        echo "Attach to screen session from another window with:"
        echo "  screen -r $sess"
    done

    echo "Commanding Qemu to reset the machine..."
    ./qmp.py localhost $QMP_PORT cont
}

# default values
CMD="run"
BOOT_IMAGE_OPTION="dram"
HPPS_ROOTFS_OPTION="dram"

# parse options
while getopts ":b:c:f:" o; do
    case "${o}" in
        c)
            if [ "${OPTARG}" == "run" ] || [ "${OPTARG}" == "gdb" ] || [ "${OPTARG}" == "consoles" ] || [ "${OPTARG}" == "nand_create" ]
            then
                CMD="${OPTARG}"
            else
                echo "Error: no such command - ${OPTARG}"
                usage
            fi
            ;;
        b)
            if [ "${OPTARG}" == "dram" ] || [ "${OPTARG}" == "nvram" ]
            then
                BOOT_IMAGE_OPTION="${OPTARG}"
            else
                echo "Error: no such boot image option - ${OPTARG}"
                usage
            fi
            ;;
        f)
            if [ "${OPTARG}" == "dram" ] || [ "${OPTARG}" == "nand" ]
            then
                HPPS_ROOTFS_OPTION="${OPTARG}"
            else
                echo "Error: no such HPPS rootfile system option - ${OPTARG}"
                usage
            fi
            ;;
        *)
            echo "Wrong option" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# preparation of environment
case "$CMD" in
   run)
        for session in "${SCREEN_SESSIONS[@]}"
        do
            setup_screen $session
        done
        attach_consoles &
        ;;
   gdb)
        for session in "${SCREEN_SESSIONS[@]}"
        do
            setup_screen $session
        done
        attach_consoles &
        # setup/attach_consoles are called when gdb runs this script with "consoles"
        # cmd from the hook to the "run" command defined below:
        # NOTE: have to go through an actual file because -ex doesn't work since no way
        ## to give a multiline command (incl. multiple -ex), and bash-created file -x
        # <(echo -e ...) doesn't work either (issue only with gdb).
       GDB_CMD_FILE=$(mktemp)
cat >/"$GDB_CMD_FILE" <<EOF
define hook-run
shell $0 -c consoles
end
EOF
        GDB_ARGS=(gdb -x "$GDB_CMD_FILE" --args)
        ;;
    consoles)
        echo "run setup_screen"
        for session in "${SCREEN_SESSIONS[@]}"
        do
            setup_screen $session
        done
        echo "run attach_consoles"
        attach_consoles &
        exit # don't run qemu
        ;;
   nand_create)
        for session in "${SCREEN_SESSIONS[@]}"
        do
            setup_screen $session
        done
        attach_consoles &
        ;;
esac

#
# Compose qemu commands according to the command options.
# Build the command as an array of strings. Quote anything with a path variable
# or that uses commas as part of a string instance. Building as a string and
# using eval on it is error-prone, e.g., if spaces are introduced to parameters.
#
# See QEMU User Guide in HPSC release for explanation of the command line arguments
# Note: order of -device args may matter, must load ATF last, because loader also sets PC
# Note: If you want to see instructions and exceptions at a large performance cost, then add
# "in_asm,int" to the list of categories in -d.
BASE_COMMAND=("${GDB_ARGS[@]}" "${YOCTO_QEMU_DIR}/qemu-system-aarch64"
    -machine "arm-generic-fdt"
    -nographic
    -monitor stdio
    -qmp "telnet::$QMP_PORT,server,nowait"
    -S -s -D "/tmp/qemu.log" -d "fdt,guest_errors,unimp,cpu_reset"
    -hw-dtb "${QEMU_DT_FILE}"
    "${SERIAL_PORT_ARGS[@]}"
    -device "loader,addr=${LINUX_DT_ADDR},file=${LINUX_DT_FILE},force-raw,cpu-num=3"
    -device "loader,addr=${KERNEL_ADDR},file=${KERNEL_FILE},force-raw,cpu-num=3"
    -device "loader,file=${TRCH_FILE},cpu-num=0"
    -net "nic,vlan=0" -net "user,vlan=0,hostfwd=tcp:127.0.0.1:2345-10.0.2.15:2345,hostfwd=tcp:127.0.0.1:10022-10.0.2.15:22")
RTPS_FILE_LOAD=(-device "loader,file=${RTPS_FILE},cpu-num=1")
RTPS_FILE_BIN_LOAD=(-device "loader,addr=${RTPS_FILE_ADDR},file=${RTPS_FILE_BIN},cpu-num=1")
RTPS_BL_FILE_LOAD=(-device "loader,file=${RTPS_BL_FILE},cpu-num=1")
HPPS_UBOOT_LOAD=(-device "loader,file=${BL_FILE},cpu-num=3")
HPPS_ATF_LOAD=(-device "loader,file=${ARM_TF_FILE},cpu-num=3")
HPPS_ROOTFS_LOAD=(-device "loader,addr=${ROOTFS_ADDR},file=${ROOTFS_FILE},force-raw,cpu-num=3")
HPPS_NAND_LOAD=(-drive "file=$HPPS_NAND_IMAGE,if=pflash,format=raw,index=3")
HPPS_SRAM_LOAD=(-drive "file=$HPPS_SRAM_FILE,if=pflash,format=raw,index=2")
TRCH_SRAM_LOAD=(-drive "file=$TRCH_SRAM_FILE,if=pflash,format=raw,index=0")
BOOT_MODE_DRAM_LOAD=(-device "loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE_DRAM,data-len=4,cpu-num=3")
BOOT_MODE_NAND_LOAD=(-device "loader,addr=$BOOT_MODE_ADDR,data=$BOOT_MODE_NAND,data-len=4,cpu-num=3")

COMMAND=()
if [ "${CMD}" == "nand_create" ]
then
   BOOT_IMAGE_OPTION="dram"
   HPPS_ROOTFS_OPTION="dram"
   OPT_COMMAND=("${HPPS_NAND_LOAD[@]}")
fi
COMMAND+=("${BASE_COMMAND[@]}" "${OPT_COMMAND[@]}")

if [ "${BOOT_IMAGE_OPTION}" == "dram" ]    # Boot images are loaded onto DRAM by Qemu
then
    OPT_COMMAND=("${HPPS_UBOOT_LOAD[@]}" "${HPPS_ATF_LOAD[@]}" "${RTPS_BL_FILE_LOAD[@]}" "${RTPS_FILE_LOAD[@]}")
elif [ "${BOOT_IMAGE_OPTION}" == "nvram" ]	# Boot images are stored in an NVRAM and loaded onto DRAM by TRCH
then
    create_nvsram_image
    OPT_COMMAND=("${TRCH_SRAM_LOAD[@]}")
fi
COMMAND+=("${OPT_COMMAND[@]}")

if [ "${HPPS_ROOTFS_OPTION}" == "dram" ]    # HPPS rootfs is loaded onto DRAM by Qemu, volatile
then
    OPT_COMMAND=("${HPPS_ROOTFS_LOAD[@]}" "${BOOT_MODE_DRAM_LOAD[@]}")
elif [ "${HPPS_ROOTFS_OPTION}" == "nand" ]    # HPPS rootfs is stored in an Nand, non-volatile
then
    OPT_COMMAND=("${HPPS_NAND_LOAD[@]}" "${BOOT_MODE_NAND_LOAD[@]}")
fi
COMMAND+=("${OPT_COMMAND[@]}")

if [ "${CMD}" == "run" ]
then
    echo "Final Command: ${COMMAND[*]}"
fi

function finish {
    if [ -n "$GDB_CMD_FILE" ]
    then
        rm "$GDB_CMD_FILE"
    fi
}
trap finish EXIT

# Make it so!
"${COMMAND[@]}"
