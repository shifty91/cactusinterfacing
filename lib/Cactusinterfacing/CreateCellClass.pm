
##
## CreateCellClass.pm
##
## This module builds a cell class for LibGeoDecomp.
##

package Cactusinterfacing::CreateCellClass;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Config qw($tab);
use Cactusinterfacing::Utils qw(util_indent util_input err warning);
use Cactusinterfacing::Schedule qw(getEvolFunction);
use Cactusinterfacing::Parameter qw(getParameters generateParameterMacro
									buildParameterStrings);
use Cactusinterfacing::Interface qw(getInterfaceVars buildInterfaceStrings);
use Cactusinterfacing::Libgeodecomp qw(getCoordZero generateSoAMacro
									   getGFIndexFirst getFixedCoordZero);
use Cactusinterfacing::CreateSelector qw(createSelectors);
use Cactusinterfacing::CreateStaticDataClass qw(generateStaticDataClass);

# exports
our @EXPORT_OK = qw(createCellClass);

#
# Searches through GFs dimensions to get highest.
#
# param:
#  - inf_ref: ref to interface data
#
# return:
#  - dimension
#
sub getDimension
{
	my ($inf_ref) = @_;
	my ($dim);

	# init
	$dim = -1;

	# look for dimensions and find maximum
	foreach my $key (keys %$inf_ref) {
		next if ($inf_ref->{$key}{"gtype"} =~ /^SCALAR$/i);
		next if ($inf_ref->{$key}{"gtype"} =~ /^ARRAY$/i);

		if ($inf_ref->{$key}{"dim"} > $dim) {
			$dim = $inf_ref->{$key}{"dim"};
		}
	}

	# consistency checks
	if ($dim == -1) {
		$dim = util_input("Could not determine the dimension of Cactus Thorn. ".
						  "Please specify");
		err("That is not a valid dimension!", __FILE__, __LINE__)
			if ($dim !~ /\d/ || $dim <= 0);
	}
	if ($dim > 4) {
		err("The Dimension of $dim is too big for LibGeoDecomp!",
			__FILE__, __LINE__);
	}

	return $dim;
}

#
# This function builds macros for overriding cactus functions
# like CCTK_GFINDEX3D. These macros are specific for cell classes.
# For initializer classes these macro have a different purpose. This
# is why they will be regenerated in CreateInitializerClass.
# Moreover since the cell class consists only of a header file,
# these macros will be undefined at the end of the header file to
# avoid redefining compiler warnings.
#
# param:
#  - val_ref  : ref to values hash
#  - def_ref  : ref to array where defines will be stored
#  - undef_ref: ref to array where undefines will be stored
#
# return:
#  - none, macros and undefs will be stored in def_ref and undef_ref
#
sub buildSpecialMacros
{
	my ($val_ref, $def_ref, $undef_ref) = @_;
	my ($dim);

	# init
	$dim = $val_ref->{"dim"};

	# switch dimension
	if ($dim == 0) {
		push(@$def_ref  , "#define CCTK_GFINDEX0D(cctkGH) 0\n");
		push(@$def_ref  , "#define CCTK_VECTGFINDEX0D(cctkGH,n) (n)\n");
		push(@$undef_ref, "#undef CCTK_GFINDEX0D\n");
		push(@$undef_ref, "#undef CCTK_VECTGFINDEX0D\n");
	} elsif ($dim == 1) {
		push(@$def_ref  , "#define CCTK_GFINDEX1D(cctkGH,i) (i)\n");
		push(@$def_ref  , "#define CCTK_VECTGFINDEX1D(cctkGH,i,n) ((i) + ACCESSOR2::DIM_X * (n))\n");
		push(@$undef_ref, "#undef CCTK_GFINDEX1D\n");
		push(@$undef_ref, "#undef CCTK_VECTGFINDEX1D\n");
	} elsif ($dim == 2) {
		push(@$def_ref  , "#define CCTK_GFINDEX2D(cctkGH,i,j) ((i) + ACCESSOR2::DIM_X * (j))\n");
		push(@$def_ref  , "#define CCTK_VECTGFINDEX2D(cctkGH,i,j,n) ((i) + ACCESSOR2::DIM_X * ((j) + ACCESSOR2::DIM_Y * (n)))\n");
		push(@$undef_ref, "#undef CCTK_GFINDEX2D\n");
		push(@$undef_ref, "#undef CCTK_VECTGFINDEX2D\n");
	} elsif ($dim == 3) {
		push(@$def_ref  , "#define CCTK_GFINDEX3D(cctkGH,i,j,k) ((i) + ACCESSOR2::DIM_X * ((j) + ACCESSOR2::DIM_Y * (k)))\n");
		push(@$def_ref  , "#define CCTK_VECTGFINDEX3D(cctkGH,i,j,k,n) ((i) + ACCESSOR2::DIM_X * ((j) + ACCESSOR2::DIM_Y * ((k) + ACCESSOR2::DIM_Z * (n))))\n");
		push(@$undef_ref, "#undef CCTK_GFINDEX3D\n");
		push(@$undef_ref, "#undef CCTK_VECTGFINDEX3D\n");
	} elsif ($dim == 4) {
		push(@$def_ref  , "#define CCTK_GFINDEX4D(cctkGH,i,j,k,l) ((i) + ACCESSOR2::DIM_X * ((j) + ACCESSOR2::DIM_Y * ((k) + ACCESSOR2::DIM_Z * (l))))\n");
		# FIXME: how to do that with libgeodecomp?
		push(@$def_ref  , "#define CCTK_VECTGFINDEX4D(cctkGH,i,j,k,l,n) 0\n");
		push(@$undef_ref, "#undef CCTK_GFINDEX4D\n");
		push(@$undef_ref, "#undef CCTK_VECTGFINDEX4D\n");
	} else {
		# This should never happen, since dim is checked by getDimension().
		err("Dimension does not fit!", __FILE__, __LINE__);
	}

	return;
}

#
# Generates macros for LibGeoDecomps variables to have same code
# as cactus has. An Example:
#   #define phi     &hoodNew[FixedCoord<0, 0, 0>()].var_phi
#   #define phi_p   &hoodOld[FixedCoord<0, 0, 0>()].var_phi
#   #define phi_p_p &hoodOld[FixedCoord<0, 0, 0>()].var_phi_p
# Also generates undefs for these macros to avoid confusions with
# other sources.
#
# param:
#  - val_ref  : ref to hash where macros will be stored
#  - inf_ref  : ref to interface data hash
#  - def_ref  : ref to array where defines will be stored
#  - undef_ref: ref to array where undefines will be stored
#
# return:
#  - none, results will be stored in def_ref and undef_ref
#
sub buildInfVarMacros
{
	my ($val_ref, $inf_ref, $def_ref, $undef_ref) = @_;
	my ($dim);

	# init
	$dim = $val_ref->{"dim"};

	# go
	foreach my $group (keys %{$inf_ref}) {
		my ($gtype, $timelevels);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};

		# this is not necessary for arrays/scalars
		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			my ($i);

			# for the first timelevel hoodNew is used
			push(@$def_ref  , "#define $name (&hoodNew.var_$name())\n");
			push(@$undef_ref, "#undef $name\n");

			# for all other timelevels hoodOld
			for ($i = 1; $i < $timelevels; ++$i) {
				my ($past_name, $var_name, $fixed_coord);

				$past_name   = "$name" . ("_p" x $i);
				$var_name    = "var_" . $name . ("_p" x ($i - 1));
				$fixed_coord = getFixedCoordZero($dim);

				push(@$def_ref, "#define $past_name (&hoodOld[".
						 $fixed_coord . "].".
						 $var_name . "())\n");
				push(@$undef_ref, "#undef $past_name\n");
			}
		}
	}

	return;
}

#
# Builds cells static updateLineX function.
#
# param:
#  - val_ref: ref to value hash
#  - inf_ref: ref to interface data
#
# return:
#  - none, stores string of update function into value hash, key "update_line"
#
sub buildUpdateLineFunction
{
	my ($val_ref, $inf_ref) = @_;
	my (@outdata, @indata, $code_str);

	# adjust evol function for updateLine
	adjustUpdateLine($inf_ref, $val_ref, \@indata);
	# add rotating timelevels
	addRotateTimelevels($inf_ref, $val_ref, \@indata);
	# indent function
	util_indent(\@indata, 2);

	# build code string
	$code_str = join("\n", @indata);

	push(@outdata, $tab."template<typename ACCESSOR1, typename ACCESSOR2>\n");
	push(@outdata, $tab."static void updateLineX(ACCESSOR1 hoodOld, int *indexOld, int indexEnd, ACCESSOR2 hoodNew, int* /* indexNew */, unsigned /* nanoStep */)\n");
	push(@outdata, $tab."{\n");
	push(@outdata, "$code_str\n");
	push(@outdata, $tab."}\n");

	# build final string
	$val_ref->{"update_line"} = join("", @outdata);

	return;
}

#
# Add the rotating of the timelevels
# to the end of the updateLineX function.
#
# param:
#  - inf_ref : ref to interface data hash
#  - val_ref : ref to values hash
#  - evol_ref: ref to array of evol function
#
# return:
#  - none, modifies evol array
#
sub addRotateTimelevels
{
	my ($inf_ref, $val_ref, $evol_ref) = @_;
	my (@outdata, $i, $dim, $index, $pushed);

	# init
	$pushed = 0;
	$dim    = $val_ref->{"dim"};
	$index  = "_i";

	# start with a comment
	push(@outdata, "\n");
	push(@outdata, "// rotate timelevels");

	# start for loop
	push(@outdata, "for (int $index = 0; $index < (indexEnd - *indexOld); ++$index) {");

	foreach my $group (keys %{$inf_ref}) {
		my ($gtype, $timelevels);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};

		# skip scalars and arrays
		next if ($gtype =~ /^SCALAR$/i);
		next if ($gtype =~ /^ARRAY$/i);

		foreach my $name (@{$inf_ref->{$group}{"names"}}) {
			for ($i = $timelevels - 1; $i > 1; --$i) {
				my ($left, $right, $hood_new, $gfindex);

				$gfindex  = getGFIndexFirst($dim, $index);
				$hood_new = "(&hoodNew.var_"         . $name . ("_p" x ($i - 1). "())");
				$left     = "$hood_new" . "[$gfindex]";
				# using macro here, it's just shorter
				$right    = "$name" . ("_p" x ($i - 1)) . "[$gfindex]";

				# save
				push(@outdata, "$left = $right;\n");
				$pushed = 1;
			}
		}
	}

	# end foor loop
	push(@outdata, "}");

	# indent
	util_indent(\@outdata, 2);

	# only add if there variables, else there would be a useless comment
	push(@$evol_ref, @outdata) if ($pushed);

	return;
}

#
# This function adjusts the loop indices
# in the for loops. For updateLineX only one
# line has to be updated, but the cactus code updates
# a n-dimensional cube. This is why the loop indices have
# to be adjusted.
#
# params:
#  - evol_ref: ref of evol array
#  - inf_ref : ref of interface data hash
#  - out_ref : ref to array where to store adjusted function
#
# return:
#  - none, array is stored into out_ref
#
sub adjustUpdateLine
{
	my ($inf_ref, $val_ref, $out_ref) = @_;
	my ($codestr, $dim);
	my (@blocks, $lbcopy, $i);

	# init
	$codestr = join("\n", @{$val_ref->{"cctk_evol_arr"}});
	$dim     = $val_ref->{"dim"};

	# check for empty evol func
	goto out if (scalar @{$val_ref->{"cctk_evol_arr"}} <= 1);

	# find for loops and adjust indices in the following way:
	#  - for (int i = x; i < gridSize(); i++) => for (int i = 0; i < 1; ++i)
	#  - the last will be: for (int x = 0; x < indexEnd - *indexOld; ++x)
	@blocks = $codestr =~ /((?:for\s*\([\w\s()+\-*\/=<>;,\[\]]*\)\s*\{\s*){$dim})/g;
	unless (@blocks) {
		warning("Could not adjust loop indices.\n  -> You propably want to adjust the".
				" code on your own.", __FILE__, __LINE__);
		goto out;
	}

	for my $loopblock (@blocks) {
		$i = 0;
		$lbcopy = $loopblock;

		while ($loopblock =~ /(for\s*\(\s*(\w*)\s*(\w+)[\w\s=+\-*\/()<>,;\[\]]*\))/g) {
			my ($for, $type, $index, $replace);
			$for   = $1;
			$type  = $2;
			$index = $3;
			if ($i++ < ($dim -1)) {
				$replace = !$type ? "for ($index = 0; $index < 1; ++$index)" :
					"for ($type $index = 0; $index < 1; ++$index)";
			} else {
				$replace = !$type ? "for ($index = 0; $index < (indexEnd - *indexOld); ++$index)" :
					"for ($type $index = 0; $index < (indexEnd - *indexOld); ++$index)";
			}
			$lbcopy =~ s/\Q$for/$replace/;
		}

		# final replacement
		$codestr =~ s/\Q$loopblock/$lbcopy/;
	}

 out:
	push(@$out_ref, split("\n", $codestr));

	return;
}

#
# Build cell header.
#
# param:
#  - val_ref: ref to value hash
#  - out_ref: ref where to store cell header
#
# return:
#  - none, header will be stored into out_ref
#
sub buildCellHeader
{
	my ($val_ref, $out_ref) = @_;
	my ($ncellvars, $nprot, $npriv);

	# init
	$ncellvars = $val_ref->{"cell_params"} eq "" ? 0 : 1;
	$nprot     = $val_ref->{"inf_vars_prot"} eq "" ? 0 : 1;
	$npriv     = $val_ref->{"inf_vars_priv"} eq "" ? 0 : 1;

	# all template related code goes into the header
	push(@$out_ref, "#ifndef _CELL_H_\n");
	push(@$out_ref, "#define _CELL_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include \"cctk.h\"\n");
	push(@$out_ref, "#include \"cctk_$val_ref->{\"class_name\"}.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class $val_ref->{\"class_name\"}\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	# inherit from Line to use static updateLineX, which should make
	# things pretty much faster
	push(@$out_ref, $tab."class API :\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasFixedCoordsOnlyUpdate,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasSoA,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasUpdateLineX,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasStencil<Stencils::Moore<$val_ref->{\"dim\"}, 1> >,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasCubeTopology<$val_ref->{\"dim\"}>\n");
	push(@$out_ref, $tab."{};\n");
	push(@$out_ref, "\n");
	# check here if there are cell vars for avoiding build failures
	if (!$ncellvars) {
		push(@$out_ref, $tab."$val_ref->{\"class_name\"}() {}\n");
	} else {
		push(@$out_ref, $tab."$val_ref->{\"class_name\"}($val_ref->{\"cell_params\"}) :\n");
		push(@$out_ref, $tab.$tab."$val_ref->{\"cell_init_params\"}\n");
		push(@$out_ref, $tab."{}\n");
	}
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"update_line\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"inf_vars_pub\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."// cactus grid hierachy\n");
	push(@$out_ref, $tab."static CactusGrid *cctkGH;\n");
	push(@$out_ref, "$val_ref->{\"param_def\"}\n");
	if ($nprot) {
		push(@$out_ref, "\n");
		push(@$out_ref, "protected:\n");
		push(@$out_ref, "$val_ref->{\"inf_vars_prot\"}\n");
		push(@$out_ref, "\n");
	}
	if ($npriv) {
		push(@$out_ref, "\n");
		push(@$out_ref, "private:\n");
		push(@$out_ref, "$val_ref->{\"inf_vars_priv\"}\n");
		push(@$out_ref, "\n");
	}
	push(@$out_ref, "};\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"soa_macro\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include \"cctk_$val_ref->{\"class_name\"}_undef.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _CELL_H_ */\n");

	return;
}

#
# Build cell cpp file.
#
# param:
#  - val_ref: ref to value hash
#  - out_ref: ref where to store cell cpp
#
# return:
#  - none, cell cpp will be stored into out_ref
#
sub buildCellCpp
{
	my ($val_ref, $out_ref) = @_;

	# init parameters with default values
	# and set cctkGH pointer to NULL
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $val_ref->{"param_init"}."\n");
	push(@$out_ref, "CactusGrid* $val_ref->{\"class_name\"}::cctkGH = 0;\n");
	push(@$out_ref, "\n");

	return;
}

#
# Init value hash (see below) with default values
# to avoid perl warnings.
#
# param:
#  - val_ref: ref to value hash
#
# return:
#  - none, initial values will be stored in val_ref
#
sub initValueHash
{
	my ($val_ref) = @_;

	$val_ref->{"dim"}                  = 0;
	$val_ref->{"class_name"}           = "";
	$val_ref->{"param_def"}            = "";
	$val_ref->{"param_init"}           = "";
	$val_ref->{"cctk_evol_arr"}        = ();
	$val_ref->{"cctk_evol"}            = "";
	$val_ref->{"update_line"}          = "";
	$val_ref->{"inf_vars_pub"}         = "";
	$val_ref->{"inf_vars_prot"}        = "";
	$val_ref->{"inf_vars_priv"}        = "";
	$val_ref->{"cell_params"}          = "";
	$val_ref->{"cell_init_params"}     = "";
	$val_ref->{"soa_macro"}            = "";

	return;
}

#
# This function creates a cell class for LibGeoDecomp
# from a given thorn:
#  - parses interface.ccl to get variables
#  - parses parameters.ccl to get parameters
#  - parses schedule.ccl to get functions at specific (cactus-!)timesteps
#
# param:
#  - config_ref   : ref to config hash
#  - thorninfo_ref: ref to thorninfo hash
#  - out_ref      : ref to store cellh, cellcpp, param_macro, etc.
#
# return:
#  - hash of cellh, cellcpp, param_macro, dimension, selectors, inf_macros,
#    inf_macros_undef, special_macros, special_macros_undef, inf_data,
#    class_name
#
# documentation:
#  - all relevant and computed values will be stored in values hash:
#    - dim             : dimension of code (2D/3D/4D)
#    - class_name      : name of cell class e.g. "Cell"
#    - param_def       : parameter definitions
#    - param_init      : parameter initialization
#    - cctk_evol_arr   : array of evol_func
#    - cctk_evol       : string of evol function
#    - update_line     : string of update line function
#    - inf_vars_pub    : public interface variables
#    - inf_vars_prot   : protected interface variables
#    - inf_vars_priv   : private interface variables
#    - cell_params     : parameters for constructor
#    - cell_init_params: init constructor variables
#    - soa_macro       : string of LibGeoDecomp Struct of Array macro
#
sub createCellClass
{
	my ($config_ref, $thorninfo_ref, $out_ref) = @_;
	my ($thorndir, $thorn, $arrangement, $impl, $class);
	my (@cellh, @cellcpp, @selectors);
	my (@param_macro, @inf_macros, @inf_macros_undef, @special_macros, @special_macros_undef);
	my (%inf_data, %param_data, %values);

	# init
	initValueHash(\%values);
	$thorndir             = $config_ref->{"arr_dir"}."/".$config_ref->{"evol_thorn_arr"};
	$thorn                = $config_ref->{"evol_thorn"};
	$arrangement          = $config_ref->{"evol_arr"};
	$impl                 = $thorninfo_ref->{$config_ref->{"evol_thorn_arr"}}[0];
	$class                = $thorn."_Cell";
	$values{"class_name"} = $class;

	# parse param.ccl to get parameters
	getParameters($thorndir, $thorn, \%param_data);
	buildParameterStrings(\%param_data, $class, \%values);
	generateParameterMacro(\%param_data, $thorn, $impl, $class, \@param_macro);

	# parse schedule.ccl to get function at CCTK_Evol-Timestep
	getEvolFunction($thorndir, $thorn, \%values);

	# parse interface.ccl to get vars
	getInterfaceVars($config_ref->{"arr_dir"}, $config_ref->{"evol_thorn_arr"},
					 $thorninfo_ref, \%inf_data);
	buildInterfaceStrings(\%inf_data, \%values);

	# get dimension
	$values{"dim"} = getDimension(\%inf_data);

	# build macros for struct of array access
	buildInfVarMacros(\%values, \%inf_data, \@inf_macros, \@inf_macros_undef);
	$values{"soa_macro"} = generateSoAMacro(\%inf_data, $class);

	# special macros
	buildSpecialMacros(\%values, \@special_macros, \@special_macros_undef);

	# build updateLineX function
	buildUpdateLineFunction(\%values, \%inf_data);

	# build final files
	buildCellHeader(\%values, \@cellh);
	buildCellCpp(\%values, \@cellcpp);

	# build selectors for LibGeoDecomp writer
	createSelectors(\%inf_data, $class, \@selectors);

	# prepare hash
	$out_ref->{"cellh"}                 = \@cellh;
	$out_ref->{"cellcpp"}               = \@cellcpp;
	$out_ref->{"param_macro"}           = \@param_macro;
	$out_ref->{"selectors"}             = \@selectors;
	$out_ref->{"inf_macros"}            = \@inf_macros;
	$out_ref->{"inf_macros_undef"}      = \@inf_macros_undef;
	$out_ref->{"special_macros"}        = \@special_macros;
	$out_ref->{"special_macros_undef"}  = \@special_macros_undef;
	$out_ref->{"class_name"}            = $values{"class_name"};
	$out_ref->{"dim"}                   = $values{"dim"};
	$out_ref->{"inf_data"}              = \%inf_data;

	return;
}

1;
