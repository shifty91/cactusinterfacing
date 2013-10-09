
##
## CreateInititializerClass.pm
##
## This module builds an initializer for LibGeoDecomp.
##

package Cactusinterfacing::CreateInitializerClass;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Config qw($tab);
use Cactusinterfacing::Parameter qw(getParameters generateParameterMacro
									buildParameterStrings);
use Cactusinterfacing::Schedule qw(getInitFunction);
use Cactusinterfacing::Interface qw(getInterfaceVars);
use Cactusinterfacing::Utils qw(util_indent _err);
use Cactusinterfacing::Libgeodecomp qw(getCoord getGFIndex);
use Cactusinterfacing::ThornList qw(isInherit isFriend);

# exports
our @EXPORT_OK = qw(createInitializerClass);

#
# Builds the ADD_WRITE_MEMBER macro calls to create the
# classes for write access.
#
# param:
#  - val_ref: ref to values hash
#  - inf_ref: ref to interface data hash
#  - out_ref: ref to array where macro calls will be stored
#
# return:
#  - none, the macro calls will be store in out_ref
#
sub buildWriteMember
{
	my ($val_ref, $inf_ref, $out_ref) = @_;

	foreach my $group (keys %{$inf_ref}) {
		my ($i, $gtype, $vtype, $timelevels);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$vtype      = $inf_ref->{$group}{"vtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};

		for ($i = 0; $i < ($timelevels - 1); ++$i) {
			foreach my $name (@{$inf_ref->{$group}{"names"}}) {
				my $var_name = "var_".$name.("_p" x $i);
				push(@$out_ref, "ADD_WRITE_MEMBER($vtype, $var_name)\n");
			}
		}
	}

	return;
}

#
# Builds special objects declaration which have to be done
# before starting the init function.
#
# param:
#  - val_ref: ref to values hash
#  - inf_ref: ref to interface data hash
#
# return:
#  - none, the declarations will be stored in val_ref, key is "objects_decl"
#
sub buildObjectsDecl
{
	my ($val_ref, $inf_ref) = @_;
	my (@outdata, $dim);

	# init
	$dim = $val_ref->{"dim"};

	# the first object is fixed
	# it's the box
	push(@outdata, $tab."CoordBox<$dim> box = target->boundingBox();\n");

	foreach my $group (keys %{$inf_ref}) {
		my ($i, $gtype, $vtype, $timelevels);

		# init
		$gtype      = $inf_ref->{$group}{"gtype"};
		$vtype      = $inf_ref->{$group}{"vtype"};
		$timelevels = $inf_ref->{$group}{"timelevels"};

		for ($i = 0; $i < ($timelevels - 1); ++$i) {
			foreach my $name (@{$inf_ref->{$group}{"names"}}) {
				my $decl = "WriteMember_var_".$name.("_p" x $i)." $name".("_p" x $i)."(target);";
				push(@outdata, $tab."$decl\n");
			}
		}
	}

	# save
	$val_ref->{"objects_decl"} = join("", @outdata);

	return;
}

#
# Builds some cactus macros that are different for a initializer.
#
# param:
#  - val_ref: ref to values hash
#  - out_ref: ref to array where special macros will be stored
#
# return:
#  - none, macros will be stored in out_ref
#
sub buildSpecialMacros
{
	my ($val_ref, $out_ref) = @_;
	my ($dim, $coord, $gfindex, $i, $char, @letters);

	# init
	$dim = $val_ref->{"dim"};
	$char = 'I';

	for ($i = 0; $i < $dim; ++$i) {
		push(@letters, $char++);
	}
	$coord   = getCoord("coord", $dim, \@letters);
	$gfindex = getGFIndex($dim, \@letters);

	# build macros
	push(@$out_ref, "#define $gfindex ($coord".".toIndex(box.dimensions))\n");
	# FIXME: this shouldn't be needed, but atm there's no other way to do this
	push(@$out_ref, "#define SQR(X) ((X)*(X))\n");

	return;
}

#
# Builds ADD_READ_MEMBER. This is needed for defining
# read access to a cell member.
#
# param:
#  - val_ref: ref to values hash
#  - out_ref: ref to array where read member macro will be stored
#
# return:
#  - none, macro will be stored in out_ref
#
sub buildReadMemberMacro
{
	my ($val_ref, $out_ref) = @_;
	my ($cell_class, $dim);

	# init
	$cell_class = $val_ref->{"cell_class_name"};
	$dim        = $val_ref->{"dim"};

	# build macro
	push(@$out_ref, "// helper code to pull data from gridbase\n");
	push(@$out_ref, "#define ADD_READ_MEMBER(TYPE, MEMBER) \\\n");
	push(@$out_ref, $tab."class ReadMember_##MEMBER \\\n");
	push(@$out_ref, $tab."{ \\\n");
	push(@$out_ref, $tab."public: \\\n");
	push(@$out_ref, $tab.$tab."ReadMember_##MEMBER(GridBase<$cell_class, $dim> *source) : \\\n");
	push(@$out_ref, $tab.$tab.$tab."source(source), \\\n");
	push(@$out_ref, $tab.$tab.$tab."box(source->boundingBox()) \\\n");
	push(@$out_ref, $tab.$tab."{} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."TYPE operator[](int index) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."Coord<$dim> c = box.origin + \\\n");
	push(@$out_ref, $tab.$tab.$tab.$tab."box.dimensions.indexToCoord(index); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return source->get(c).MEMBER; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab."private: \\\n");
	push(@$out_ref, $tab.$tab."GridBase<$cell_class, $dim> *source; \\\n");
	push(@$out_ref, $tab.$tab."CoordBox<$dim> box; \\\n");
	push(@$out_ref, $tab."};\n");

	return;
}

#
# Builds ADD_WRITE_MEMBER. This is needed for defining
# write access to a cell member to set initial values.
#
# param:
#  - val_ref: ref to values hash
#  - out_ref: ref to array where write member macro will be stored
#
# return:
#  - none, macro will be stored in out_ref
#
sub buildWriteMemberMacro
{
	my ($val_ref, $out_ref) = @_;
	my ($cell_class, $dim);

	# init
	$cell_class = $val_ref->{"cell_class_name"};
	$dim        = $val_ref->{"dim"};

	# build macro
	push(@$out_ref, "// helper code to write data back to gridbase\n");
	push(@$out_ref, "#define ADD_WRITE_MEMBER(TYPE, MEMBER) \\\n");
	push(@$out_ref, $tab."class WriteReference_##MEMBER \\\n");
	push(@$out_ref, $tab."{ \\\n");
	push(@$out_ref, $tab."public: \\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER(const Coord<$dim>& pos, GridBase<$cell_class, $dim> *target) : \\\n");
	push(@$out_ref, $tab.$tab.$tab."pos(pos), target(target) \\\n");
	push(@$out_ref, $tab.$tab."{} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(TYPE value) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."$cell_class cell = target->get(pos); \\\n");
	push(@$out_ref, $tab.$tab.$tab."cell.MEMBER = value; \\\n");
	push(@$out_ref, $tab.$tab.$tab."target->set(pos, cell); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return *this; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."template<typename WRITE_MEMBER> \\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(WRITE_MEMBER other) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."*this = other.get(); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return *this; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."TYPE get() const \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."return target->get(pos).MEMBER; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab."private: \\\n");
	push(@$out_ref, $tab.$tab."Coord<$dim> pos; \\\n");
	push(@$out_ref, $tab.$tab."GridBase<$cell_class, $dim> *target; \\\n");
	push(@$out_ref, $tab."}; \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab."class WriteMember_##MEMBER \\\n");
	push(@$out_ref, $tab."{ \\\n");
	push(@$out_ref, $tab."public: \\\n");
	push(@$out_ref, $tab.$tab."WriteMember_##MEMBER(GridBase<$cell_class, $dim> *target) : \\\n");
	push(@$out_ref, $tab.$tab.$tab."target(target), box(target->boundingBox()) \\\n");
	push(@$out_ref, $tab.$tab."{} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER operator[](int index)\\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."Coord<$dim> c = box.origin + \\\n");
	push(@$out_ref, $tab.$tab.$tab.$tab."box.dimensions.indexToCoord(index); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return WriteReference_##MEMBER(c, target); \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab."private: \\\n");
	push(@$out_ref, $tab.$tab."GridBase<$cell_class, $dim> *target; \\\n");
	push(@$out_ref, $tab.$tab."CoordBox<$dim> box; \\\n");
	push(@$out_ref, $tab."}; \\\n");

	return;
}

#
# Builds grid function. This function sets up the initial grid.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none, function string will be stored in val_ref with key "grid_func"
#
sub buildGridFunction
{
	my ($val_ref) = @_;
	my (@outdata, $code_str, $dim, $init_class, $cell_class, $decl);

	# init
	$dim        = $val_ref->{"dim"};
	$init_class = $val_ref->{"class_name"};
	$cell_class = $val_ref->{"cell_class_name"};
	$decl       = $val_ref->{"objects_decl"};

	# indent function
	util_indent($val_ref->{"cctk_initial_arr"}, 1);

	# build code string
	$code_str = join("\n", @{$val_ref->{"cctk_initial_arr"}});

	push(@outdata, "void $init_class"."::"."grid(GridBase<$cell_class, $dim> *target)\n");
	push(@outdata, "{\n");
	push(@outdata, "$decl\n");
	push(@outdata, "$code_str\n");
	push(@outdata, "}\n");

	# save final function
	$val_ref->{"grid_func"} = join("", @outdata);

	return;
}

#
# Builds init.h file.
#
# param:
#  - val_ref: ref to values hash
#  - out_ref: ref to array where to store init.h
#
# return:
#  - none, header file will be stored in out_ref
#
sub buildInitHeader
{
	my ($val_ref, $out_ref) = @_;
	my ($dim, $i, @grid_size, $size_coord);

	# init
	$dim       = $val_ref->{"dim"};
	# setup grid size in apprioriate dimension
	for ($i = 0; $i < $dim; ++$i) {
		push(@grid_size, "cctkGH->cctk_gsh()[$i]");
	}
	$size_coord = getCoord("coord", $dim, \@grid_size);

	# FIXME: what to do with x,y,z?
	push(@$out_ref, "#ifndef _INIT_H_\n");
	push(@$out_ref, "#define _INIT_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include \"cctk.h\"\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class $val_ref->{\"class_name\"} : public SimpleInitializer<$val_ref->{\"cell_class_name\"}>\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	push(@$out_ref, $tab."using SimpleInitializer<$val_ref->{\"cell_class_name\"}>::gridDimensions;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."$val_ref->{\"class_name\"}() : SimpleInitializer<$val_ref->{\"cell_class_name\"}>($size_coord, cctkGH->cctk_iteration())\n");
	push(@$out_ref, $tab."{\n");
	# FIXME: will segfault if dimension < 3
	push(@$out_ref, $tab.$tab."int i = cctkGH->cctk_gsh()[0];\n");
	push(@$out_ref, $tab.$tab."int j = cctkGH->cctk_gsh()[1];\n");
	push(@$out_ref, $tab.$tab."int k = cctkGH->cctk_gsh()[2];\n");
	push(@$out_ref, $tab.$tab."int size = i * j * k;\n");
	push(@$out_ref, $tab.$tab."x = new CCTK_REAL[size];\n");
	push(@$out_ref, $tab.$tab."y = new CCTK_REAL[size];\n");
	push(@$out_ref, $tab.$tab."z = new CCTK_REAL[size];\n");
	push(@$out_ref, $tab.$tab."setupXYZ();\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."~$val_ref->{\"class_name\"}()\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."delete[] x;\n");
	push(@$out_ref, $tab.$tab."delete[] y;\n");
	push(@$out_ref, $tab.$tab."delete[] z;\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "\n");
	# FIXME: will segfault if dimension < 3
	push(@$out_ref, $tab."void setupXYZ()\n");
	push(@$out_ref, $tab."{\n");
	push(@$out_ref, $tab.$tab."int vindex, i, j, k;\n");
	push(@$out_ref, $tab.$tab."int iend = cctkGH->cctk_gsh()[0];\n");
	push(@$out_ref, $tab.$tab."int jend = cctkGH->cctk_gsh()[1];\n");
	push(@$out_ref, $tab.$tab."int kend = cctkGH->cctk_gsh()[2];\n");
	push(@$out_ref, $tab.$tab."CCTK_REAL X = cctkGH->cctk_origin_space()[0];\n");
	push(@$out_ref, $tab.$tab."CCTK_REAL Y = cctkGH->cctk_origin_space()[1];\n");
	push(@$out_ref, $tab.$tab."CCTK_REAL Z = cctkGH->cctk_origin_space()[2];\n");
	push(@$out_ref, $tab.$tab."for (k = 0; k < kend; ++k, Z += cctkGH->cctk_delta_space()[2]) {\n");
	push(@$out_ref, $tab.$tab.$tab."for (j = 0; j < jend; ++j, Y += cctkGH->cctk_delta_space()[1]) {\n");
	push(@$out_ref, $tab.$tab.$tab.$tab."for (i = 0; i < iend; ++i, X += cctkGH->cctk_delta_space()[0]) {\n");
	push(@$out_ref, $tab.$tab.$tab.$tab.$tab."vindex = (i + iend * (j + jend * k));\n");
	push(@$out_ref, $tab.$tab.$tab.$tab.$tab."x[vindex] = X; y[vindex] = Y; z[vindex] = Z;\n");
	push(@$out_ref, $tab.$tab.$tab.$tab."}\n");
	push(@$out_ref, $tab.$tab.$tab.$tab."X = cctkGH->cctk_origin_space()[0];\n");
	push(@$out_ref, $tab.$tab.$tab."}\n");
	push(@$out_ref, $tab.$tab.$tab."Y = cctkGH->cctk_origin_space()[1];\n");
	push(@$out_ref, $tab.$tab."}\n");
	push(@$out_ref, $tab."}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."virtual void grid(GridBase<$val_ref->{\"cell_class_name\"}, $dim>*);\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{'param_def'}\n");
	push(@$out_ref, $tab."// cactus grid hierarchy\n");
	push(@$out_ref, $tab."static CactusGrid *cctkGH;\n");
	push(@$out_ref, $tab."// fake x,y,z\n");
	push(@$out_ref, $tab."CCTK_REAL *x;\n");
	push(@$out_ref, $tab."CCTK_REAL *y;\n");
	push(@$out_ref, $tab."CCTK_REAL *z;\n");
	push(@$out_ref, "};\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _INIT_H_ */\n");

	return;
}

#
# Builds init.cpp file.
#
# param:
#  - val_ref: ref to value hash
#  - out_ref: ref to array where init.cpp will be stored
#
# return:
#  - none, results will be stored in out_ref
#
sub buildInitCpp
{
	my ($val_ref, $out_ref) = @_;

	push(@$out_ref, "#include \"init.h\"\n");
	push(@$out_ref, "#include \"cctk_$val_ref->{\"class_name\"}.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "// parameter init to default values\n");
	push(@$out_ref, "$val_ref->{'param_init'}\n");
	push(@$out_ref, "CactusGrid* $val_ref->{\"class_name\"}::cctkGH = 0;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "// setting up intitial grid\n");
	push(@$out_ref, "$val_ref->{'grid_func'}\n");
	push(@$out_ref, "\n");

	return;
}

#
# The subroutine checks whether the init thorn
# inherits from teh evol thorn.
#
# param:
#  - thorninfo_ref: ref to thorninfo data hash
#  - init_ar      : arrangement/InitThorn
#  - evol_ar      : arrangement/EvolThorn
#
# return:
#  - none
#
sub preCheck
{
	my ($thorninfo_ref, $init_ar, $cell_ar) = @_;

	# check if init and evol thorn share the same variables
	# else a initializer can't init the cells variables
	unless (isInherit($thorninfo_ref, $init_ar, $cell_ar) ||
		isFriend($thorninfo_ref, $init_ar, $cell_ar)) {
		_err("Init Thorn and Evol Thorn do not share same variables!",
			__FILE__, __LINE__);
	}

	return;
}

#
# Inits value hash with default values.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none
#
sub initValueHash
{
	my ($val_ref) = @_;

	$val_ref->{"dim"}                = 0;
	$val_ref->{"class_name"}         = "";
	$val_ref->{"cell_class_name"}    = "";
	$val_ref->{"cctk_initial_arr"}   = ();
	$val_ref->{"param_def"}          = "";
	$val_ref->{"param_init"}         = "";
	$val_ref->{"objects_decl"}       = "";

	return;
}

#
# This function creates a initializer class for LibGeoDecomp
# from a given cactus thorn.
#
# param:
#  - config_ref   : ref to config hash
#  - thorninfo_ref: ref to thorninfo hash
#  - cell_ref     : ref to cell data hash
#  - out_ref      : ref to hash where to store init files
#
# return:
#  - none, results will be stored in out_ref
#
sub createInitializerClass
{
	my ($config_ref, $thorninfo_ref, $cell_ref, $out_ref) = @_;
	my ($init_ar, $cell_ar, $thorndir, $thorn, $arrangement, $impl, $class);
	my (@inith, @initcpp);
	my (@param_macro, @read_macro, @write_macro, @write_member, @special_macros);
	my (%inf_data, %param_data, %values);

	# init
	initValueHash(\%values);
	$init_ar                   = $config_ref->{"init_thorn_arr"};
	$cell_ar                   = $config_ref->{"evol_thorn_arr"};
	$thorndir                  = $config_ref->{"arr_dir"}."/".$init_ar;
	$thorn                     = $config_ref->{"init_thorn"};
	$arrangement               = $config_ref->{"init_arr"};
	$impl                      = $thorninfo_ref->{$init_ar}[0];
	$class                     = $thorn."_Initializer";
	$values{"class_name"}      = $class;
	$values{"cell_class_name"} = $cell_ref->{"class_name"};
	$values{"dim"}             = $cell_ref->{"dim"};

	# pre check
	preCheck($thorninfo_ref, $init_ar, $cell_ar);

	# parse param ccl to get parameters
	getParameters($thorndir, $thorn, \%param_data);
	buildParameterStrings(\%param_data, $class, \%values);
	generateParameterMacro(\%param_data, $thorn, $impl, $class, \@param_macro);

	# parse schedule.ccl to get function at CCTK_INITIAL-Timestep
	getInitFunction($thorndir, $thorn, \%values);

	# build init specific macros
	buildReadMemberMacro(\%values, \@read_macro);
	buildWriteMemberMacro(\%values, \@write_macro);
	buildWriteMember(\%values, $cell_ref->{"inf_data"}, \@write_member);
	buildSpecialMacros(\%values, \@special_macros);
	buildObjectsDecl(\%values, $cell_ref->{"inf_data"});

	# build grid function
	buildGridFunction(\%values);

	# build cpp and header file
	buildInitHeader(\%values, \@inith);
	buildInitCpp(\%values, \@initcpp);

	# prepare hash
	$out_ref->{"inith"}          = \@inith;
	$out_ref->{"initcpp"}        = \@initcpp;
	$out_ref->{"param_macro"}    = \@param_macro;
	$out_ref->{"read_macro"}     = \@read_macro;
	$out_ref->{"write_macro"}    = \@write_macro;
	$out_ref->{"write_member"}   = \@write_member;
	$out_ref->{"special_macros"} = \@special_macros;
	$out_ref->{"class_name"}     = $values{"class_name"};
	$out_ref->{"dim"}            = $values{"dim"};

	return;
}

1;
