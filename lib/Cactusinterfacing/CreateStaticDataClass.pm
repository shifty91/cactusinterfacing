##
## CreateStaticDataClass.pm
##
## This module has utilities for generating a class which contains all
## static variables (interface/parameter). This is needed for running
## the LibGeoDecomp application e.g. on GPUs.
##

package Cactusinterfacing::CreateStaticDataClass;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Config qw(%cinf_config);
use Cactusinterfacing::Utils qw(util_indent);
use Cactusinterfacing::Parameter qw(buildParameterStrings);

# export
our @EXPORT_OK = qw(createStaticDataClass);

# tab
my $tab = $cinf_config{"tab"};

#
# Builds interface strings for grid ARRAYs and SCALARs.
#
# param:
#  - inf_ref: ref to interface data hash
#  - val_ref: ref to values hash
#
# return:
#  - none, resulting strings will be stored in val_ref, key is "inf_def"
#
sub buildInterfaceStrings
{
	my ($inf_ref, $val_ref) = @_;
	my (@def);

	foreach my $group (keys %{$inf_ref}) {
		my ($i, $gtype, $vtype, $size, $timelevels, $desc);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$vtype      = $inf_ref->{$group}{"vtype"};
		$size       = $inf_ref->{$group}{"size"};
		$timelevels = $inf_ref->{$group}{"timelevels"};
		$desc       = $inf_ref->{$group}{"description"};

		# skip GFs
		next if ($gtype =~ /^GF$/i);

		# add description first
		push(@def, "// $desc");

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			if ($gtype =~ /^SCALAR$/i) {
				# scalars cannot have timelevels regarding to cactus userguide
				push(@def, "$vtype $name;");
				next;
			}

			for ($i = 0; $i < $timelevels; ++$i) {
				my ($past_name);

				# build past_name by appending _p
				$past_name = $name . ("_p" x $i);

				# type name[size];
				push(@def, "$vtype $past_name" . "[" . "$size" . "];");
			}
		}
	}

	# indent and save
	util_indent(\@def, 1);
	$val_ref->{"inf_def"} = join("\n", @def);

	return;
}

#
# This functions builds the header file which contains
# the complete class definition.
#
# param:
#  - val_ref: ref to values hash
#  - out_ref: ref to array where to store header file
#
# return:
#  - none, resulting header file will be stored in out_ref
#
sub buildHeader
{
	my ($val_ref, $out_ref) = @_;
	my ($class);

	# init
	$class = $val_ref->{"class_name"};

	# build header
	push(@$out_ref, "#ifndef _STATICDATA_H_\n");
	push(@$out_ref, "#define _STATICDATA_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include \"cctk_Types.h\"\n");
	push(@$out_ref, "#include \"cactusgrid.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class $class\n");
	push(@$out_ref, "{\n");
	# all variables become public members, since their values
	# need to be changeable
	push(@$out_ref, "public:\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."$class()\n");
	push(@$out_ref, $tab."{\n");
	# set the cctkGH pointer to NULL
	push(@$out_ref, $tab.$tab."cctkGH = 0;\n");
	# init all parameters to their default values
	push(@$out_ref, "$val_ref->{\"param_init\"}\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."// cactus grid hierarchy\n");
	push(@$out_ref, $tab."CactusGrid* cctkGH;\n");
	push(@$out_ref, "$val_ref->{\"param_def\"}\n");
	push(@$out_ref, "$val_ref->{\"inf_def\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "};\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _STATICDATA_H_ */\n");

	return;
}

#
# Generates a data class which contains parameters,
# grid scalars and grid arrays interface variables.
#
# param:
#  - inf_ref   : ref to interface data hash
#  - par_ref   : ref to parameter data hash
#  - class_name: the class name which to generate this class for
#  - out_ref   : ref to hash where header file and name of class will be stored
#
# return:
#  - none, resulting file will be stored in out_ref
#
sub createStaticDataClass
{
	my ($inf_ref, $par_ref, $class_name, $out_ref) = @_;
	my (@header, $class, %values);

	# init
	$class                = $class_name."_StaticData";
	$values{"class_name"} = $class;

	# build definitions
	buildParameterStrings($par_ref, "", 0, \%values);
	buildInterfaceStrings($inf_ref, \%values);

	# build header
	buildHeader(\%values, \@header);

	# save
	$out_ref->{"statich"}    = \@header;
	$out_ref->{"class_name"} = $class;

	return;
}

1;
