# Resize last partition to full medium size on fist boot
#
# This software is a part of ISAR.
# Copyright (c) Siemens AG, 2018-2022
#
# SPDX-License-Identifier: MIT

inherit dpkg-raw

DESCRIPTION = "This service grows the last partition to the full medium during first boot"
MAINTAINER = "isar-users <isar-users@googlegroups.com>"

DEBIAN_DEPENDS = "systemd, sed, grep, coreutils, mount, e2fsprogs, fdisk (>=2.29.2-3) | util-linux (<2.29.2-3), util-linux, btrfs-progs, udev"

SRC_URI = " \
    file://expand-on-first-boot.service \
    file://expand-last-partition.sh \
    file://postinst"

do_install() {
    install -d -m 755 ${D}/lib/systemd/system
    install -m 644 ${WORKDIR}/expand-on-first-boot.service ${D}/lib/systemd/system/

    install -d -m 755 ${D}/usr/share/expand-on-first-boot
    install -m 755 ${WORKDIR}/expand-last-partition.sh ${D}/usr/share/expand-on-first-boot/
}
