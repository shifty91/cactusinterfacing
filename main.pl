#!/usr/bin/env perl
#
# Cactusinterfacing
# main.pl -- gathers information and creates LibGeoDecomp application
# Copyright (C) 2013, 2014 Kurt Kanzenbach <kurt@kmk-computers.de>
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
								util_input _err vprint util_chooseMulti);

# vars
my (@configs, $configdir, @thorns, %config);
# options
my (@evol_thorns, @init_thorns, $input_evol_thorn, $input_init_thorn);
my ($help, $config, $cctk_home, $outputdir, $force_mpi);

#
# Prints usage on stderr and exits with success.
#
# param:
#  - none
#
# return:
#  - none
#
sub printUsage
{
	select(STDERR);
	local $| = 1;

	print <<'EOF';
usage: main.pl [options]

options:
    --help,       -h        show this help
    --config,     -c        the Cactus configuration to use
    --evolthorns, -e        selects evolution thorns, multiple should be comma seperated
    --initthorns, -i        selects initialization thorns, multiple should be comma seperated
    --cactushome, -d        selects the the path to Cactus directory
    --outputdir,  -o        selects the output directory, where generated code will be stored
    --force_mpi,  -f        selects whether the code will be generated with MPI even if the
                            Cactus configuration is built without
EOF

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
sub getArgs
{
	# The Cactus home directory can be specified by an environment variable
	# called CCTK_HOME.
	$cctk_home = $ENV{"CCTK_HOME"};

	GetOptions("help"           => \$help,
			   "force_mpi"      => \$force_mpi,
			   "c|config=s"     => \$config,
			   "evolthorn=s"    => \$input_evol_thorn,
			   "initthorn=s"    => \$input_init_thorn,
			   "d|cactushome=s" => \$cctk_home,
			   "outputdir=s"    => \$outputdir) || printUsage();

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
sub getThorns
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

#
# Parses the input strings for evol/init thorns.
#
# param:
#  - evol_ref: ref to evol thorns array
#  - init_ref: ref to init thorns array
#
# return:
#  - none, results will be stored in (evol/init)_ref
#
sub parseThorns
{
	my ($evol_ref, $init_ref) = @_;

	goto init unless ($input_evol_thorn);
	foreach my $evol_thorn (split ',', $input_evol_thorn) {
		$evol_thorn =~ s/^\s*//g;
		$evol_thorn =~ s/\s*$//g;
		push(@$evol_ref, $evol_thorn);
	}

 init:
	return unless ($input_init_thorn);
	foreach my $init_thorn (split ',', $input_init_thorn) {
		$init_thorn =~ s/^\s*//g;
		$init_thorn =~ s/\s*$//g;
		push(@$init_ref, $init_thorn);
	}

	return;
}

#
# This function checks whether the given thorns are valid
# by comparing them to the ThornList and looking for weird
# input.
#
# param:
#  - thorn_ref: ref to all found thorns (except for stripped ones)
#  - evol_ref : ref to evol thorns array
#  - init_ref : ref to init thorns array
#
# return:
#  - none, exits if something is wrong
#
sub checkThorns
{
	my ($thorn_ref, $evol_ref, $init_ref) = @_;
	my (@merged);

	push(@merged, @{$evol_ref});
	push(@merged, @{$init_ref});

	foreach my $input (@merged) {
		_err("Given thorn \"\Q$input\E\" is not in ThornList.", __FILE__, __LINE__)
			unless (grep { $input eq $_ } @{$thorn_ref});
		_err("Given thorn \"\Q$input\E\" contains not valid characters.", __FILE__,
			 __LINE__) if ($input =~ /[ \\*+--=\*\.&\^%\$@!#]+/);
	}

	return;
}

#
# This functions builds the thorn hash for createLibGeoDecompApp.
# Each hash consists of all thorns including name of thorn, arragements
# and complete arragement/thorn.
#
# param:
#  - config_ref: ref to config hash
#  - evol_ref  : ref to evol thorns array
#  - init_ref  : ref to init thorns array
#
# return:
#  - none, hashes will be stored in config_ref, keys "evol_thorns" and "init_thorns"
#
sub buildThornHash
{
	my ($config_ref, $evol_ref, $init_ref) = @_;
	my (%evol_thorns, %init_thorns);

	foreach my $evol_thorn (@{$evol_ref}) {
		my ($arr, $thorn) = $evol_thorn =~ /^(\w+)\/(\w+)$/;
		$evol_thorns{$thorn}{"thorn"}     = $thorn;
		$evol_thorns{$thorn}{"arr"}       = $arr;
		$evol_thorns{$thorn}{"thorn_arr"} = $evol_thorn;
	}

	foreach my $init_thorn (@{$init_ref}) {
		my ($arr, $thorn) = $init_thorn =~ /^(\w+)\/(\w+)$/;
		$init_thorns{$thorn}{"thorn"}     = $thorn;
		$init_thorns{$thorn}{"arr"}       = $arr;
		$init_thorns{$thorn}{"thorn_arr"} = $init_thorn;
	}

	$config_ref->{"evol_thorns"} = \%evol_thorns;
	$config_ref->{"init_thorns"} = \%init_thorns;

	return;
}

# and go :)
getArgs();

# Need help? No problem
printUsage() if ($help);

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
getThorns(\@thorns, $configdir);

# parse user input for evol/init thorns
parseThorns(\@evol_thorns, \@init_thorns);

# no evol thorns given
unless (@evol_thorns) {
	if (@thorns > 1) {
		@evol_thorns = util_chooseMulti("Choose evolution Thorn(s)", \@thorns);
	} else {
		@evol_thorns = ( $thorns[0] );
	}
}

# no init thorns given
unless (@init_thorns) {
	if (@thorns > 1) {
		@init_thorns = util_chooseMulti("Choose intialization Thorn(s)", \@thorns);
	} else {
		@init_thorns = ( $thorns[0] );
	}
}

# check thorns
checkThorns(\@thorns, \@evol_thorns, \@init_thorns);

# using current directory as default, if not set
$outputdir = "." unless ($outputdir);

# build config hash
# this hash includes all necassary information about
# paths and thorns
$config{"force_mpi"}  = $force_mpi;
$config{"cctk_home"}  = $cctk_home;
$config{"config"}     = $config;
$config{"config_dir"} = $configdir;
$config{"arr_dir"}    = $cctk_home . "/arrangements";
$config{"outputdir"}  = $outputdir;
buildThornHash(\%config, \@evol_thorns, \@init_thorns);

# do it
createLibgeodecompApp(\%config);

vprint("Done. You may want to have a look at the source and do some adjustments.");

# done
exit 0;
