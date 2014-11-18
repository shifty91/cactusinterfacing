
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
use Cactusinterfacing::Config qw(%cinf_config);
use Cactusinterfacing::Utils qw(util_readFile _warn);

# exports
our @EXPORT_OK = qw(createLibgeodecompMakefile getSources);

#
# This subroutine gatheres all source files
# from a cactus make.code.defn Makefile.
# Therefore it works recursivly.
#
# param:
#  - dir        : directory of cactus thorn
#  - sources_ref: ref to sources array
#
# return:
#  - none, sources will be stored in sources ref
#
sub getSources
{
	my ($dir, $sources_ref) = @_;
	my ($subdirs, @lines, $str, $sources, @token);

	util_readFile("$dir/make.code.defn", \@lines);

	$str = join("", @lines);

	# get sources files in current directory
	if ($str =~ /SRCS\s*=\s*([\w\s.\\]+)/) {
		$sources = $1;

		# strip '\' and comments
		$sources =~ s/\\//g;
		$sources =~ s/#.*//g;
		$sources =~ s/\s+$//g;
		@token = split /\s+/, $sources;

		# append path to source files
		@token = map { $dir . "/" . $_ } @token;

		# save
		push(@$sources_ref, @token);
	} else {
		_warn("No source files found in $dir/make.code.defn", __FILE__,
			  __LINE__);
	}

	# get all subdirectories and append sources
	if ($str =~ /SUBDIRS\s*=\s*([\-\w\s.\\]+)/) {
		$subdirs = $1;

		# strip '\', comments and newlines
		$subdirs =~ s/\\//g;
		$subdirs =~ s/#.*//g;
		$subdirs =~ s/\s+$//g;

		# go in all sub directories
		getSources($dir . "/" . $_, $sources_ref) for (split /\s+/, $subdirs);
	}

	return;
}


#
# Creating a Makefile for compiling the final LibGeoDecomp application.
# This uses `pkg-config' to determine compiler flags and libs. Make sure the
# LibGeoDecomp is installed on your system. This can be installed by
# `sudo make install`. Additionally -O3 is used for optimizations.
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
	my ($cxx, $cxxflags, $ldflags, $name);

	# init name and compiler, use mpicxx if mpi is used, g++ is default
	$name = "cactus_".$config_ref->{"config"};
	$cxx  = $opt_ref->{"mpi"} ? "mpicxx" : "g++";
	# ignore some unused variables/parameters warnings,
	# they're caused by some adjustments to the code
	$cxxflags  = "-pedantic -Wall -Wextra -Wno-unused-parameter ";
	$cxxflags .= "-Wno-unused-variable -Wno-unused-but-set-variable ";
	# ignore warnings about variadic macros since they're only standard in c++11
	$cxxflags .= "-Wno-variadic-macros -O3 -Iinclude";
	$cxxflags .= " `pkg-config --cflags libgeodecomp`";
	# build with debug code?
	$cxxflags .= " -DDEBUG" if ($cinf_config{debug});
	# additionally we need to link against boost_regex
	# the rest will be determined by pkg-config, make sure PKG_CONFIG_PATH is set
	$ldflags = "`pkg-config --libs libgeodecomp` -lboost_regex";

	push(@$out_ref, "RM       := rm\n");
	push(@$out_ref, "CXX      := $cxx\n");
	push(@$out_ref, "LD       := $cxx\n");
	push(@$out_ref, "CXXFLAGS := $cxxflags\n");
	push(@$out_ref, "LDFLAGS  := $ldflags\n");
	push(@$out_ref, "OBJDIR   := build\n");
	push(@$out_ref, "SOURCES  := \$(shell find * -name \"*.cpp\" -type f -print)\n");
	push(@$out_ref, "OBJECTS  := \$(SOURCES:%.cpp=\$(OBJDIR)/%.o)\n");
	push(@$out_ref, "DEPS     := \$(OBJECTS:\$(OBJDIR)/%.o=\$(OBJDIR)/%.d)\n");
	push(@$out_ref, "PROG     := $name\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "all: \$(PROG)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\$(PROG): \$(OBJECTS)\n");
	push(@$out_ref, "\t\@echo \"LD\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(LD) -o \$@ \$^ \$(LDFLAGS)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\$(OBJDIR)/%.o: %.cpp\n");
	push(@$out_ref, "\t\@if ! [ -d \$(OBJDIR) ] ; then mkdir -p \$(OBJDIR) ; fi\n");
	push(@$out_ref, "\t\@echo \"CXX\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(CXX) \$(CXXFLAGS) -c -o \$@ \$<\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "\$(OBJDIR)/%.d: %.cpp\n");
	push(@$out_ref, "\t\@if ! [ -d \$(OBJDIR) ] ; then mkdir -p \$(OBJDIR) ; fi\n");
	push(@$out_ref, "\t\@echo \"DEP\t\t\$@\"\n");
	push(@$out_ref, "\t\@\$(CXX) \$(CXXFLAGS) -MM -MF \$@ -MT \$(OBJDIR)/\$*.o \$<\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "clean:\n");
	push(@$out_ref, "\t\@echo \"CLEAN\"\n");
	push(@$out_ref, "\t\@\$(RM) -rf build \$(PROG)\n");
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
