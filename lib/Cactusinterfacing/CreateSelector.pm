
##
## CreateSelector.pm
##
## Contains routines to create selector classes
## for LibGeoDecomp Writers.
##

package Cactusinterfacing::CreateSelector;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Config qw($tab);

# export
our @EXPORT_OK = qw(createSelectors);

#
# Add a Ascii Selector class for one variable of
# grid functions.
#
# param:
#  - names   : name of the variable
#  - type    : type of variable
#  - cellname: name of cell class
#  - out_ref : ref to array where ascii class will be stored
#
# return:
#  - none, resulting class will be stored in out_ref
#
sub addAsciiSelector
{
	my ($name, $type, $cellname, $out_ref) = @_;

	push(@$out_ref, "class Ascii\U$name\ESelector\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	push(@$out_ref, $tab."$type operator()(const $cellname& cell) const\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."return cell.var_$name;\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "};\n");

	return;
}

#
# Add a Bov Selector class for one group of
# grid functions.
#
# param:
#  - names_ref: ref to names array
#  - type     : type of group
#  - cellname : name of cell class
#  - out_ref  : ref to array where bov class will be stored
#
# return:
#  - none, resulting class will be stored in out_ref
#
sub addBovSelector
{
	my ($names_ref, $type, $cellname, $out_ref) = @_;
	my ($namestr, $namescnt, $i, $datatype);

	# init
	$namestr  = join("", @$names_ref);
	$namescnt = scalar @$names_ref;
	if ($type eq "CCTK_REAL") {
		$datatype = "DOUBLE";
	} elsif ($type eq "CCTK_INT") {
		$datatype = "INT";
	} elsif ($type = "CCTK_BYTE") {
		$datatype = "BYTE";
	} elsif ($datatype = "CCTK_COMPLEX") {
		$datatype = "DOUBLE";
	}

	push(@$out_ref, "class Bov\U$namestr\ESelector\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	push(@$out_ref, $tab."typedef $type VariableType;\n");
	push(@$out_ref, $tab."static std::string varName()\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."return \"$namestr\";\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, $tab."static std::string dataFormat()\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."return \"$datatype\";\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, $tab."static int dataComponents()\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."return $namescnt;\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, $tab."void operator()(const $cellname& cell, $type *storage) const\n");
	push(@$out_ref, $tab."{\n");
	for ($i = 0; $i < $namescnt; $i++) {
		my ($name);
		$name = "var_".$names_ref->[$i];
		push(@$out_ref, $tab.$tab."storage[$i] = cell.$name;\n");
	}
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "};\n");

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
	my ($class);

	# init
	$class = "selectors";

	push(@$out_ref, "#ifndef _\U$class\E_H_\n");
	push(@$out_ref, "#define _\U$class\E_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <cstring>\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "#include \"cctk_Types.h\"\n");
	push(@$out_ref, "\n");

	for my $group (keys %$inf_ref) {
		my (@names, $gtype, $vtype);
		@names = @{$inf_ref->{$group}{"names"}};
		$gtype = $inf_ref->{$group}{"gtype"};
		$vtype = $inf_ref->{$group}{"vtype"};
		# create selectors only for gridfunctions
		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@names) {
			addAsciiSelector($name, $vtype, $cellname, $out_ref);
			push(@$out_ref, "\n");
		}
		addBovSelector(\@names, $vtype, $cellname, $out_ref);
		push(@$out_ref, "\n");
	}

	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _\U$class\E_H_ */\n");

	return;
}

1;
