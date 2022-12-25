#!/usr/bin/env bash
# Script for CI system build
#
# Alexander Smirnov <asmirnov@ilbers.de>
# Copyright (c) 2016-2018 ilbers GmbH

set -e

ES_BUG=3

# Export $PATH to use 'parted' tool
export PATH=$PATH:/sbin

# Go to Isar root
cd "$(dirname "$0")/.."

for i in virtualenv umoci skopeo reprepro quilt zstd debootstrap qemu-debootstrap; do
	if ! command -v $i > /dev/null; then
	    if [ "$updated" != "1" ]; then
                sudo apt-get update
	    fi
	    sudo apt install -y ${i/qemu-debootstrap/qemu-user-static}
	    updated=1
	fi
done

# install avocado in virtualenv in case it is not there already
if ! command -v avocado > /dev/null; then
    tmpdir=$(mktemp -p "$TMPDIR" -d avocado_venv.XXXX)
    trap "rm -rf $tmpdir" EXIT
    virtualenv --python python3 $tmpdir
    source $tmpdir/bin/activate
    pip install avocado-framework==96.0
fi

# Get Avocado build tests path
TESTSUITE_DIR="$(pwd)/testsuite"

# Start tests in current path by default
BASE_DIR=./build

# Check dependencies
DEPENDENCIES="umoci skopeo"
for prog in ${DEPENDENCIES} ; do
    if [ ! -x "$(which $prog)" ] ; then
        echo "missing $prog in PATH" >&2
    fi
done

show_help() {
    echo "This script builds the default Isar images."
    echo
    echo "Usage:"
    echo "    $0 [params]"
    echo
    echo "Parameters:"
    echo "    -b, --base BASE_DIR      set path to base directory. If not set,"
    echo "                             the tests will be started in current path."
    echo "    -c, --cross              enable cross-compilation."
    echo "    -d, --debug              enable debug bitbake output."
    echo "    -f, --fast               cross build reduced set of configurations."
    echo "    -q, --quiet              suppress verbose bitbake output."
    echo "    -r, --repro              enable use of cached base repository."
    echo "    -n, --norun              do not execute QEMU run tests."
    echo "    -t, --timeout SEC        specify time in seconds to wait before stop QEMU."
    echo "                             The default is: 300"
    echo "    --help                   display this message and exit."
    echo
    echo "Exit status:"
    echo " 0  if OK,"
    echo " 3  if invalid parameters are passed."
}

TAGS="full"
CROSS_BUILD="0"
QUIET="0"
TIMEOUT=300

# Parse command line to get user configuration
while [ $# -gt 0 ]
do
    key="$1"

    case $key in
    -h|--help)
        show_help
        exit 0
        ;;
    -b|--base)
        BASE_DIR="$2"
        shift
        ;;
    -c|--cross)
        CROSS_BUILD="1"
        ;;
    -d|--debug)
        VERBOSE="--show=app,test"
        ;;
    -f|--fast)
        # Start build for the reduced set of configurations
        # Enforce cross-compilation to speed up the build
        TAGS="fast"
        CROSS_BUILD="1"
        ;;
    -q|--quiet)
        QUIET="1"
        ;;
    -r|--repro)
        REPRO_BUILD="1"
        # This switch is deprecated, just here to not cause failing CI on
        # legacy configs
        case "$2" in
        -s|--sign) shift ;;
        esac
        ;;
    -n|--norun)
        NORUN="1"
        ;;
    -t|--timeout)
        TIMEOUT=$2
        shift
        ;;
    *)
        echo "error: invalid parameter '$key', please try '--help' to get list of supported parameters"
        exit $ES_BUG
        ;;
    esac

    shift
done

if [ -z "$REPRO_BUILD" ]; then
    TAGS="$TAGS,-repro"
fi

if [ -n "$NORUN" ]; then
    TAGS="$TAGS,-startvm"
fi

# Provide working path
mkdir -p .config/avocado
cat <<EOF > .config/avocado/avocado.conf
[datadir.paths]
base_dir = $(realpath $BASE_DIR)/
test_dir = $(realpath $BASE_DIR)/tests
data_dir = $(realpath $BASE_DIR)/data
logs_dir = $(realpath $BASE_DIR)/job-results
EOF
export VIRTUAL_ENV="./"

# the real stuff starts here, trace commands from now on
set -x

avocado $VERBOSE run "$TESTSUITE_DIR/citest.py" \
    -t $TAGS --nrunner-max-parallel-tasks=1 --disable-sysinfo \
    -p quiet=$QUIET -p cross=$CROSS_BUILD -p time_to_wait=$TIMEOUT
