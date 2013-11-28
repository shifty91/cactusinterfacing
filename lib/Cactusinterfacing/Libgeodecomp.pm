
##
## Libgeodecomp.pm
##
## Utility functions for building LibGeoDecomp Code
## like macros etc..
##

package Cactusinterfacing::Libgeodecomp;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Config qw($debug);
use Cactusinterfacing::Utils qw(_warn);

# exports
our @EXPORT_OK = qw(generateSoAMacro getCoord getGFIndex getCoordZero
					getFixedCoordZero getGFIndexLast getGFIndexFirst);

#
# Generates SoA macro for LibGeoDecomp.
# they look like: LIBFLATARRAY_REGISTER_SOA(Cell, ((double)(c))((int)(a)))
#
# param:
#  - inf_ref: ref to interface data hash
#  - class  : name of class eg. "Cell"
#
# return:
#  - string of SoA macro
#
sub generateSoAMacro
{
	my ($inf_ref, $class) = @_;
	my ($macro, $vars);

	# init
	$macro .= "LIBFLATARRAY_REGISTER_SOA($class, ";
	$vars   = "";

	# get vars and type
	foreach my $group (keys %$inf_ref) {
		my ($gtype, $vtype, $timelevels, $i);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$vtype      = $inf_ref->{$group}{"vtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};

		# skip scalars and arrays
		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			for ($i = 0; $i < ($timelevels - 1); ++$i) {
				$vars .= "(($vtype)(var_$name" . (("_p") x $i) . "))";
			}
		}
	}

	$macro .= $vars;
	$macro .= ")";

	# if there are no vars, just return ""
	return $vars ne "" ? $macro : "";
}

#
# Generates a Zero-Coord for LibGeoDecomp for given
# dimension. They look like "Coord<3>(0,0,0)" for
# a dim of 3.
#
# param:
#  - dim: dimension
#
# return:
#  - coordinate string
#
sub getCoordZero
{
	my ($dim) = @_;
	my (@zeros, $i);

	for ($i = 0; $i < $dim; ++$i) {
		push(@zeros, "0");
	}

	return getCoord("coord", $dim, \@zeros);
}

#
# Generates a Zero-Fixed-Coord for LibGeoDecomp for given
# dimension. They look like "FixedCoord<0,0,0>()" for
# a dim of 3.
#
# param:
#  - dim: dimension
#
# return:
#  - coordinate string
#
sub getFixedCoordZero
{
	my ($dim) = @_;
	my (@zeros, $i);

	for ($i = 0; $i < $dim; ++$i) {
		push(@zeros, "0");
	}

	return getCoord("fixed", $dim, \@zeros);
}

#
# Generates a Coord for LibGeoDecomp. Either fixed or not.
#
# param:
#  - type   : fixed or coord
#  - dim    : dimension
#  - arr_ref: array ref, the coordinates are stored in that array
#
# return:
#  - coordinate string
#
sub getCoord
{
	my ($type, $dim, $arr_ref) = @_;
	my ($ret);

	# init
	$ret = "";

	# test dimension
	if ($dim <= 0) {
		_warn("Dimension ($dim) in getCoord() is not valid",
				__FILE__, __LINE__);
		goto out;
	}

	# test length of arr
	if (@$arr_ref != $dim) {
		_warn("Dimension does not fit to number of arguments in getCoord()",
				__FILE__, __LINE__);
		goto out;
	}

	# switch type
	if ($type =~ /^coord$/i) {
		$ret .= "Coord<$dim>(";
		$ret .= join(",", @$arr_ref);
		$ret .= ")";
	} elsif ($type =~ /^fixed$/i) {
		$ret .= "FixedCoord<";
		$ret .= join(",", @$arr_ref);
		$ret .= ">()";
	} else {
		_warn("No valid coordinate type given in getCoord()",
				__FILE__, __LINE__);
		goto out;
	}

 out:
	return $ret;
}

#
# Generates a CCTK_GFINDEX function call with zeros
# and one last index, e.g. CCTK_GFINDEX3D(cctkGH, 0, 0, i).
#
# param:
#  - dim : dimension
#  - last: last index
#
# return:
#  - CCTK_GFINDEX function call
#
sub getGFIndexLast
{
	my ($dim, $last) = @_;
	my (@indices, $i);

	for ($i = 0; $i < $dim; ++$i) {
		push(@indices, $i < ($dim-1) ? "0" : $last);
	}

	return getGFIndex($dim, \@indices);
}

#
# Generates a CCTK_GFINDEX function call with zeros
# and one first index, e.g. CCTK_GFINDEX3D(cctkGH, i, 0, 0).
#
# param:
#  - dim  : dimension
#  - first: first index
#
# return:
#  - CCTK_GFINDEX function call
#
sub getGFIndexFirst
{
	my ($dim, $first) = @_;
	my (@indices, $i);

	for ($i = 0; $i < $dim; ++$i) {
		push(@indices, $i > 0 ? "0" : $first);
	}

	return getGFIndex($dim, \@indices);
}

#
# Generates a CCTK_GFINDEX call for indexing Coords.
#
# param:
#  - dim    : dimension
#  - arr_ref: array ref, the indices are stored in that array
#
# return:
#  - CCTK_GFINDEX function call
#
sub getGFIndex
{
	my ($dim, $arr_ref) = @_;
	my ($ret);

	# init
	$ret = "";

	# test dimension
	if ($dim <= 0) {
		_warn("Dimension ($dim) in getCoord() is not valid",
				__FILE__, __LINE__);
		goto out;
	}

	# test length of arr
	if (@$arr_ref != $dim) {
		_warn("Dimension does not fit to number of arguments in getCoord()",
			  __FILE__, __LINE__);
		goto out;
	}

	$ret .= "CCTK_GFINDEX$dim"."D(cctkGH,";
	$ret .= join(",", @$arr_ref);
	$ret .= ")";

 out:
	return $ret;
}

1;
