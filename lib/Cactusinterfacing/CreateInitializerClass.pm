
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

		# skip arrays and scalars
		next if ($gtype =~ /^ARRAY$/i);
		next if ($gtype =~ /^SCALAR$/i);

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

		# skip arrays and scalars
		next if ($gtype =~ /^ARRAY$/i);
		next if ($gtype =~ /^SCALAR$/i);

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
# Builds some Cactus macros that are different for a initializer.
# This includes:
#  - CCTK_GFINDEX
#  - variables of cactus grid hierarchy
#  - read member macro
#  - write member macro
#  - object declaration
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
	my ($val_ref, $cinf_ref, $out_ref) = @_;
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
	push(@$out_ref, "\n");

	# add variables for cGH
	# this provides access for the thorn code to all cctk grid hierachie variables
	push(@$out_ref, "#define cctk_dim cctkGH->cctk_dim()\n");
	push(@$out_ref, "#define cctk_gsh (cctkGH->cctk_gsh())\n");
	push(@$out_ref, "#define cctk_lsh (cctkGH->cctk_lsh())\n");
	push(@$out_ref, "#define cctk_lbnd (cctkGH->cctk_lbnd())\n");
	push(@$out_ref, "#define cctk_ubnd (cctkGH->cctk_ubnd())\n");
	push(@$out_ref, "#define cctk_bbox (cctkGH->cctk_bbox())\n");
	push(@$out_ref, "#define cctk_delta_time cctkGH->cctk_delta_time()\n");
	push(@$out_ref, "#define cctk_time cctkGH->cctk_time()\n");
	push(@$out_ref, "#define cctk_delta_space (cctkGH->cctk_delta_space())\n");
	push(@$out_ref, "#define cctk_origin_space (cctkGH->cctk_origin_space())\n");
	push(@$out_ref, "#define cctk_levfac (cctkGH->cctk_levfac())\n");
	push(@$out_ref, "#define cctk_levoff (cctkGH->cctk_levoff())\n");
	push(@$out_ref, "#define cctk_levoffdenom (cctkGH->cctk_levoffdenom())\n");
	push(@$out_ref, "#define cctk_nghostzones (cctkGH->cctk_nghostzones())\n");
	push(@$out_ref, "#define cctk_iteration cctkGH->cctk_iteration()\n");
	push(@$out_ref, "\n");

	# build init specific macros
	buildReadMemberMacro($val_ref, $out_ref);
	push(@$out_ref, "\n");
	buildWriteMemberMacro($val_ref, $out_ref);
	push(@$out_ref, "\n");
	buildWriteMember($val_ref, $cinf_ref, $out_ref);
	push(@$out_ref, "\n");
	buildObjectsDecl($val_ref, $cinf_ref);

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
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(CCTK_REAL value) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."$cell_class cell = target->get(pos); \\\n");
	push(@$out_ref, $tab.$tab.$tab."cell.MEMBER = value; \\\n");
	push(@$out_ref, $tab.$tab.$tab."target->set(pos, cell); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return *this; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(CCTK_INT value) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."$cell_class cell = target->get(pos); \\\n");
	push(@$out_ref, $tab.$tab.$tab."cell.MEMBER = value; \\\n");
	push(@$out_ref, $tab.$tab.$tab."target->set(pos, cell); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return *this; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(CCTK_BYTE value) \\\n");
	push(@$out_ref, $tab.$tab."{ \\\n");
	push(@$out_ref, $tab.$tab.$tab."$cell_class cell = target->get(pos); \\\n");
	push(@$out_ref, $tab.$tab.$tab."cell.MEMBER = value; \\\n");
	push(@$out_ref, $tab.$tab.$tab."target->set(pos, cell); \\\n");
	push(@$out_ref, $tab.$tab.$tab."return *this; \\\n");
	push(@$out_ref, $tab.$tab."} \\\n");
	#push(@$out_ref, "\\\n");
	push(@$out_ref, $tab.$tab."WriteReference_##MEMBER& operator=(CCTK_CHAR value) \\\n");
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
# Builds constructor. Allocates memory for x, y and z.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none, result will be stored in val_ref using key "constructor"
#
sub buildConstructor
{
	my ($val_ref) = @_;
	my (@outdata, $class, $dim, $i, $x, @grid_size, $size_coord);

	# init
	$dim   = $val_ref->{"dim"};
	$class = $val_ref->{"class_name"};
	# setup grid size in apprioriate dimension
	for ($i = 0; $i < $dim; ++$i) {
		push(@grid_size, "cctkGH->cctk_gsh()[$i]");
	}
	$size_coord = getCoord("coord", $dim, \@grid_size);

	# go
	push(@outdata, $tab."$class() : SimpleInitializer<$val_ref->{\"cell_class_name\"}>($size_coord, cctkGH->cctk_iteration())\n");
	push(@outdata, $tab."{}\n");

	# save data
	$val_ref->{"constructor"} = join("", @outdata);

	return;
}

#
# Builds the deconstructor. This frees x, y and z.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none, result will be stored in val_ref using key "deconstructor"
#
sub buildDeconstructor
{
	my ($val_ref) = @_;
	my (@outdata, $class, $dim, $i, $x);

	# init
	$dim   = $val_ref->{"dim"};
	$class = $val_ref->{"class_name"};

	# go
	push(@outdata, $tab."virtual ~$class()\n");
	push(@outdata, $tab."{\n");

	for ($i = 0, $x = 'x'; $i < $dim; ++$i, ++$x) {
		push(@outdata, $tab.$tab."delete[] $x;\n");
	}

	push(@outdata, $tab."}\n");

	# save data
	$val_ref->{"deconstructor"} = join("", @outdata);

	return;
}

#
# This functions sets up fake x,y,z. This would be done by CartGrid3D Thorn.
# Generates the code in appropriate dimension.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none, the function will be stored in val_ref using key "xyz_func"
#
sub buildXYZFunction
{
	my ($val_ref) = @_;
	my (@outdata, $dim);

	# init
	$dim = $val_ref->{"dim"};

	push(@outdata, $tab."void setupXYZ()\n");
	push(@outdata, $tab."{\n");

	# switch dimension
	if ($dim == 1) {
		push(@outdata, $tab.$tab."int a = cctkGH->cctk_lsh()[0];\n");
		push(@outdata, $tab.$tab."int size = a;\n");
		push(@outdata, $tab.$tab."x = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."int vindex, i;\n");
		push(@outdata, $tab.$tab."int iend = cctkGH->cctk_gsh()[0];\n");
		push(@outdata, $tab.$tab."CCTK_REAL X = cctkGH->cctk_origin_space()[0]+cctkGH->cctk_delta_space()[0]*cctkGH->cctk_lbnd()[0];\n");
		push(@outdata, $tab.$tab."for (i = 0; i < iend; ++i, X += cctkGH->cctk_delta_space()[0]) {\n");
		push(@outdata, $tab.$tab.$tab."vindex = i;\n");
		push(@outdata, $tab.$tab.$tab."x[vindex] = X;\n");
		push(@outdata, $tab.$tab."}\n");
	} elsif ($dim == 2) {
		push(@outdata, $tab.$tab."int a = cctkGH->cctk_lsh()[0];\n");
		push(@outdata, $tab.$tab."int b = cctkGH->cctk_lsh()[1];\n");
		push(@outdata, $tab.$tab."int size = a * b;\n");
		push(@outdata, $tab.$tab."x = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."y = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."int vindex, i, j;\n");
		push(@outdata, $tab.$tab."int iend = cctkGH->cctk_gsh()[0];\n");
		push(@outdata, $tab.$tab."int jend = cctkGH->cctk_gsh()[1];\n");
		push(@outdata, $tab.$tab."CCTK_REAL X = cctkGH->cctk_origin_space()[0]+cctkGH->cctk_delta_space()[0]*cctkGH->cctk_lbnd()[0];\n");
		push(@outdata, $tab.$tab."CCTK_REAL Y = cctkGH->cctk_origin_space()[1]+cctkGH->cctk_delta_space()[1]*cctkGH->cctk_lbnd()[1];\n");
		push(@outdata, $tab.$tab."for (j = 0; j < jend; ++j, Y += cctkGH->cctk_delta_space()[1]) {\n");
		push(@outdata, $tab.$tab.$tab."for (i = 0; i < iend; ++i, X += cctkGH->cctk_delta_space()[0]) {\n");
		push(@outdata, $tab.$tab.$tab.$tab."vindex = (i + iend * j);\n");
		push(@outdata, $tab.$tab.$tab.$tab."x[vindex] = X; y[vindex] = Y;\n");
		push(@outdata, $tab.$tab.$tab."}\n");
		push(@outdata, $tab.$tab.$tab."X = cctkGH->cctk_origin_space()[0];\n");
		push(@outdata, $tab.$tab."}\n");
	} elsif ($dim == 3) {
		push(@outdata, $tab.$tab."int a = cctkGH->cctk_lsh()[0];\n");
		push(@outdata, $tab.$tab."int b = cctkGH->cctk_lsh()[1];\n");
		push(@outdata, $tab.$tab."int c = cctkGH->cctk_lsh()[2];\n");
		push(@outdata, $tab.$tab."int size = a * b * c;\n");
		push(@outdata, $tab.$tab."x = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."y = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."z = new CCTK_REAL[size];\n");
		push(@outdata, $tab.$tab."int vindex, i, j, k;\n");
		push(@outdata, $tab.$tab."int iend = cctkGH->cctk_gsh()[0];\n");
		push(@outdata, $tab.$tab."int jend = cctkGH->cctk_gsh()[1];\n");
		push(@outdata, $tab.$tab."int kend = cctkGH->cctk_gsh()[2];\n");
		push(@outdata, $tab.$tab."CCTK_REAL X = cctkGH->cctk_origin_space()[0]+cctkGH->cctk_delta_space()[0]*cctkGH->cctk_lbnd()[0];\n");
		push(@outdata, $tab.$tab."CCTK_REAL Y = cctkGH->cctk_origin_space()[1]+cctkGH->cctk_delta_space()[1]*cctkGH->cctk_lbnd()[1];\n");
		push(@outdata, $tab.$tab."CCTK_REAL Z = cctkGH->cctk_origin_space()[2]+cctkGH->cctk_delta_space()[2]*cctkGH->cctk_lbnd()[2];\n");
		push(@outdata, $tab.$tab."for (k = 0; k < kend; ++k, Z += cctkGH->cctk_delta_space()[2]) {\n");
		push(@outdata, $tab.$tab.$tab."for (j = 0; j < jend; ++j, Y += cctkGH->cctk_delta_space()[1]) {\n");
		push(@outdata, $tab.$tab.$tab.$tab."for (i = 0; i < iend; ++i, X += cctkGH->cctk_delta_space()[0]) {\n");
		push(@outdata, $tab.$tab.$tab.$tab.$tab."vindex = (i + iend * (j + jend * k));\n");
		push(@outdata, $tab.$tab.$tab.$tab.$tab."x[vindex] = X; y[vindex] = Y; z[vindex] = Z;\n");
		push(@outdata, $tab.$tab.$tab.$tab."}\n");
		push(@outdata, $tab.$tab.$tab.$tab."X = cctkGH->cctk_origin_space()[0];\n");
		push(@outdata, $tab.$tab.$tab."}\n");
		push(@outdata, $tab.$tab.$tab."Y = cctkGH->cctk_origin_space()[1];\n");
		push(@outdata, $tab.$tab."}\n");
	} else {
		_err("Dimension $dim is too high!", __FILE__, __LINE__);
	}

	push(@outdata, $tab."}\n");

	# save
	$val_ref->{"xyz_func"} = join("", @outdata);

	return;
}

#
# This functions initializes cctk_lbnd, cctk_ubnd and cctk_lsh.
# This cannot be done in parameter parser, since we do not have
# decomposition there. This is why this needs to be done in
# initializer.
#
# param:
#  - val_ref: ref to values hash
#
# return:
#  - none, result will be stored in values hash using key "cctk_func"
#
sub buildCctkGHFunction
{
	my ($val_ref) = @_;
	my (@outdata, $dim, $i, $x);

	# init
	$dim = $val_ref->{"dim"};

	# build function
	push(@outdata, $tab."inline void setupCctkGH(const CoordBox<$dim>& box)\n");
	push(@outdata, $tab."{\n");
	for ($i = 0, $x = 'x'; $i < $dim; ++$i, ++$x) {
		push(@outdata, $tab.$tab."cctkGH->cctk_lsh()[$i]  = box.dimensions.$x();\n");
		push(@outdata, $tab.$tab."cctkGH->cctk_lbnd()[$i] = box.origin.$x();\n");
		push(@outdata, $tab.$tab."cctkGH->cctk_ubnd()[$i] = box.origin.$x() + box.dimensions.$x() - 1;\n");
	}
	push(@outdata, $tab."}\n");

	# save
	$val_ref->{"cctk_func"} = join("", @outdata);

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
	# call functions to set up variables
	push(@outdata, $tab."setupCctkGH(box);\n");
	push(@outdata, $tab."setupXYZ();\n");
	push(@outdata, "\n");
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
	my ($dim);

	# init
	$dim       = $val_ref->{"dim"};

	# go
	push(@$out_ref, "#ifndef _INIT_H_\n");
	push(@$out_ref, "#define _INIT_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include <cmath>\n");
	push(@$out_ref, "#include \"cctk.h\"\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "class $val_ref->{\"class_name\"} : public SimpleInitializer<$val_ref->{\"cell_class_name\"}>\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, "public:\n");
	push(@$out_ref, "$val_ref->{\"constructor\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"deconstructor\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"xyz_func\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{\"cctk_func\"}");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."virtual void grid(GridBase<$val_ref->{\"cell_class_name\"}, $dim>*);\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "$val_ref->{'param_def'}\n");
	push(@$out_ref, $tab."// cactus grid hierarchy\n");
	push(@$out_ref, $tab."static CactusGrid *cctkGH;\n");
	push(@$out_ref, $tab."// fake x, y, z\n");
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
	push(@$out_ref, "// parameter initialisation to default values\n");
	push(@$out_ref, "$val_ref->{'param_init'}\n");
	push(@$out_ref, "CactusGrid* $val_ref->{\"class_name\"}::cctkGH = 0;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "// setting up initial grid\n");
	push(@$out_ref, "$val_ref->{'grid_func'}\n");
	push(@$out_ref, "\n");

	return;
}

#
# The subroutine checks whether the init thorn inherits from the evol thorn.
#
# param:
#  - thorninfo_ref: ref to thorninfo data hash
#  - init_ar      : arrangement/InitThorn
#  - evol_ar      : arrangement/EvolThorn
#
# return:
#  - none, exits on error
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

	$val_ref->{"dim"}              = 0;
	$val_ref->{"class_name"}       = "";
	$val_ref->{"cell_class_name"}  = "";
	$val_ref->{"cctk_initial_arr"} = ();
	$val_ref->{"param_def"}        = "";
	$val_ref->{"param_init"}       = "";
	$val_ref->{"constructor"}      = "";
	$val_ref->{"deconstructor"}    = "";
	$val_ref->{"objects_decl"}     = "";
	$val_ref->{"xyz_func"}         = "";
	$val_ref->{"cctk_func"}        = "";
	$val_ref->{"cctk_func_call"}   = "";

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
	my (@param_macro, @special_macros);
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
	buildParameterStrings(\%param_data, $class, 1, \%values);
	generateParameterMacro(\%param_data, $thorn, $impl, $class, "", \@param_macro);

	# parse schedule.ccl to get function at CCTK_INITIAL-Timestep
	getInitFunction($thorndir, $thorn, \%values);

	# build init specific special macros
	buildSpecialMacros(\%values, $cell_ref->{"inf_data"}, \@special_macros);

	# build grid, setupXYZ and setupCctkGH function as well as (de|con)structor
	buildGridFunction(\%values);
	buildXYZFunction(\%values);
	buildCctkGHFunction(\%values);
	buildConstructor(\%values);
	buildDeconstructor(\%values);

	# build cpp and header file
	buildInitHeader(\%values, \@inith);
	buildInitCpp(\%values, \@initcpp);

	# prepare hash
	$out_ref->{"inith"}          = \@inith;
	$out_ref->{"initcpp"}        = \@initcpp;
	$out_ref->{"param_macro"}    = \@param_macro;
	$out_ref->{"special_macros"} = \@special_macros;
	$out_ref->{"class_name"}     = $values{"class_name"};
	$out_ref->{"dim"}            = $values{"dim"};

	return;
}

1;
