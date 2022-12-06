#!/bin/bash
set -eE
subject=$1
usermail=$(git config user.email)
destination=isar-users@googlegroups.com
test -n "$usermail" -a -n "$subject" -a -n "$2"
shift
set -x
git send-email --from $usermail --to $destination \
	--cc $usermail --subject "$subject" "$@"
