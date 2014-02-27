#!/usr/bin/env bash

set -e

#
# This script builds the LibGeoDecomp.
#

# adjust here for your needs
HGDIR=$HOME/hg/libgeodecomp				   # checkout directory
INSTALL=no								   # may be yes or no
WRITEBUILDLOG=yes						   # may be yes or no
TESTIT=no								   # may be yes or no
ADDITIONAL_CMAKE_FLAGS="-DWITH_QT='FALSE'" # add cmakeflags here, like CXX etc ...
NUMCPUS=`awk '/^processor/ { N++ } END { print N }' /proc/cpuinfo`

# test for some tools
test -x `which hg`    || exit 1
test -x `which cmake` || exit 2
test -x `which make`  || exit 3

# log?
if [ "$WRITEBUILDLOG" == "yes" ] ; then
	LOG="build_log"
else
	LOG="/dev/null"
fi

# clone the repository or update if it exists
if ! [ -d "$HGDIR" ] ; then
	hg clone http://bitbucket.org/gentryx/libgeodecomp $HGDIR >/dev/null 2>&1
	cd $HGDIR
	mkdir -p build
else
	cd $HGDIR
	hg pull -u >/dev/null 2>&1
fi
cd build

# start build process
cmake $ADDITIONAL_CMAKE_FLAGS .. >/dev/null 2>&1
echo "Build startet on `date`" >$LOG
make "-j$NUMCPUS" >>$LOG 2>&1
[ "$TESTIT"  == "yes" ] && make test >>$LOG 2>&1
[ "$INSTALL" == "yes" ] && sudo make install && sudo ldconfig
echo "Build ended on `date`" >>$LOG

exit 0
