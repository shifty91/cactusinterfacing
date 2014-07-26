#!/usr/bin/env perl
#
# Cactusinterfacing
# main.pl -- gathers information and creates LibGeoDecomp application
# Copyright (C) 2013 Kurt Kanzenbach <kurt@kmk-computers.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

use strict;
use warnings;
use FindBin;
use lib "$FindBin::RealBin/lib";
use Getopt::Long;
use Cactusinterfacing::CreateLibgeodecompApp qw(createLibgeodecompApp);
use Cactusinterfacing::Utils qw(util_readDir util_readFile util_choose
								util_input _err vprint);

# vars
my (@configs, $configdir);
my (@thorns);
my (%config);
# options
my ($help, $config, $evol_thorn, $init_thorn, $cctk_home, $outputdir, $force_mpi);

#
# Prints usage and exits with success.
#
# param:
#  - none
#
# return:
#  - none
#
sub print_usage
{
	select(STDERR);
	local $| = 1;
	print "usage: main.pl [options]\n";
	print "Options:\n";
	print "\t--help, -h\t\tshow this help\n";
	print "\t--config\t\tCactus configuration to build for\n";
	print "\t--evolthorn, -e\t\tevolution thorn\n";
	print "\t--initthorn, -i\t\tinitialization thorn\n";
	print "\t--cactushome\t\tdirectory to Cactus Home\n";
	print "\t--outputdir, -o\t\toutput directory\n";
	print "\t--force_mpi, -f\t\tbuild with MPI even if Cactus is build without\n";

	exit 0;
}

#
# Gets arguments using GetOpt.
#
# param:
#  - none
#
# return:
#  - none
#
sub get_args
{
	# The Cactus home directory can be specified by an environment variable
	# called CCTK_HOME.
	$cctk_home = $ENV{"CCTK_HOME"};

	GetOptions("help"         => \$help,
			   "force_mpi"    => \$force_mpi,
			   "config=s"     => \$config,
			   "evolthorn=s"  => \$evol_thorn,
			   "initthorn=s"  => \$init_thorn,
			   "cactushome=s" => \$cctk_home,
			   "outputdir=s"  => \$outputdir) || print_usage();

	return;
}

#
# Reads the ThornList and strips some known thorns like CactusBase.
#
# param:
#  - thorns_ref: ref to array where to store thorns
#  - configdir : directory to Cactus/configs
#
# return:
#  - none, thorns will be stored in thorns_ref
#
sub get_thorns
{
	my ($thorns_ref, $configdir) = @_;
	my (@lines);

	util_readFile("$configdir/ThornList", \@lines);

	foreach my $line (@lines) {
		# skip empty lines
		next if ($line =~ /^\s*$/);
		# skip comments
		next if ($line =~ /^\s*#/);
		if ($line =~ /^\s*([\w\/]+).*/) {
			# strip some known io/driver/... thorns
			next if ($line =~ /^CactusBase/);
			next if ($line =~ /^CactusNumerical/);
			next if ($line =~ /^CactusConnect/);
			next if ($line =~ /^CactusIO/);
			next if ($line =~ /^CactusPUGH/);
			next if ($line =~ /^CactusPUGHIO/);
			next if ($line =~ /^ExternalLibraries/);
			next if ($line =~ /^CactusDoc/);
			next if ($line =~ /^Carpet/);
			next if ($line =~ /^LSUThorns/);
			push(@$thorns_ref, $1);
		} else {
			_err("Syntax error in $configdir/ThornList", __FILE__, __LINE__);
		}
	}

	# consistency check
	_err("No Thorns found. Check your ThornList.", __FILE__, __LINE__)
		if (@$thorns_ref == 0);

	return;
}

# and go :)
get_args();

# Need help? No problem
print_usage() if ($help);

vprint("Transforming a Cactus configuration into a LibGeoDecomp application.");

# get Cactus directory
$cctk_home = util_input("Specify the Cactus Home directory (CCTK_HOME)")
	unless ($cctk_home);

# test it
_err("Your specified Cactus Home directory does not exist!", __FILE__, __LINE__)
	unless (-d $cctk_home);

# get configs
unless ($config) {
	# get configs in configdir
	util_readDir("$cctk_home/configs", \@configs);

	# choose one config
	if (@configs > 1) {
		$config = util_choose("Choose a Cactus configuration to build LibGeoDecomp application for", \@configs);
	} elsif (@configs == 0) {
		_err("You have to build a configuration first.\n" .
			 "Therefore run `gmake <configname>-config` in your Cactus Home directory!",
			 __FILE__, __LINE__);
	} else {
		$config = $configs[0];
	}
}
$configdir = $cctk_home . "/configs/" . $config;

# get thorns
get_thorns(\@thorns, $configdir);

unless ($evol_thorn) {
	if (@thorns > 1) {
		# choose evol thorn
		$evol_thorn = util_choose("Choose evolution Thorn", \@thorns);
	} else {
		$evol_thorn = $thorns[0];
	}
}

unless ($init_thorn) {
	if (@thorns > 1) {
		# choose init thorn
		$init_thorn = util_choose("Choose intialization Thorn", \@thorns);
	} else {
		$init_thorn = $thorns[0];
	}
}

# using current directory as default, if not set
$outputdir = "." unless ($outputdir);

# build config hash
# this hash includes all necassary information about
# paths and thorns
$config{"force_mpi"}      = $force_mpi;
$config{"cctk_home"}      = $cctk_home;
$config{"config"}         = $config;
$config{"config_dir"}     = $configdir;
$config{"arr_dir"}        = $cctk_home."/arrangements";
$config{"outputdir"}      = $outputdir;
$config{"evol_thorn_arr"} = $evol_thorn;
$config{"init_thorn_arr"} = $init_thorn;
($config{"evol_arr"}, $config{"evol_thorn"})
	= $config{"evol_thorn_arr"} =~ /(\w+)\/(\w+)/;
($config{"init_arr"}, $config{"init_thorn"})
	= $config{"init_thorn_arr"} =~ /(\w+)\/(\w+)/;

# do it
createLibgeodecompApp(\%config);

vprint("Done. You may want to have a look at the source and do some adjustments.");

# done
exit 0;
