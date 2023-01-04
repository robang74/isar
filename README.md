## ISAR - Integration System for Automated Root filesystem generation

ISAR is a set of scripts for building software packages and repeatable
generation of Debian-based root filesystems with customizations.

### Download

- https://github.com/robang74/isar.git

### Build

Instruction on how to build can be found in the

- [User Manual](doc/user_manual.md).

### Try

To test the QEMU image, run the following command:

	start_vm -a <arch of your build> -d <distro of your build>

Ex: Architecture of your build could be arm,arm64,i386,amd64,etc.
    Distribution of your build could be buster,bullseye,bookworm,etc.

The default root password is 'root'.

To test the RPi board, flash the image to an SD card using the instructions
from the official site, section "WRITING AN IMAGE TO THE SD CARD":

- https://www.raspberrypi.org/documentation/installation/installing-images/README.md

### Supported distributions

List of supported distributions, architectures and features can be found in the

- [Supported_Configurations](Supported_Configurations.md).

### Support

Mailing lists:

* Using Isar: https://groups.google.com/d/forum/isar-users
  * Subscribe: isar-users+subscribe@googlegroups.com
  * Unsubscribe: isar-users+unsubscribe@googlegroups.com

* Collaboration: https://lists.debian.org/debian-embedded/
  * Subscribe: debian-embedded-request@lists.debian.org, Subject: subscribe
  * Unsubscribe: debian-embedded-request@lists.debian.org, Subject: unsubscribe

Commercial support: info@ilbers.de

### Credits

* Developed by ilbers GmbH & Siemens AG
* Sponsored by Siemens AG
* Re-worked by Roberto A. Foglietta

### Fork

This is a modified fork maintained by

* Roberto A. Foglietta <roberto.foglietta@gmail.com>

### License

Almost all the files are under MIT license or GPLv2 and the others are in the
public domain. However the composition of these files is protected by the GPLv3
license.

This means that everyone can use a single MIT licensed file or a part of it
under the MIT license terms. Instead, using two of them or two parts of them
implies that you are using a subset of this collection. Thus a derived work of
this collection which is licensed under the GPLv3 also.

The GPLv3 license applies to the composition unless you are the original
copyright owner or the author of a specific unmodified file. This means that
every one that can legally claim rights about the original files maintains its
rights, obviously. So, it should not need to complain with the GPLv3 license
applied to the composition. Unless, the composition is adopted for the part
which had not the rights, before.

An exception is this specific file which is "all rights reserved, but fair use
allowed", here:

* [expand-last-partition.sh](meta/recipes-support/expand-on-first-boot/files/expand-last-partition.sh) which is different among branches, check which one you are using

This file will be installed into the images created by this fork when your
layer will use

	IMAGE_INSTALL += "expand-on-first-boot"

is added to the image recipe. Thus this file license applies also to produced
images.

For further information or requests about licensing and how to obtain your own
business-like fork, please write to the project maintainer:

* Roberto A. Foglietta roberto.foglietta@gmail.com

Have fun! <3
