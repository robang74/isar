#!/bin/bash
set -eE
if [ "$2" == "" -a -f "$1" ]; then
	echo "Retrieving subject from the patchi ..."
	subject=$(grep Subject: "$1" | head -n1 | cut -d: -f2 | cut -d' ' -f2-)
	patch=$1
else
	subject=$1
	patch=$2
fi
usermail=$(git config user.email)
destination=isar-users@googlegroups.com
test -n "$usermail" -a -n "$subject" -a -n "$patch"
shift
set -x
git send-email --from $usermail --to $destination \
	--cc $usermail --subject "$subject" "$patch"
