#!/bin/bash

#
# Automatic build test for Cactus WaveToyC demo.
# Returns 0 on success.
#

set -e

# where to find WaveDemo files
WAVEDEMO="WaveDemo"
# get number of cores for compilation process, assuming a linux system
NUMCPUS=`awk '/^processor/ { N++ } END { print N }' /proc/cpuinfo`
# set make options
MAKEOPTS="-j$NUMCPUS -C $WAVEDEMO"

function print_usage()
{
	echo "
USAGE:
    test.sh [command] [options]

OPTIONS:
    -b, --build                        : build only
    -r, --run [path/to/parameter_file] : run only, make sure to build it first
    -m, --main                         : run main.pl only
    -h, --help                         : display this help
"
}

function execute_main()
{
	./main.pl > /dev/null <<EOF
2
0
0
EOF
}

function cmd_build()
{
	# first of all get source
	execute_main
	# compile
	make $MAKEOPTS > /dev/null
}

function cmd_run()
{
	# parameter file can be specified by an optional argument
	$WAVEDEMO/cactus_WaveDemo ${2:-"$HOME/git/Cactus/wavetoyc_none.par"}
}

function cmd_main()
{
	./main.pl <<EOF
2
0
0
EOF
}

# go
case "$1" in
	-b|--build)
		cmd_build
		;;
	-r|--run)
		cmd_run
		;;
	-m|--main)
		cmd_main
		;;
	-h|--help)
		print_usage
		;;
	*)
		cmd_build
		cmd_run
		;;
esac

exit 0
