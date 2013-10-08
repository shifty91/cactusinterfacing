#!/usr/bin/env perl

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
use Data::Dumper;
use Getopt::Long;
use Cactusinterfacing::CreateLibgeodecompApp qw(createLibgeodecompApp);
use Cactusinterfacing::Utils qw(util_readDir util_readFile util_choose
								util_input err vprint);
use Cactusinterfacing::Config qw($verbose);

# vars
my (@configs, $configdir);
my (@thorns);
my (%config);
# options
my ($help, $verbose, $config, $evol_thorn, $init_thorn, $cctk_home, $outputdir);

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
	print STDERR "usage: main.pl [options]\n";
	print STDERR "Options:\n";
	print STDERR "--help, -h\t\tShow this help\n";
	print STDERR "--verbose, -v\t\tVerbose output\n";
	print STDERR "--config\t\tCactus-Configuration to build for\n";
	print STDERR "--evolthorn, -e\t\tEvolution thorn\n";
	print STDERR "--initthorn, -i\t\tInit thorn\n";
	print STDERR "--cactushome\t\tDirectory to Cactus home\n";
	print STDERR "--outputdir, -o\t\tOutput directory\n";

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
	# the cactus home directory can be specified by an environment variable
	# called CCTK_HOME
	$cctk_home = $ENV{"CCTK_HOME"};

	GetOptions("help"         => \$help,
			   "verbose"      => \$verbose,
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
			push(@$thorns_ref, $1);
		} else {
			err("Syntax error in $configdir/ThornList", __FILE__, __LINE__);
		}
	}

	# consistency check
	err("No Thorns found. Check your ThornList.", __FILE__, __LINE__)
		if (@$thorns_ref == 0);

	return;
}

# and go :)
get_args();

# need help? no problem
print_usage() if ($help);

vprint("Transforming a Cactus Application into a Libgeodecomp App...");

# get cactus directory
$cctk_home = util_input("Specify the Cactus Home directory (CCTK_HOME)")
	unless (defined $cctk_home);

# test it
err("Your specified Cactus Home directory does not exist!", __FILE__, __LINE__)
	unless (-d $cctk_home);

# get configs
unless (defined $config) {
	# get configs in configdir
	util_readDir("$cctk_home/configs", \@configs);

	# choose one config
	if (@configs > 1) {
		$config = util_choose("Choose config to Libgeodecomp App for", \@configs);
	} elsif (@configs == 0) {
		err("You have to build a configuration first.\n".
			"Therefore run `gmake <configname>-config` in your Cactus directory!",
			__FILE__, __LINE__);
	} else {
		$config = $configs[0];
	}
}
$configdir = $cctk_home."/configs/".$config;

# get thorns
get_thorns(\@thorns, $configdir);

unless (defined $evol_thorn) {
	# choose evol thorn
	$evol_thorn = util_choose("Choose Evol Thorn", \@thorns);
}

unless (defined $init_thorn) {
	# choose init thorn
	$init_thorn = util_choose("Choose Init Thorn", \@thorns);
}

# get output directory
unless (defined $outputdir) {
	# using current directory as default
	$outputdir = ".";
}

# build config hash
# this hash includes all necassary information about
# paths and thorns
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
