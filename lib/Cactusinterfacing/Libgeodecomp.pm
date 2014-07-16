
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
use Cactusinterfacing::Config qw($debug $tab);
use Cactusinterfacing::Utils qw(_warn);

# exports
our @EXPORT_OK = qw(generateSoAMacro getCoord getGFIndex getCoordZero
					getFixedCoordZero getGFIndexLast getGFIndexFirst
					buildCctkSteerer getBOVWriter getVisItWriter);

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

#
# Builds the cctk steerer. It increments the iteration and the time
# every step.
#
# param:
#  - cell_class  : name of cell class
#  - static_class: name of static data class for the cell
#  - out_ref     : ref to array where to store steerer header file containing
#                  the class called "CctkSteerer"
#
# return:
#  - none, resulting class will be stored in out_ref
#
sub buildCctkSteerer
{
	my ($cell_class, $static_class, $out_ref) = @_;

	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include <libgeodecomp/io/steerer.h>\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "#include \"staticdata.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class CctkSteerer : public Steerer<$cell_class>\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	push(@$out_ref, $tab."CctkSteerer($static_class *staticData) :\n");
	push(@$out_ref, $tab.$tab."Steerer<$cell_class>(1),\n");
	push(@$out_ref, $tab.$tab."data(staticData)\n");
	push(@$out_ref, $tab."{}\n");
	push(@$out_ref, $tab."virtual void nextStep(\n");
	push(@$out_ref, $tab.$tab."GridType *grid,\n");
	push(@$out_ref, $tab.$tab."const Region<Topology::DIM>& validRegion,\n");
	push(@$out_ref, $tab.$tab."const CoordType& globalDimensions,\n");
	push(@$out_ref, $tab.$tab."unsigned step,\n");
	push(@$out_ref, $tab.$tab."SteererEvent event,\n");
	push(@$out_ref, $tab.$tab."std::size_t rank,\n");
	push(@$out_ref, $tab.$tab."bool lastCall,\n");
	push(@$out_ref, $tab.$tab."SteererFeedback *feedback)\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."if (event == STEERER_NEXT_STEP) {\n");
	push(@$out_ref, $tab.$tab.$tab."// increment current iteration and timestep\n");
	push(@$out_ref, $tab.$tab.$tab."data->cctkGH->incrCctkIteration();\n");
	push(@$out_ref, $tab.$tab.$tab."data->cctkGH->incrCctkTime();\n");
	push(@$out_ref, $tab.$tab."}\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "private:\n");
	push(@$out_ref, $tab."$static_class *data;\n");
	push(@$out_ref, "};\n");

	return;
}

#
# Generates BOV writer strings for LibGeoDecomp. Example:
# "new BOVWriter<Cell>(Selector<Cell>(&Cell:var, "var"), "var", 1)"
#
# param:
#  - inf_ref: ref to interface data hash
#  - class  : name of cell class
#  - type   : serial or normal (mpi related)
#  - out_ref: ref to array where to store bov writer strings
#  - freq   : output frequency
#
# return:
#  - none, resulting bov writer strings will be stored in out_ref
#
sub getBOVWriter
{
	my ($inf_ref, $class, $type, $out_ref, $freq) = @_;

	$freq = $freq ? $freq : "outputFrequency";
	$type = "serial" unless ($type =~ /^serial$/i || $type =~ /^normal$/i);

	foreach my $group (keys %{$inf_ref}) {
		my ($gtype);

		$gtype = $inf_ref->{$group}{"gtype"};

		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			my ($selector, $var, $writer);

			$var      = "&" . $class . "::" . "var_" . $name;
			$selector = "Selector<$class>($var, \"$name\")";
			$writer   = "new BOVWriter<$class>($selector, \"$name\", $freq)"
				if ($type =~ /^normal$/i);
			$writer   = "new SerialBOVWriter<$class>($selector, \"$name\", $freq)"
				if ($type =~ /^serial$/i);
			push(@$out_ref, $writer);
		}
	}

	return;
}

#
# Generates VisIt writer strings for LibGeoDecomp. Example:
# "VisItWriter<Cell> *visItWriter = new VisItWriter<Cell>("jacobi", 1);
#  visItWriter->addVariable(&Cell::temp, "temperature");"
#
# param:
#  - inf_ref: ref to interface data hash
#  - class  : name of cell class
#  - out_ref: ref to array where to store visit writer strings
#  - freq   : output frequency
#
# return:
#  - none, resulting visit writer strings will be stored in out_ref
#
sub getVisItWriter
{
	my ($inf_ref, $class, $out_ref, $freq) = @_;
	my ($pushed);

	$freq   = $freq ? $freq : "outputFrequency";
	$pushed = 0;

	# add a visit writer
	push(@$out_ref, "VisItWriter<$class> *visItWriter = new VisItWriter<$class>(\"visit\", $freq);\n");

	# add variables
	foreach my $group (keys %{$inf_ref}) {
		my ($gtype);

		$gtype = $inf_ref->{$group}{"gtype"};

		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			my ($var, $add);

			$var = "&" . $class . "::" . "var_" . $name;
			$add = "visItWriter->addVariable($var, \"$name\");\n";
			push(@$out_ref, $add);
			$pushed = 1;
		}
	}

	@$out_ref = () unless ($pushed);

	return;
}

1;
