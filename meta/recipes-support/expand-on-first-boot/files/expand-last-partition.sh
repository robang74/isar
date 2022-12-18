#!/bin/sh
#
# Resize last partition to full medium size
#
# This software was originally a part of ISAR
# Copyright (c) Siemens AG, 2018-2022
# SPDX-License-Identifier: MIT
#
# After its rework and generalisation this file was relicensed
# (C) 2022, Roberto A. Foglietta <roberto.foglietta@gmail.com>
# SPDX-License-Identifier: all rights reserved, but fair use allowed
# Fair use includes test, learning and marketing but not sales, redistribution
# leasing, renting or every other commercial/business activities without the
# consent of the author. Every company or individual allowed to use this
# code behind these limitations will be listed here below, if any.
#

exitnlog() {
	ec=$?
	set +e
	if [ "$ec" != "0" ]; then
		echo "ERROR: $0 failed"
	else
		echo "$0 succeded"
	fi >/dev/kmsg
	if [ "$ec" != "0" -a -e /etc/unsupervised ]; then
		reboot
	fi
}
export -f exitnlog
trap exitnlog EXIT

exitnlog() {
	ec=$?
	set +e
	if [ "$ec" != "0" ]; then
		echo "ERROR: $0 failed"
	else
		echo "$0 succeded"
	fi >/dev/kmsg
	if [ "$ec" != "0" -a -e /etc/unsupervised ]; then
		reboot
	fi
}
export -f exitnlog
trap exitnlog EXIT

set -e

udevadm settle

ROOT_DEV="$(findmnt / -o source -n)"
ROOT_DEV_NAME=${ROOT_DEV##*/}
ROOT_DEV_SLAVE=$(find /sys/block/"${ROOT_DEV_NAME}"/slaves -mindepth 1 -print -quit 2>/dev/null || true)
if [ -n "${ROOT_DEV_SLAVE}" ]; then
	ROOT_DEV=/dev/${ROOT_DEV_SLAVE##*/}
fi

# full resizing of ext4 and btrfs does not fail nor hurt but supporting more
# filesystems in future might change this condition, so commenting this code
useless_for_now() {
	# this value is in blocks. Normally a block has 512 bytes.
	BUFFER_SIZE=32768
	BOOT_DEV_NAME=${BOOT_DEV##*/}
	DISK_SIZE="$(cat /sys/class/block/"${BOOT_DEV_NAME}"/size)"
	ALL_PARTS_SIZE=0
	for PARTITION in /sys/class/block/"${BOOT_DEV_NAME}"/"${BOOT_DEV_NAME}"*; do
		PART_SIZE=$(cat "${PARTITION}"/size)
		ALL_PARTS_SIZE=$((ALL_PARTS_SIZE + PART_SIZE))
	done

	MINIMAL_SIZE=$((ALL_PARTS_SIZE + BUFFER_SIZE))
	if [ "$DISK_SIZE" -lt "$MINIMAL_SIZE" ]; then
		echo "Disk is practically already full, doing nothing." >&2
		exit 0
	fi
} 

# TODO, 14.12.2022: this change should be tested with a single volume system
# preliminary tests shown that ext4 and btrfs entire volumes cam be resized 
BOOT_DEV="$(echo "${ROOT_DEV}" | sed 's/p\?[0-9]*$//')"
if [ "${ROOT_DEV}" = "${BOOT_DEV}" ]; then
	LAST_PART="${BOOT_DEV}"
else
	LAST_PART="$(sfdisk -d "${BOOT_DEV}" 2>/dev/null | tail -1 | cut -d ' ' -f 1)"

	# Transform the partition table as follows:
	#
	# - Remove any 'last-lba' header so sfdisk uses the entire available space.
	# - If this partition table is MBR and an extended partition container (EBR)
	#   exists, we assume this needs to be expanded as well; remove its size
	#   field so sfdisk expands it.
	# - For the previously fetched last partition, also remove the size field so
	#   sfdisk expands it.
	sfdisk -d "${BOOT_DEV}" 2>/dev/null | \
		grep -v last-lba | \
		sed 's|^\(.*, \)size=[^,]*, \(type=[f5]\)$|\1\2|' | \
		sed 's|^\('"${LAST_PART}"' .*, \)size=[^,]*, |\1|' | \
		sfdisk --force "${BOOT_DEV}"

	# Inform the kernel about the partitioning change
	partx -u "${LAST_PART}"
fi

# Do not fail resize2fs if no mtab entry is found, e.g.,
# when using systemd mount units.
export EXT2FS_NO_MTAB_OK=1

eval $(blkid -o export ${LAST_PART} | grep -e '^TYPE=')
test "$TYPE" == "" && TYPE=$(lsblk -fno FSTYPE ${LAST_PART})

case $TYPE in
	ext[234]) resize2fs "${LAST_PART}"
		;;
	btrfs) 	err=0
		tmpdir=$(mktemp -d -p "$TMPDIR" btrfs.XXXX || \
			mktemp -d -p "/dev/shm" btrfs.XXXX)
		mount "${LAST_PART}" "$tmpdir"
		btrfs filesystem resize max "$tmpdir" || err=1
		umount "$tmpdir" && rmdir "$tmpdir"
		exit $err
		;;
	*)	echo "WARNING: $0 unsupported filesystem" >/dev/kmsg || true
		;;
esac && df -h ${LAST_PART}

