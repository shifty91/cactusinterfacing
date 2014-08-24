
##
## CreateCellClass.pm
##
## This module builds a cell class for LibGeoDecomp.
##

package Cactusinterfacing::CreateCellClass;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Config qw($tab $ghostzone_width $topology);
use Cactusinterfacing::Utils qw(util_indent util_input _err _warn);
use Cactusinterfacing::Schedule qw(getEvolFunctions);
use Cactusinterfacing::Parameter qw(getParameters generateParameterMacro
									buildParameterStrings);
use Cactusinterfacing::Interface qw(getInterfaceVars buildInterfaceStrings);
use Cactusinterfacing::Libgeodecomp qw(getCoordZero generateSoAMacro
									   getGFIndexFirst getFixedCoordZero);
use Cactusinterfacing::CreateStaticDataClass qw(createStaticDataClass);

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
	foreach my $key (keys %{$inf_ref}) {
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
		_err("This is not a valid dimension!", __FILE__, __LINE__)
			if ($dim !~ /\d/ || $dim <= 0);
	}
	if ($dim > 4) {
		_err("The Dimension of $dim is too big for LibGeoDecomp!",
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
# This includes:
#  - CCTK_GFINDEX, CCTK_VECTGFINDEX
#  - macros for Cactus grid hierarchy variables
#  - macros for interface variables
#  - macros for parameters
#
# param:
#  - val_ref  : ref to values hash
#  - inf_ref  : ref to interface data hash
#  - par_ref  : ref to parameter data hash
#  - def_ref  : ref to array where defines will be stored
#  - undef_ref: ref to array where undefines will be stored
#
# return:
#  - none, macros and undefs will be stored in def_ref and undef_ref
#
sub buildSpecialMacros
{
	my ($val_ref, $inf_ref, $par_ref, $def_ref, $undef_ref) = @_;
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
		_err("Dimension does not fit!", __FILE__, __LINE__);
	}

	push(@$def_ref, "\n");

	# add variables for cGH
	# this provides access for the thorn code to all cctk grid hierachie variables
	push(@$def_ref, "#define cctk_dim staticData.cctkGH->cctk_dim()\n");
	push(@$undef_ref, "#undef cctk_dim\n");
	push(@$def_ref, "#define cctk_gsh (staticData.cctkGH->cctk_gsh())\n");
	push(@$undef_ref, "#undef cctk_gsh\n");
	push(@$def_ref, "#define cctk_lsh (staticData.cctkGH->cctk_lsh())\n");
	push(@$undef_ref, "#undef cctk_lsh\n");
	push(@$def_ref, "#define cctk_lbnd (staticData.cctkGH->cctk_lbnd())\n");
	push(@$undef_ref, "#undef cctk_lbnd\n");
	push(@$def_ref, "#define cctk_ubnd (staticData.cctkGH->cctk_ubnd())\n");
	push(@$undef_ref, "#undef cctk_ubnd\n");
	push(@$def_ref, "#define cctk_bbox (staticData.cctkGH->cctk_bbox())\n");
	push(@$undef_ref, "#undef cctk_bbox\n");
	push(@$def_ref, "#define cctk_delta_time staticData.cctkGH->cctk_delta_time()\n");
	push(@$undef_ref, "#undef cctk_delta_time\n");
	push(@$def_ref, "#define cctk_time staticData.cctkGH->cctk_time()\n");
	push(@$undef_ref, "#undef cctk_time\n");
	push(@$def_ref, "#define cctk_delta_space (staticData.cctkGH->cctk_delta_space())\n");
	push(@$undef_ref, "#undef cctk_delta_space\n");
	push(@$def_ref, "#define cctk_origin_space (staticData.cctkGH->cctk_origin_space())\n");
	push(@$undef_ref, "#undef cctk_origin_space\n");
	push(@$def_ref, "#define cctk_levfac (staticData.cctkGH->cctk_levfac())\n");
	push(@$undef_ref, "#undef cctk_levfac\n");
	push(@$def_ref, "#define cctk_levoff (staticData.cctkGH->cctk_levoff())\n");
	push(@$undef_ref, "#undef cctk_levoff\n");
	push(@$def_ref, "#define cctk_levoffdenom (staticData.cctkGH->cctk_levoffdenom())\n");
	push(@$undef_ref, "#undef cctk_levoffdenom\n");
	push(@$def_ref, "#define cctk_nghostzones (staticData.cctkGH->cctk_nghostzones())\n");
	push(@$undef_ref, "#undef cctk_nghostzones\n");
	push(@$def_ref, "#define cctk_iteration staticData.cctkGH->cctk_iteration()\n");
	push(@$undef_ref, "#undef cctk_iteration\n");

	push(@$def_ref, "\n");

	# build macros for struct of array access
	buildInfVarMacros($val_ref, $inf_ref, $def_ref, $undef_ref);

	push(@$def_ref, "\n");

	# build parameter macros
	buildParameterMacros($par_ref, $def_ref, $undef_ref);

	return;
}

#
# Build parameter macros. Parameter become static data in a cell classes.
# Static data is hold in a separate class called "staticData". This is
# why these macros define parameter names into staticData.name. An example:
#  - #define bound staticData.bound
#
# param:
#  - par_ref  : ref to parameter hash
#  - def_ref  : ref to array where defines will be stored
#  - undef_ref: ref to array where undefines will be stored
#
# return:
#  - none, macros and undefs will be stored in def_ref and undef_ref
#
sub buildParameterMacros
{
	my ($par_ref, $def_ref, $undef_ref) = @_;

	foreach my $name (keys %{$par_ref}) {
		# build define and undefines
		push(@$def_ref,   "#define $name staticData.$name\n");
		push(@$undef_ref, "#undef $name\n");
	}

	return;
}

#
# Generates macros for LibGeoDecomp's variables to have same code
# as Cactus has. An example:
#   #define phi     &hoodNew[FixedCoord<0, 0, 0>()].var_phi
#   #define phi_p   &hoodOld[FixedCoord<0, 0, 0>()].var_phi
#   #define phi_p_p &hoodOld[FixedCoord<0, 0, 0>()].var_phi_p
# Also generates undefs for these macros to avoid confusions with
# other source files.
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
# Builds cell's static updateLineX function. If more than one function for
# evolution is given, then every function will be build separately and just
# called in updateLineX in given order.
#
# param:
#  - evol_ref: ref to hash where evolution function(s) is/are stored
#  - val_ref : ref to value data hash
#  - inf_ref : ref to interface data hash
#
# return:
#  - none, stores string of updatelinex function into value hash, key "update_linex",
#    and if there are more evolution functions then they will be stored as array of
#    strings in value hash, key "evol_funcs"
#
sub buildUpdateFunctions
{
	my ($evol_ref, $val_ref, $inf_ref) = @_;
	my (@keys);

	# init
	@keys = keys %{$evol_ref};

	# one function -> just build updateLineX
	if (@keys == 1) {
		my (@linex, $code_str, $func, $func_ref);

		# get function
		$func     = $keys[0];
		$func_ref = $evol_ref->{$func}{"data"};

		# adjust evol function for updateLine
		adjustEvolutionFunction($inf_ref, $val_ref, $func_ref);
		# add rotating timelevels
		addRotateTimelevels($inf_ref, $val_ref, $func_ref);
		# indent function
		util_indent($func_ref, 2);

		# build code string
		$code_str = join("\n", @$func_ref);

		push(@linex, $tab."template<typename ACCESSOR1, typename ACCESSOR2>\n");
		push(@linex, $tab."static void updateLineX(ACCESSOR1& hoodOld, int indexEnd, ACCESSOR2& hoodNew, int /* nanoStep */)\n");
		push(@linex, $tab."{\n");
		push(@linex, "$code_str\n");
		push(@linex, $tab."}\n");

		# build final string
		$val_ref->{"update_linex"} = join("", @linex);
	} elsif (@keys > 1) {
		# more functions -> build and call them
		my (@linex, @rotate);

		# build each function
		foreach my $func (@keys) {
			my (@evol, $code_str, $func_ref);

			# get function
			$func_ref = $evol_ref->{$func}{"data"};

			# adjust evol function for updateLine
			adjustEvolutionFunction($inf_ref, $val_ref, $func_ref);
			# indent function
			util_indent($func_ref, 2);

			# build code string
			$code_str = join("\n", @$func_ref);

			# build function
			push(@evol, $tab."template<typename ACCESSOR1, typename ACCESSOR2>\n");
			push(@evol, $tab."static void $func(ACCESSOR1& hoodOld, int indexEnd, ACCESSOR2& hoodNew)\n");
			push(@evol, $tab."{\n");
			push(@evol, "$code_str\n");
			push(@evol, $tab."}\n");

			# save evol function
			push(@{$val_ref->{"evol_funcs"}}, join("", @evol));
		}

		# build rotateTimelevels
		push(@rotate, $tab."template<typename ACCESSOR1, typename ACCESSOR2>");
		push(@rotate, $tab."static void rotateTimelevels(ACCESSOR1& hoodOld, int indexEnd, ACCESSOR2& hoodNew)");
		push(@rotate, $tab."{");
		addRotateTimelevels($inf_ref, $val_ref, \@rotate);
		push(@rotate, $tab."}");
		push(@{$val_ref->{"evol_funcs"}}, join("\n", @rotate));

		# build updateLineX
		push(@linex, $tab."template<typename ACCESSOR1, typename ACCESSOR2>\n");
		push(@linex, $tab."static void updateLineX(ACCESSOR1& hoodOld, int indexEnd, ACCESSOR2& hoodNew, int /* nanoStep */)\n");
		push(@linex, $tab."{\n");
		# call them
		for my $func (@keys) {
			push(@linex, $tab.$tab.$func."(hoodOld, indexEnd, hoodNew);\n");
		}
		push(@linex, $tab.$tab."rotateTimelevels(hoodOld, indexEnd, hoodNew);\n");
		push(@linex, $tab."}\n");

		# save it
		$val_ref->{"update_linex"} = join("", @linex);
	} else {
		# this should never happen, since the schedule functions ensure that
		# at least one function is returned, even if it's not valid
		_err("No functions for building cell class found.", __FILE__, __LINE__);
	}

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
	push(@outdata, "// rotate timelevels\n");

	# start for loop
	push(@outdata, "for (int $index = 0; $index < (indexEnd - hoodOld.index()); ++$index) {\n");

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
				my ($left, $right, $hood_new, $gfindex, $var_idx);

				$var_idx  = "vindex";
				$gfindex  = getGFIndexFirst($dim, $index);
				$hood_new = "(&hoodNew.var_" . $name . ("_p" x ($i - 1) . "())");
				$left     = "$hood_new" . "[$var_idx]";
				# using macro here, it's just shorter
				$right    = "$name" . ("_p" x ($i - 1)) . "[$var_idx]";

				# save
				push(@outdata, "int $var_idx = $gfindex;\n");
				push(@outdata, "$left = $right;\n");
				$pushed = 1;
			}
		}
	}

	# end foor loop
	push(@outdata, "}\n");

	# indent
	util_indent(\@outdata, 2);

	# only add if there variables, else there would be a useless comment
	push(@$evol_ref, @outdata) if ($pushed);

	return;
}

#
# This function adjusts the loop indices
# in the for loops. For updateLineX only one
# line has to be updated, but the Cactus code updates
# a n-dimensional cube. This is why the loop indices have
# to be adjusted.
#
# params:
#  - inf_ref : ref to interface data hash
#  - val_ref : ref to values hash
#  - evol_ref: ref to array of evol function
#
# return:
#  - none, evol_ref is modified
#
sub adjustEvolutionFunction
{
	my ($inf_ref, $val_ref, $evol_ref) = @_;
	my ($codestr, $dim);
	my (@blocks, $lbcopy, $i);

	# init
	$codestr = join("\n", @$evol_ref);
	$dim     = $val_ref->{"dim"};

	# check for empty evol func
	goto out if (scalar @$evol_ref <= 1);

	# find for loops and adjust indices in the following way:
	#  - for (int i = x; i < gridSize(); i++) => for (int i = 0; i < 1; ++i)
	#  - the last will be: for (int x = 0; x < indexEnd - *indexOld; ++x)
	@blocks = $codestr =~ /((?:for\s*\([\w\s()+\-*\/=<>;,\[\]]*\)\s*\{\s*){$dim})/g;
	unless (@blocks) {
		_warn("Could not adjust loop indices.\n  -> You propably want to adjust the".
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
				$replace = !$type ? "for ($index = 0; $index < (indexEnd - hoodOld.index()); ++$index)" :
					"for ($type $index = 0; $index < (indexEnd - hoodOld.index()); ++$index)";
			}
			$lbcopy =~ s/\Q$for\E/$replace/;
		}

		# final replacement
		$codestr =~ s/\Q$loopblock\E/$lbcopy/;
	}

 out:
	@$evol_ref = split "\n", $codestr;

	return;
}

#
# Build cell header.
#
# param:
#  - val_ref: ref to value hash
#  - opt_ref: ref to options hash
#  - out_ref: ref where to store cell header
#
# return:
#  - none, header will be stored into out_ref
#
sub buildCellHeader
{
	my ($val_ref, $opt_ref, $out_ref) = @_;
	my ($dim, $class, $static_class, $ncellvars, $nevolfuncs, $mpi);

	# init
	$dim          = $val_ref->{"dim"};
	$class        = $val_ref->{"class_name"};
	$static_class = $val_ref->{"static_class_name"};
	$ncellvars    = $val_ref->{"cell_params"} eq "" ? 0 : 1;
	$nevolfuncs   = $val_ref->{"evol_funcs"} ? 1 : 0;
	$mpi          = $opt_ref->{"mpi"};

	# all template related code goes into the header
	push(@$out_ref, "#ifndef _CELL_H_\n");
	push(@$out_ref, "#define _CELL_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include <cmath>\n");
	push(@$out_ref, "#include \"cctk.h\"\n");
	push(@$out_ref, "#include \"staticdata.h\"\n");
	push(@$out_ref, "#include \"cctk_$class.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class $class\n");
	push(@$out_ref, "{\n");
	if ($nevolfuncs) {
		push(@$out_ref, "private:\n");
		push(@$out_ref, $_."\n") for (@{$val_ref->{"evol_funcs"}});
		push(@$out_ref, "\n");
	}
	push(@$out_ref, "public:\n");
	push(@$out_ref, $tab."class API :\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasFixedCoordsOnlyUpdate,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasSoA,\n");
	# for cactus code using updateLineX which should make things a bit faster
	push(@$out_ref, $tab.$tab."public APITraits::HasUpdateLineX,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasOpaqueMPIDataType<$class>,\n")
		if ($mpi);
	push(@$out_ref, $tab.$tab."public APITraits::HasStencil<Stencils::Moore<$dim, $ghostzone_width> >,\n");
	push(@$out_ref, $tab.$tab."public APITraits::Has"."$topology"."Topology<$dim>,\n");
	push(@$out_ref, $tab.$tab."public APITraits::HasStaticData<$static_class>\n");
	push(@$out_ref, $tab."{};\n");
	push(@$out_ref, "\n");
	# check here if there are cell vars for avoiding build failures
	if (!$ncellvars) {
		push(@$out_ref, $tab."explicit $class() {}\n");
	} else {
		push(@$out_ref, $tab."explicit $class($val_ref->{\"cell_params\"}) :\n");
		push(@$out_ref, $tab.$tab."$val_ref->{\"cell_init_params\"}\n");
		push(@$out_ref, $tab."{}\n");
	}
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"update_linex\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"inf_vars\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."// class for static data\n");
	push(@$out_ref, $tab."static $static_class staticData;\n");
	push(@$out_ref, $tab."static MPI_Datatype MPIDataType;\n") if ($mpi);
	push(@$out_ref, "};\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"soa_macro\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include \"cctk_$class" . "_undef.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _CELL_H_ */\n");

	return;
}

#
# Build cell cpp file.
#
# param:
#  - val_ref: ref to value hash
#  - opt_ref: ref to options hash
#  - out_ref: ref where to store cell cpp
#
# return:
#  - none, cell cpp will be stored into out_ref
#
sub buildCellCpp
{
	my ($val_ref, $opt_ref, $out_ref) = @_;
	my ($static_class, $class, $mpi);

	# init
	$static_class = $val_ref->{"static_class_name"};
	$class        = $val_ref->{"class_name"};
	$mpi          = $opt_ref->{"mpi"};

	# init staticData of cell class
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "$static_class $class" . "::staticData;\n");
	push(@$out_ref, "MPI_Datatype $class" . "::MPIDataType = MPI_DATATYPE_NULL;\n")
		if ($mpi);
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

	$val_ref->{"dim"}               = 0;
	$val_ref->{"class_name"}        = "";
	$val_ref->{"update_linex"}      = "";
	$val_ref->{"evol_funcs"}        = ();
	$val_ref->{"inf_vars"}          = "";
	$val_ref->{"cell_params"}       = "";
	$val_ref->{"cell_init_params"}  = "";
	$val_ref->{"soa_macro"}         = "";
	$val_ref->{"static_class_name"} = "";

	return;
}

#
# This function creates a cell class for LibGeoDecomp
# from a given thorn:
#  - parses interface.ccl to get variables
#  - parses parameters.ccl to get parameters
#  - parses schedule.ccl to get functions at specific (Cactus-!)timesteps
#
# param:
#  - config_ref   : ref to config hash
#  - thorninfo_ref: ref to thorninfo hash
#  - option_ref   : ref to options hash
#  - out_ref      : ref to store cellh, cellcpp, param_macro, etc.
#
# return:
#  - hash of cellh, cellcpp, param_macro, dimension, selectors, inf_macros,
#    inf_macros_undef, special_macros, special_macros_undef, inf_data,
#    class_name
#
# documentation:
#  - all relevant and computed values for cell.h will be stored in values hash:
#    - dim              : dimension of code (2D/3D/4D)
#    - class_name       : name of cell class e.g. "Cell"
#    - update_linex     : string of update line function
#    - inf_vars         : all interface variables definitions
#    - cell_params      : parameters for constructor
#    - cell_init_params : init constructor variables
#    - soa_macro        : string of LibGeoDecomp Struct of Array macro
#    - static_class_name: name of the class which holds the static data for cell
#
sub createCellClass
{
	my ($config_ref, $thorninfo_ref, $option_ref, $out_ref) = @_;
	my ($thorndir, $thorn, $arrangement, $impl, $class, $first);
	my (@cellh, @cellcpp);
	my (@param_macro, @special_macros, @special_macros_undef);
	my (%inf_data, %param_data, %static, %values, %evol_funcs, %evol_thorn);

	# check thorns
	_warn("Using more than one evolution thorn is not supported at the Moment. ".
		  "Using the first one.", __FILE__, __LINE__)
		if (keys %{$config_ref->{"evol_thorns"}} > 1);

	# init
	initValueHash(\%values);
	$first                = (keys %{$config_ref->{"evol_thorns"}})[0];
	%evol_thorn           = %{$config_ref->{"evol_thorns"}{$first}};
	$thorndir             = $config_ref->{"arr_dir"} . "/" . $evol_thorn{"thorn_arr"};
	$thorn                = $evol_thorn{"thorn"};
	$arrangement          = $evol_thorn{"arr"};
	$impl                 = $thorninfo_ref->{$evol_thorn{"thorn_arr"}}{"impl"};
	$class                = $config_ref->{"config"} . "_Cell";
	$values{"class_name"} = $class;

	# parse param.ccl to get parameters
	getParameters($thorndir, $thorn, \%param_data);
	generateParameterMacro(\%param_data, $thorn, $impl, $class, "staticData.", \@param_macro);

	# parse schedule.ccl to get function(s) at CCTK_Evol-Timestep
	getEvolFunctions($thorndir, $thorn, \%evol_funcs);

	# parse interface.ccl to get vars
	getInterfaceVars($config_ref->{"arr_dir"}, $evol_thorn{"thorn_arr"},
					 $thorninfo_ref, \%inf_data);
	buildInterfaceStrings(\%inf_data, \%values);

	# get dimension
	$values{"dim"} = getDimension(\%inf_data);

	# build LibGeoDecomp Struct of Array macro
	$values{"soa_macro"} = generateSoAMacro(\%inf_data, $class);

	# special macros
	buildSpecialMacros(\%values, \%inf_data, \%param_data, \@special_macros,
					   \@special_macros_undef);

	# build updateLineX function
	buildUpdateFunctions(\%evol_funcs, \%values, \%inf_data);

	# generate a class holding all static data
	# this is needed for having static data in a LibGeoDecomp cell class
	createStaticDataClass(\%inf_data, \%param_data, $class, \%static);
	$values{"static_class_name"} = $static{"class_name"};

	# build final files
	buildCellHeader(\%values, $option_ref, \@cellh);
	buildCellCpp(\%values, $option_ref, \@cellcpp);

	# prepare hash
	$out_ref->{"cellh"}                = \@cellh;
	$out_ref->{"cellcpp"}              = \@cellcpp;
	$out_ref->{"param_macro"}          = \@param_macro;
	$out_ref->{"special_macros"}       = \@special_macros;
	$out_ref->{"special_macros_undef"} = \@special_macros_undef;
	$out_ref->{"class_name"}           = $values{"class_name"};
	$out_ref->{"dim"}                  = $values{"dim"};
	$out_ref->{"inf_data"}             = \%inf_data;
	$out_ref->{"static_data_class"}    = \%static;

	return;
}

1;
