#!/bin/bash

#
# Automatic build test for Cactus WaveToyC demo.
#  - executes the code generator on the Cactus WaveDemo
#  - builds it
#  - runs it
# Returns 0 on success.
#

set -e

# where to find cactus etc.
CONFIG="WaveDemo"
EVOLTHORN="CactusWave/WaveToyC"
INITTHORN="CactusWave/IDScalarWaveC"
# get number of cores for compilation process, assuming a linux system
NUMCPUS=`awk '/^processor/ { N++ } END { print N }' /proc/cpuinfo`
# set make options
MAKEOPTS="-j$NUMCPUS -C $CONFIG"
MAINOPTS="--evolthorn $EVOLTHORN --initthorn $INITTHORN --config $CONFIG"

function print_usage()
{
	echo "
USAGE:
    $0 [command] [options]

OPTIONS:
    -b, --build                        : build only
    -r, --run [path/to/parameter_file] : run only, make sure to build it first
    -m, --main                         : run main.pl only
    -h, --help                         : display this help
"
}

function get_cctk_home
{
	if [ -z "$CCTK_HOME" ] ; then
		echo -n "Enter the Cactus home directory: "
		read CCTK_HOME
		if ! [ -d "$CCTK_HOME" ] ; then
			echo "This is not a valid directory!"
			exit -1
		fi
	fi
}

function execute_main()
{
	../main.pl $MAINOPTS > /dev/null <<EOF
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
	"$CONFIG/cactus_$CONFIG" "$1"
}

function cmd_main()
{
	../main.pl $MAINOPTS <<EOF
0
EOF
}

# first check cctk_home
get_cctk_home
MAINOPTS="$MAINOPTS --cactushome $CCTK_HOME"

# go
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"
case "$1" in
	-b|--build)
		cmd_build
		;;
	-r|--run)
		cmd_run ${2:-"$HOME/git/Cactus/WaveDemo.par"}
		;;
	-m|--main)
		cmd_main
		;;
	-h|--help)
		print_usage
		;;
	*)
		cmd_build
		cmd_run ${1:-"$HOME/git/Cactus/WaveDemo.par"}
		;;
esac

exit 0
