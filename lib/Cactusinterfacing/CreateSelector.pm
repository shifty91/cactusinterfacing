
##
## CreateSelector.pm
##
## Contains routines to create selector classes for LibGeoDecomp Writers.
## Currently ASCII and BOV writer selectors are supported.
##

package Cactusinterfacing::CreateSelector;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Config qw($tab);

# export
our @EXPORT_OK = qw(createSelectors);

#
# Builds a ASCII Selector class for one variable of grid functions.
#
# param:
#  - name    : name of the variable
#  - type    : type of variable
#  - cellname: name of cell class
#  - out_ref : ref to asciiwriter hash
#
# return:
#  - none, resulting class and the name of the variable will be stored in out_ref
#    key is the name of the class (e.g. like AsciiPHISelector)
#
sub buildAsciiSelector
{
	my ($name, $type, $cellname, $out_ref) = @_;
	my ($class, @outdata);

	# init
	$class = "Ascii\U$name\ESelector";

	# build ascii selector class
	push(@outdata, "class $class\n");
	push(@outdata, "{\n");
	push(@outdata, "public:\n");
	push(@outdata, $tab."$type operator()(const $cellname& cell) const\n");
	push(@outdata, $tab."{\n");
	push(@outdata, $tab.$tab."return cell.var_$name;\n");
	push(@outdata, $tab."}\n");
	push(@outdata, "};\n");

	# save back data and name of the variable
	$out_ref->{$class}{"data"}     = \@outdata;
	$out_ref->{$class}{"var_name"} = $name;

	return;
}

#
# Builds a BOV Selector class for one variable the grid functions.
#
# param:
#  - name    : name of the variable
#  - type    : type of variable
#  - cellname: name of cell class
#  - out_ref : ref to bovwriter hash
#
# return:
#  - none, resulting class and the name of the variable  will be stored in out_ref,
#    key is the name of class (e.g. like BovPHISelector)
#
sub buildBovSelector
{
	my ($name, $type, $cellname, $out_ref) = @_;
	my ($datatype, $class, @outdata);

	# init
	$class    = "Bov\U$name\ESelector";
	if ($type eq "CCTK_REAL") {
		$datatype = "DOUBLE";
	} elsif ($type eq "CCTK_INT") {
		$datatype = "INT";
	} elsif ($type = "CCTK_BYTE") {
		$datatype = "BYTE";
	} elsif ($datatype = "CCTK_COMPLEX") {
		$datatype = "DOUBLE";
	}

	push(@outdata, "class $class\n");
	push(@outdata, "{\n");
	push(@outdata, "public:\n");
	push(@outdata, $tab."typedef $type VariableType;\n");
	push(@outdata, $tab."static std::string varName()\n");
	push(@outdata, $tab."{\n");
	push(@outdata, $tab.$tab."return \"$name\";\n");
	push(@outdata, $tab."}\n");
	push(@outdata, $tab."static std::string dataFormat()\n");
	push(@outdata, $tab."{\n");
	push(@outdata, $tab.$tab."return \"$datatype\";\n");
	push(@outdata, $tab."}\n");
	push(@outdata, $tab."static int dataComponents()\n");
	push(@outdata, $tab."{\n");
	push(@outdata, $tab.$tab."return 1;\n");
	push(@outdata, $tab."}\n");
	push(@outdata, $tab."void operator()(const $cellname& cell, $type *storage) const\n");
	push(@outdata, $tab."{\n");
	push(@outdata, $tab.$tab."*storage = cell.var_$name;\n");
	push(@outdata, $tab."}\n");
	push(@outdata, "};\n");

	# save back, data and name of group
	$out_ref->{$class}{"data"}     = \@outdata;
	$out_ref->{$class}{"var_name"} = $name;

	return;
}

#
# Builds selectors.h header file which contains all selector classes
# for LibGeoDecomp's writers.
#
# param:
#  - bov_ref  : ref to bovwriters hash
#  - ascii_ref: ref to asciiwriters hash
#  - out_ref  : ref to array where to store the lines of selectors.h
#
# return:
#  - none, selectors.h will be stored in out_ref
#
sub buildHeader
{
	my ($bov_ref, $ascii_ref, $out_ref) = @_;
	my ($name);

	# init
	$name = "selectors";

	# build selectors.h containing all created selector classes for writers
	push(@$out_ref, "#ifndef _\U$name\E_H_\n");
	push(@$out_ref, "#define _\U$name\E_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <string>\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "#include \"cctk_Types.h\"\n");
	push(@$out_ref, "\n");

	for my $asciiwriter (keys %{$ascii_ref}) {
		push(@$out_ref, $_) for (@{$ascii_ref->{$asciiwriter}{"data"}});
		push(@$out_ref, "\n");
	}

	for my $bovwriter (keys %{$bov_ref}) {
		push(@$out_ref, $_) for (@{$bov_ref->{$bovwriter}{"data"}});
		push(@$out_ref, "\n");
	}

	push(@$out_ref, "#endif /* _\U$name\E_H_ */\n");

	return;
}

#
# This function generates a header file which
# contains ascii/bov selectors for all grid functions.
#
# param:
#  - inf_ref : ref to interface data hash
#  - cellname: name of cell class
#  - out_ref : ref to array where the selector file will be stored
#
# return:
#  - none, resulting selector file will be stored in out_ref
#
sub createSelectors
{
	my ($inf_ref, $cellname, $out_ref) = @_;
	my (@header, %bovwriter, %asciiwriter);

	# build selectors
	for my $group (keys %{$inf_ref}) {
		my (@names, $gtype, $vtype);

		# init
		@names = @{$inf_ref->{$group}{"names"}};
		$gtype = $inf_ref->{$group}{"gtype"};
		$vtype = $inf_ref->{$group}{"vtype"};

		# create selectors only for gridfunctions
		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		# just build selectors for the first variables and not for all timelevels
		foreach my $name (@names) {
			buildAsciiSelector($name, $vtype, $cellname, \%asciiwriter);
			buildBovSelector($name, $vtype, $cellname, \%bovwriter);
		}
	}

	# build header
	buildHeader(\%bovwriter, \%asciiwriter, \@header);

	# prepare hash
	$out_ref->{"selectorh"}   = \@header;
	$out_ref->{"bovwriter"}   = \%bovwriter;
	$out_ref->{"asciiwriter"} = \%asciiwriter;

	return;
}

1;
