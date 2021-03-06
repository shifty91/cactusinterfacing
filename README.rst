.. -*- restructuredtext -*-

==================================
Automatic Cactus Interfacing
==================================

0. Coding Style
===============
The Coding Style follows the following directions:
    - indention with tabs
    - tabsize is 4
    - style is Linux

1. Requirements
===============
The following requirements have to be met, otherwise it won't compile/work:
    - Perl modules
        - Exporter
        - FindBin
        - File::Copy
        - File::Path
        - File::Which
        - Getopt::Long
        - Storable
        - Tie::IxHash
    - Boost Regex           (for Perl like regex)
    - LibGeoDecomp, installed on your system
    - Cactus
    - optionally Artistic Style for formatting auto generated code

Perl should be installed on most systems by default. The exporter and
data dumper modules, too.

Installing LibGeoDecomp is also simple. First you have to clone the
repository and then build it from source. Therefore you'll need cmake
installed. An example of building LibGeoDecomp is shown below::

  $ hg clone http://bitbucket.org/gentryx/libgeodecomp
  $ cd libgeodecomp
  $ mkdir -p build
  $ cd build
  $ cmake ..
  $ make -j8
  $ make test
  $ make install

For further information on building and using LibGeoDecomp,
please refer to http://www.libgeodecomp.org/documentation.html.

2. About
========
This project aims to provide a interface for LibGeoDecomp to
execute Cactus thorns. It is mostly written in Perl. The code
parses the thorn's ccl files and generates a C++ cell and
initializer class for LibGeoDecomp. In order to modify the
thorn's code as little as possible auto generated macros are used.

The directory layout:
    - src/include :
      Contains C header files which override some basic
      Cactus macros and functions like CCTK_REAL etc.
    - src/types :
      Contains a C++ class which holds the variables representing
      the Cactus grid hierarchy.
    - src/parparser :
      Contains a C++ parser for Cactus parameter files.
    - lib :
      This directory contains the Perl code which parses the thorn's
      ccl files and generates the appropriate LibGeoDecomp classes.

For authors see file AUTHORS.

3. Example usage
================
The example below shows the adjustment of the Cactus WaveToyC demo::

  $ wget http://www.cactuscode.org/download/GetComponents
  $ chmod 755 GetComponents
  $ ./GetComponents http://cactuscode.org/documentation/tutorials/wavetoydemo/WaveDemo.th
  $ cd Cactus
  $ gmake WaveDemo-config
  $ gmake WaveDemo -j8
  $ export CCTK_HOME="/path/to/Cactus"
  $ cd ../cactusinterfacing
  $ ./main.pl
  $ cd WaveDemo
  $ gmake -j8
  $ ./cactus_WaveDemo <parameter_file>

First of all the Cactus flesh and the necessary thorns for building WaveDemo
are resolved. Next step is to build a configuration. You can either build with
MPI or without.
Now you change the directory to the interfacing code. The script you need to run
is main.pl. You will be asked for some question e.g. what thorn you want to
adjust.
Finally a new directory with the name of the configuration will be created and
everything needed will be stored there. This directory also contains a Makefile
which can be used to compile the final LibGeoDecomp application.
At least you should be able to run the application like the Cactus executable.

4. Configuration
================
The behavior of this tool may be changed by configuration options e.g. if
vectorized code should generated or not. All configuration options may be set by
a configuration file ~/.cactus_inf.rc which is loaded at start up. For a list of
all options see lib/Cactusinterfacing/Config.pm.
