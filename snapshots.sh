# This table duplicates information tracked in the parent repository.
# Updating this is manual: in the parent repository, for each TAG of interest,
# get the list of components changed relative to master:
#
#     git diff --stat master..TAG | grep '|' | cut -d'|' -f1
#
# The assumption is that the ref in each modified component has been
# tagged with the same tag TAG, named in convention FEATURE-$RELEASE.

declare -A SNAPSHOTS

RELEASE=2020.03

# Note: Bash can't store an array in a map.

SNAPSHOTS[linux-ml-5.5.10-$RELEASE]="\
    ssw/hpps/linux \
    ssw/hpsc-utils \
"
SNAPSHOTS[qemu4-$RELEASE]="\
    sdk/hpsc-sdk-tools \
    sdk/qemu \
    sdk/qemu-devicetrees \
    ssw/hpsc-baremetal \
    ssw/rtps/r52/u-boot \
"
SNAPSHOTS[rtps-r52-rtems-1.3-$RELEASE]="\
    sdk/rtems-source-builder \
    sdk/rtems-tools \
    ssw/rtps/r52/rtems \
"
SNAPSHOTS[uboot-v2020.01-$RELEASE]="\
    ssw/hpps/u-boot \
    ssw/rtps/a53/u-boot \
    ssw/rtps/r52/u-boot \
"
