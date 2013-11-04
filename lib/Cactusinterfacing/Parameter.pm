
##
## Parameter.pm
##
## Contains routines to get information from param.ccl.
##

package Cactusinterfacing::Parameter;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Config qw($tab);
use Cactusinterfacing::Utils qw(read_file util_arrayToHash util_indent);
use Cactusinterfacing::ParameterParser qw(parse_param_ccl);

# exports
our @EXPORT_OK = qw(getParameters generateParameterMacro buildParameterStrings);

#
# Parses param.ccl to get Parameters.
#
# param:
#  - thorndir: directory to thorn (abs. path)
#  - thorn   : name of thorn
#  - out_ref : ref to a hash where the results should be stored
#
# return:
#  - none, results will be stored in out_ref
#  - hash includes:
#    - name
#    - type
#    - default value
#    - description
#    - access
#
sub getParameters
{
	my ($thorndir, $thorn, $out_ref) = @_;
	my (@indata, @data, ,%paramdata, @groups);
	my (@global, @restricted, @private, @shares);

	@indata = read_file("$thorndir/param.ccl");
	@data   = parse_param_ccl($thorn, @indata);
	util_arrayToHash(\@data, \%paramdata);

	# get variables
	push(@global, split(' ', $paramdata{"\U$thorn global\E variables"}))
		if $paramdata{"\U$thorn global\E variables"};
	push(@restricted, split(' ', $paramdata{"\U$thorn restricted\E variables"}))
		if $paramdata{"\U$thorn restricted\E variables"};
	push(@private, split(' ', $paramdata{"\U$thorn private\E variables"}))
		if $paramdata{"\U$thorn private\E variables"};
	#push(@shares, split(' ', $paramdata{"\U$thorn shares implementations"}))
	#    if $paramdata{"\U$thorn shares\E implementations"};

	# get them into a useful format
	push(@groups, @global);
	push(@groups, @restricted);
	push(@groups, @private);
	#push(@groups, @shares);

	foreach my $var (@groups) {
		# finally get the important information
		$out_ref->{$var}{"type"}        = $paramdata{"\U$thorn $var\E type"};
		$out_ref->{$var}{"default"}     = $paramdata{"\U$thorn $var\E default"};
		$out_ref->{$var}{"realname"}    = $paramdata{"\U$thorn $var\E realname"};
		$out_ref->{$var}{"description"} = $paramdata{"\U$thorn $var\E description"};
		$out_ref->{$var}{"access"} = "global"     if ($var ~~ @global);
		$out_ref->{$var}{"access"} = "restricted" if ($var ~~ @restricted);
		$out_ref->{$var}{"access"} = "private"    if ($var ~~ @private);
		$out_ref->{$var}{"access"} = "shares"     if ($var ~~ @shares);

		# prepare type, default and description for further processing
		prepareValues($var, $out_ref);
	}

	return;
}

#
# Prepare type and default values.
#  - prepend CCTK_ to type
#  - add "" to default if type is keyword or string
#  - strip "" from description
#
# param:
#  - var    : parameter variable
#  - out_ref: ref to parameter data hash
#
# return:
#  - none, parameter hash will be modified
#
sub prepareValues
{
	my ($var, $out_ref) = @_;

	# prepend CCTK_ to type to avoid confusion with cctk_Types.h
	$out_ref->{$var}{"type"} = "CCTK_".$out_ref->{$var}{"type"}
		if ($out_ref->{$var}{"type"} !~ /^CCTK_/);

	# add "" to KEYWORD and STRING default value to make it compile with c++
	$out_ref->{$var}{"default"} = "\"".$out_ref->{$var}{"default"}."\""
		if ($out_ref->{$var}{"type"} =~ /^CCTK_(STRING|KEYWORD)$/);

	# strip "" from description
	$out_ref->{$var}{"description"} =~ s/\"//g;

	return;
}

#
# This functions builds parameter strings. This includes definition and
# initialization with default values. It can build these strings either for
# static members and normal members. To specify which version to build
# set the parameter static to one or zero.
#
# param:
#  - par_ref: ref to parameter data
#  - class  : name of class, which is not needed for non static build
#  - static : boolean which indicates if the definitions should be static or not
#  - val_ref: ref to value hash
#
# return:
#  - none, strings will be stored into value hash, keys are "param_def",
#    "param_init"
#
sub buildParameterStrings
{
	my ($par_ref, $class, $static, $val_ref) = @_;
	my (@def, @init);

	foreach my $name (keys %{$par_ref}) {
		my ($type, $default, $desc);

		# init
		$type    = $par_ref->{$name}{"type"};
		$default = $par_ref->{$name}{"default"};
		$desc    = $par_ref->{$name}{"description"};

		# add description first
		push(@def, "// $desc");

		if ($static) {
			# def : 'static type name;'
			# init: 'type classname::name = default;'
			push(@def,  "static $type $name;");
			push(@init, "$type $class"."::"."$name = $default;");
		} else {
			# def:  'type name;'
			# init: 'name = default;'
			push(@def,  "$type $name;");
			push(@init, "$name = $default;");
		}
	}

	# indent
	if ($static) {
		util_indent(\@def, 1);
	} else {
		util_indent(\@def , 1);
		util_indent(\@init, 2);
	}

	# final strings
	$val_ref->{"param_def"}  = join("\n", @def);
	$val_ref->{"param_init"} = join("\n", @init);

	return;
}

#
# Generates macro for parameter parser.
#
# param:
#  - par_ref: ref to parameter data hash
#  - thorn  : name of thorn
#  - impl   : implementation of thorn
#  - class  : name of class
#  - prefix : additional prefix for variable, may be ""
#  - out_ref: ref to hash where to store macros
#
# return:
#  - none, macros will be stored in out_ref
#
sub generateParameterMacro
{
	my ($par_ref, $thorn, $impl, $class, $prefix, $out_ref) = @_;
	my ($macro_name);

	# build name of macro
	$macro_name = $class;
	$macro_name =~ s/_//g;
	$macro_name = "_SETUP_\U$macro_name\E_PARAMETERS";

	push(@$out_ref, "#define $macro_name \\\n");
	push(@$out_ref, $tab."do { \\\n");

	foreach my $name (keys %{$par_ref}) {
		my ($implname, $vtype, $classname);

		# init
		$implname  = $impl."::".$par_ref->{$name}{"realname"};
		$vtype     = $par_ref->{$name}{"type"};
		$classname = $class."::".$prefix.$par_ref->{$name}{"realname"};

		# GET(impl::name, vtype, class::name);
		push(@$out_ref, $tab.$tab."GET($implname, $vtype, $classname); \\\n");
	}

	push(@$out_ref, $tab."} while (0)\n");

	return;
}

1;
