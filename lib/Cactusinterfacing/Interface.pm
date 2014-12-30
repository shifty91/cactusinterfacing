##
## Interface.pm
##
## Contains routines to get information from interface.ccl.
##

package Cactusinterfacing::Interface;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Config qw(%cinf_config);
use Cactusinterfacing::Utils qw(read_file util_indent _warn _err);
use Cactusinterfacing::InterfaceParser qw(parse_interface_ccl);
use Cactusinterfacing::ThornList qw(getInherits getFriends);

# exports
our @EXPORT_OK = qw(getInterfaceVars getAllInterfaceVars buildInterfaceStrings);

#
# Wrapper function for parsing a interface.ccl file
# using CactusSpecificationTool (InterfaceParser.pm).
#
# param:
#  - thorndir   : directory of thorn
#  - thorn      : name of thorn
#  - arrangement: name of arrangement
#  - out_ref    : ref to store interface data
#
# return:
#  - none, hash of all groups will be stored in out_ref, including
#    - variables names
#    - description
#    - vtype (CCTK_REAL, CCTK_INT, ...)
#    - grid type (GridScalar, GridFunction, GridArray)
#    - timelevels
#    - dimensions
#    - size, for arrays only
#    - access (public, protected, private)
#
sub getInterfaceVars
{
	my ($thorndir, $thorn, $arrangement, $out_ref) = @_;
	my (@groups, @publicgroups, @protectedgroups, @privategroups);
	my (%interface_data, @indata);

	# get the data
	@indata = read_file("$thorndir/interface.ccl");
	parse_interface_ccl($arrangement, $thorn, \@indata, \%interface_data);

	# get variables data from public, protected, private groups
	@publicgroups    = split(' ', $interface_data{"\U$thorn public groups\E"});
	@protectedgroups = split(' ', $interface_data{"\U$thorn protected groups\E"});
	@privategroups   = split(' ', $interface_data{"\U$thorn private groups\E"});
	push(@groups, @publicgroups);
	push(@groups, @protectedgroups);
	push(@groups, @privategroups);

	foreach my $group (@groups) {
		my ($timelevels, $dim, $vtype, @names, $gtype, $description, $size);

		# get variables data
		$timelevels  = $interface_data{"\U$thorn group $group timelevels\E"};
		$dim         = $interface_data{"\U$thorn group $group dim\E"};
		$vtype       = $interface_data{"\U$thorn group $group vtype\E"};
		@names       = split(' ', $interface_data{"\U$thorn group $group\E"});
		$gtype       = $interface_data{"\U$thorn group $group gtype\E"};
		$description = $interface_data{"\U$thorn group $group description\E"};
		$size        = $interface_data{"\U$thorn group $group size\E"};

		# save data
		$out_ref->{$group}{"names"}       = \@names;
		$out_ref->{$group}{"description"} = $description;
		$out_ref->{$group}{"vtype"}       = $vtype;
		$out_ref->{$group}{"gtype"}       = $gtype;
		$out_ref->{$group}{"dim"}         = $dim;
		$out_ref->{$group}{"size"}        = $size;
		$out_ref->{$group}{"timelevels"}  = $timelevels;
		$out_ref->{$group}{"access"} = "public"    if (grep { $group eq $_ } @publicgroups);
		$out_ref->{$group}{"access"} = "protected" if (grep { $group eq $_ } @protectedgroups);
		$out_ref->{$group}{"access"} = "private"   if (grep { $group eq $_ } @privategroups);

		# prepare desc, type, timelevels and ARRAY sizes for further processing
		prepareValues($group, $out_ref);
	}

	return;
}

#
# Same as above, except it uses inheritance and friends.
#
# param:
#  - thorndir_in   : directory of thorn
#  - thorn_in      : name of thorn
#  - arrangement_in: name of arrangement
#  - thorninfo_ref : ref to thorninfo hash
#  - out_ref       : ref to store interface data
#
# return:
#  - none, hash of all groups will be stored in out_ref, including
#    - variables names
#    - description
#    - vtype (CCTK_REAL, CCTK_INT, ...)
#    - grid type (GridScalar, GridFunction, GridArray)
#    - timelevels
#    - dimensions
#    - size, for arrays only
#    - access (public, protected, private)
#
sub getAllInterfaceVars
{
	my ($thorndir_in, $thorn_in, $arrangement_in, $thorninfo_ref, $out_ref) = @_;
	my (@inherits, $arr_thorn_in, $arr_dir);

	# init
	$arr_thorn_in = $arrangement_in . "/" . $thorn_in;
	$arr_dir = $thorndir_in;
	$arr_dir =~ s/\/\w+\s*$//;
	$arr_dir =~ s/\/\w+\s*$//;
	push(@inherits, $arr_thorn_in);

	# get inherits/friends
	getInherits($arr_thorn_in, $thorninfo_ref, \@inherits);
	getFriends($arr_thorn_in, $thorninfo_ref, \@inherits);

	foreach my $arr_thorn (@inherits) {
		my ($arrangement, $thorn) = $arr_thorn =~ m/^\s*(\w+)\/(\w+)\s*$/;
		getInterfaceVars($arr_dir . "/" . $arr_thorn, $thorn, $arrangement, $out_ref);
	}

	return;
}

#
# Prepare type, defaults and timelevels values.
#  - prepend CCTK_ to type
#  - add default desc if no is given
#  - set GFs timelevel at minimum to two
#  - testing and computing size of ARRAYs
#
# param:
#  - group  : name of variable group
#  - out_ref: ref to interface data hash
#
# return:
#  - none, interface hash will be modified
#
sub prepareValues
{
	my ($group, $out_ref) = @_;

	# description is optional, so set a default if no is given
	$out_ref->{$group}{"description"} = "no description given"
		if (!defined $out_ref->{$group}{"description"});

	# prepend CCTK_ to vtype if its not there to avoid confusions with
	# cctk_Types.h
	$out_ref->{$group}{"vtype"} = "CCTK_".$out_ref->{$group}{"vtype"}
		if ($out_ref->{$group}{"vtype"} !~ /^CCTK_/);

	# adjusting timelevels for GFs to a minimum of two otherwise no
	# variable for this gf will be created, since if a cell member
	# is always available in two timelevels
	$out_ref->{$group}{"timelevels"} = 2
		if ($out_ref->{$group}{"gtype"} =~ /^GF$/i &&
			$out_ref->{$group}{"timelevels"} < 2);

	# testing size for arrays
	if ($out_ref->{$group}{"gtype"} =~ /^ARRAY$/i) {
		my ($size, $dim, $nsize, @token);

		# init
		$size  = $out_ref->{$group}{"size"};
		$dim   = $out_ref->{$group}{"dim"};
		$nsize = 1;

		# size given?
		_err("Size of ARRAYs must be defined.")
			unless ($size);

		# size is comma seperated list of grid points in each direction
		@token = split(',', $size);
		# check for right format
		_err("Invalid value in ARRAY size: \"$size\".")
			unless (@token == $dim);
		# just calculate the size
		foreach my $number (@token) {
			# check for numbers
			_err("ARRAY Size has to be numeric value.")
				unless ($number =~ /\d+/);
			$nsize *= $number;
		}
		# save back
		$out_ref->{$group}{"size"} = $nsize;
	}

	return;
}

#
# Builds interface variables strings, including:
#  - grid functions as member variables in appropriate timelevels
#  - constructor definitions
# Note: Grid arrays and grid scalars become static cell members by
#       CreateStaticDataClass.pm.
#
# param:
#  - inf_ref: ref to interface data
#  - val_ref: ref to value hash
#
# return:
#  - none, strings stored into value hash, keys: "cell_params",
#    "cell_init_params", "inf_vars"
#
sub buildInterfaceStrings
{
	my ($inf_ref, $val_ref) = @_;
	my (@c_vars, @c_init_vars, @inf_vars);
	my ($gfs_cnt);

	# init
	$gfs_cnt = 0;

	# build interface variables strings
	foreach my $group (keys %{$inf_ref}) {
		my ($i, $gtype, $vtype, $timelevels, $desc, $size);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$vtype      = $inf_ref->{$group}{"vtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};
		$desc       = $inf_ref->{$group}{"description"};
		$size       = $inf_ref->{$group}{"size"};

		# comment which contains the groups description
		push(@inf_vars, "// $desc");

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			# arrays scalars become static cell members
			next if ($gtype =~ /ARRAY/i);
			next if ($gtype =~ /SCALAR/i);

			# grid functions become normal cell members
			for ($i = 0; $i < ($timelevels - 1); ++$i) {
				my ($past_name);

				# build past_name with appending _p and prepend var_
				$past_name = "var_" . $name . ("_p" x $i);

				push(@inf_vars,    "$vtype $past_name;");
				# for cell member and constructor declaration
				push(@c_vars,      "const $vtype& _$past_name = $cinf_config{\"scalar\"}");
				push(@c_init_vars, "$past_name(_$past_name)");
				++$gfs_cnt;
			}
		}
	}

	# perform checks whether there are member variables
	_warn("No member variables found!") unless ($gfs_cnt);

	# indent
	util_indent(\@inf_vars,  1);

	# final variable declarations/initializiations
	$val_ref->{"inf_vars"}         = join("\n", @inf_vars);
	$val_ref->{"cell_params"}      = join(", ", @c_vars);
	$val_ref->{"cell_init_params"} = join(", ", @c_init_vars);

	return;
}

1;
