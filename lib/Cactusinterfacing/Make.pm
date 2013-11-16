
##
## Make.pm
##
## Utilities for creating Makefiles and getting
## information.
##

package Cactusinterfacing::Make;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Config qw($debug);
use Cactusinterfacing::Utils qw(util_readFile _warn);

# exports
our @EXPORT_OK = qw(createLibgeodecompMakefile getSources);

#
# This subroutine gatheres all source files
# from a cactus make.code.defn Makefile
# therefore it works recursivly.
#
# param:
#  - dir:         directory
#  - sources_ref: ref to sources array
#
# return:
#  - none, sources will be stored in sources ref
#
sub getSources
{
	my ($dir, $sources_ref) = @_;
	my ($subdirs, @lines, $str, $sources, @tmp);

	util_readFile("$dir/make.code.defn", \@lines);

	$str = join("", @lines);

	# get sources files in current directory
	if ($str =~ /\s*SRCS\s*=\s*([\w\s.\\]+)/) {
		$sources = $1;
		$sources =~ s/\\//g;
		$sources =~ s/#.*//g;
		@tmp = split(' ', $sources);
		$_ = $dir."/".$_ for (@tmp);
		push(@$sources_ref, @tmp);
	} else {
		_warn("No source files found in $dir/make.code.defn", __FILE__,
				__LINE__);
	}

	# get all subdirectories and append sources
	if ($str =~ /\s*SUBDIRS\s*=\s*([\-\w\s.\\]+)/) {
		$subdirs = $1;
		$subdirs =~ s/\\//g;
		$subdirs =~ s/#.*//g;
		getSources($dir."/".$_, $sources_ref) for (split(' ', $subdirs));
	}

	return;
}


#
# Creating a Makefile for compiling the final
# LibGeoDecomp application.
#
# param:
#  - config_ref: ref to config hash
#  - opt_ref   : ref to options hash
#  - out_ref   : ref to array where to store makefile lines
#
# return:
#  - none, makefile lines will be stored in out_ref
#
sub createLibgeodecompMakefile
{
	my ($config_ref, $opt_ref, $out_ref) = @_;
	my ($cxx, $cxxflags, $name);

	# init name and compiler, use mpicxx if mpi is used, g++ is default
	$name = "cactus_".$config_ref->{"config"};
	$cxx  = $opt_ref->{"mpi"} ? "mpicxx" : "g++";
	# ignore some unused variables/parameters warnings,
	# they're caused by some adjustments to the code
	$cxxflags  = "-pedantic -Wall -Wextra -Wno-unused-parameter ";
	$cxxflags .= "-Wno-unused-variable -Wno-unused-but-set-variable ";
	# ignore warnings about variadic macros since they're only standard in c++11
	$cxxflags .= "-Wno-variadic-macros -O3 -I./include";
	# build with debug code?
	$cxxflags .= " -DDEBUG" if ($debug);

	push(@$out_ref, "RM       = rm\n");
	push(@$out_ref, "CXX      = $cxx\n");
	push(@$out_ref, "LD       = $cxx\n");
	push(@$out_ref, "CXXFLAGS = $cxxflags\n");
	# link against libgeodecomp which requires an installation of that library
	# (to do that build libgeodecomp and run `sudo make install`)
	# some boost libraries are required, too
	push(@$out_ref, "LDFLAGS  = -lgeodecomp -lboost_date_time -lboost_regex\n");
	push(@$out_ref, "SOURCES  = \$(shell find . -name \"*.cpp\")\n");
	push(@$out_ref, "OBJECTS  = \$(SOURCES:%.cpp=%.o)\n");
	push(@$out_ref, "DEPS     = \$(OBJECTS:%.o=%.d)\n");
	push(@$out_ref, "PROG     = $name\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "all: \$(PROG)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\$(PROG): \$(OBJECTS)\n");
	push(@$out_ref, "\t\@echo \"LD\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(LD) -o \$@ \$^ \$(LDFLAGS)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "%.o: %.cpp\n");
	push(@$out_ref, "\t\@echo \"CXX\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(CXX) \$(CXXFLAGS) -c -o \$@ \$<\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "%.d: %.cpp\n");
	push(@$out_ref, "\t\@echo \"DEP\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(CXX) \$(CXXFLAGS) -MM -MF \$@ -MT \$*.o \$<\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "clean:\n");
	push(@$out_ref, "\t\@echo \"CLEAN\"\n");
	push(@$out_ref, "\t\@\$(RM) -f *.o *.d \$(PROG)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "ifneq (\$(MAKECMDGOALS),clean)\n");
	push(@$out_ref, "-include \$(DEPS)\n");
	push(@$out_ref, "endif\n");
	push(@$out_ref, "\n");
	push(@$out_ref, ".PHONY: all clean\n");
	push(@$out_ref, "\n");

	return;
}

1;
