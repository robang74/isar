#!/bin/bash

trap 'ERROR: in line $LINENO, abort due to set -e' ERR  
set -e

gfreload
bcur
pcache ||:
if [ "x${1:-}" == "x-r" ]; then
    if lsrmt | grep -qw ilbers; then
        git remote remove ilbers
    fi
fi
if ! lsrmt | grep -qw ilbers; then
    git remote add ilbers https://github.com/ilbers/isar.git
fi
frmt -a
trap - ERR
echo "git rebase ilbers/next"
git rebase ilbers/next
