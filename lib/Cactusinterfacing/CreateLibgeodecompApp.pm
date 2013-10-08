
##
## CreateLibgeodecompApp.pm
##
## Bunch of functions which generate the fully LibGeoDecomp Application.
##
##

package Cactusinterfacing::CreateLibgeodecompApp;

use strict;
use warnings;
use Exporter 'import';
use FindBin qw($RealBin);
use Data::Dumper;
use Cactusinterfacing::Config qw($tab);
use Cactusinterfacing::Utils qw(util_readFile util_writeFile util_cp util_mkdir);
use Cactusinterfacing::Make qw(createLibgeodecompMakefile);
use Cactusinterfacing::CreateCellClass qw(createCellClass);
use Cactusinterfacing::CreateInitializerClass qw(createInitializerClass);
use Cactusinterfacing::ThornList qw(parseThornList);

# exports
our @EXPORT_OK = qw(createLibgeodecompApp);

#
# Build the complete main.cpp.
#
# param:
#  - opt_ref   : ref to option hash
#  - init_class: name of init class
#  - cell_class: name of cell class
#  - out_ref   : ref to an array where to store the complete main.cpp
#
# return:
#  - none, main() will be stored in out_ref
#
sub createMain
{
	my ($opt_ref, $init_class, $cell_class, $out_ref) = @_;
	my ($mpi);

	# init
	$mpi = $opt_ref->{"mpi"};

	# build main.cpp
	push(@$out_ref, "#include <iostream>\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "#include \"init.h\"\n");
	push(@$out_ref, "#include \"parparser.h\"\n");
	push(@$out_ref, "#include \"selectors.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "static void prepareSimulation(char *argv[])\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, $tab."ParParser parser(argv[1]);\n");
	push(@$out_ref, $tab."parser.parse();\n");
	push(@$out_ref, $tab."CactusGrid *cctkGH = parser.getCctkGH();\n");
	push(@$out_ref, "#ifdef DEBUG\n");
	push(@$out_ref, $tab."cctkGH->dumpCctkGH();\n");
	push(@$out_ref, "#endif\n");
	push(@$out_ref, $tab."// set cctkGH pointer to cell/init class\n");
	push(@$out_ref, $tab.$cell_class."::cctkGH = cctkGH;\n");
	push(@$out_ref, $tab.$init_class."::cctkGH = cctkGH;\n");
	push(@$out_ref, $tab."return;\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "static void cleanup()\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, $tab."// free cactus grid hierarchy\n");
	push(@$out_ref, $tab."delete ".$cell_class."::cctkGH;\n");
	push(@$out_ref, $tab."return;\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");
	createRunSimulation($opt_ref, $init_class, $cell_class, $out_ref);
	push(@$out_ref, "\n");
	push(@$out_ref, "int main(int argc, char** argv)\n");
	push(@$out_ref, "{\n");
	if ($mpi) {
		push(@$out_ref, $tab."MPI_Init(&argc, &argv);\n");
		push(@$out_ref, $tab."LibGeoDecomp::Typemaps::initializeMaps();\n");
	}
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."prepareSimulation(argv);\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."runSimulation();\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."cleanup();\n");
	push(@$out_ref, "\n");
	if ($mpi) {
		push(@$out_ref, $tab."MPI_Finalize();\n");
	}
	push(@$out_ref, $tab."return 0;\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");

	return;
}

#
# Build a runSimulation function.
#
# param:
#  - opt_ref   : ref to options hash
#  - init_class: name of init class
#  - cell_class: name of cell class
#  - out_ref   : ref to store runSimulation function
#
# return:
#  - none, runSimulation function will be stored in out_ref
#
sub createRunSimulation
{
	my ($opt_ref, $init_class, $cell_class, $out_ref) = @_;
	my ($mpi);

	# init
	$mpi = $opt_ref->{"mpi"};

	push(@$out_ref, "static void runSimulation()\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, $tab."int outputFrequency = 1;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."$init_class *init = new $init_class();\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."SerialSimulator<$cell_class> sim(init);\n");
	if (!$mpi) {
		push(@$out_ref, $tab."sim.addWriter(new TracingWriter<$cell_class>(outputFrequency, init->maxSteps()));\n");
	} else {
		push(@$out_ref, $tab."if (MPILayer().rank() == 0) {\n");
		push(@$out_ref, $tab.$tab."sim.addWriter(new TracingWriter<$cell_class>(outputFrequency, init->maxSteps()));\n");
		push(@$out_ref, $tab."}\n");
	}
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."sim.run();\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");

	return;
}

#
# Create the header where the parameter macros are stored
# for the parparser.
#
# param:
#  - name    : name of file (mostly parameters)
#  - init_ref: ref to init data hash
#  - cell_ref: ref to cell data hash
#  - out_ref : ref to array where to store lines of parameters.h
#
# return:
#  - none, lines of parameters.h will be stored in out_ref
#
sub createParameterHeader
{
	my ($name, $init_ref, $cell_ref, $out_ref) = @_;
	my ($dim, $init_class_name, $cell_class_name);

	# init
	$dim             = $cell_ref->{"dim"};
	$init_class_name = $init_ref->{"class_name"};
	$cell_class_name = $cell_ref->{"class_name"};

	# create header
	push(@$out_ref, "#ifndef _\U$name\E_H_\n");
	push(@$out_ref, "#define _\U$name\E_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#define CCTKGHDIM $dim\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#define SETUPTHORNPARAMETERS \\\n");
	push(@$out_ref, $tab."do { \\\n");
	push(@$out_ref, $tab.$tab."SETUP\U$cell_class_name\EPARAMETERS; \\\n");
	push(@$out_ref, $tab.$tab."SETUP\U$init_class_name\EPARAMETERS; \\\n");
	push(@$out_ref, $tab."} while (0)\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $_) for (@{$cell_ref->{"param_macro"}});
	push(@$out_ref, "\n");
	push(@$out_ref, $_) for (@{$init_ref->{"param_macro"}});
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* _\U$name\E_H_ */\n");

	return;
}

#
# This function sets up the include directory. It creates
# it if it doesn't exist. It constructs three header files
# which contain the specific macros for cell and init class.
# At last it copies the definethisthorn header files into
# the include directory.
#
# param:
#  - init_ref  : ref to init data hash
#  - cell_ref  : ref to cell data hash
#  - config_ref: ref to config data hash
#  - outputdir : output directory
#
# return:
#  - none, exits on error, just because this function is
#    essentiell
#
sub setupIncludeDir
{
	my ($init_ref, $cell_ref, $config_ref, $outputdir) = @_;
	my (@cell, @cell_undef, @init);
	my ($cell_name, $cell_undef_name, $init_name);

	# init
	$cell_name       = "cctk_".$cell_ref->{"class_name"}.".h";
	$cell_undef_name = "cctk_".$cell_ref->{"class_name"}."_undef.h";
	$init_name       = "cctk_".$init_ref->{"class_name"}.".h";
	$outputdir      .= "/include";

	# mkdir include
	util_mkdir($outputdir) if (! -d "$outputdir");

	# generate header
	push(@cell, "#ifndef _CCTK_\U$cell_ref->{\"class_name\"}\E_H\n");
	push(@cell, "#define _CCTK_\U$cell_ref->{\"class_name\"}\E_H\n");
	push(@cell, "\n");
	push(@cell, "/* This file is completely autogenerated, do not modify! */\n");
	push(@cell, "\n");
	push(@cell, "#include \"definethisthorn_$cell_ref->{\"class_name\"}.h\"\n");
	push(@cell, "\n");
	push(@cell, $_) for (@{$cell_ref->{"inf_macros"}});
	push(@cell, $_) for (@{$cell_ref->{"special_macros"}});
	push(@cell, "\n");
	push(@cell, "#endif /* _CCTK_\U$cell_ref->{\"class_name\"}\E_H */\n");
	push(@cell_undef, "#ifndef _CCTK_\U$cell_ref->{\"class_name\"}_undef\E_H\n");
	push(@cell_undef, "#define _CCTK_\U$cell_ref->{\"class_name\"}_undef\E_H\n");
	push(@cell_undef, "\n");
	push(@cell_undef, "/* This file is completely autogenerated, do not modify! */\n");
	push(@cell_undef, "\n");
	push(@cell_undef, $_) for (@{$cell_ref->{"inf_macros_undef"}});
	push(@cell_undef, $_) for (@{$cell_ref->{"special_macros_undef"}});
	push(@cell_undef, "#undef DEFINE_THIS_THORN_H\n");
	push(@cell_undef, "#undef CCTK_THORN\n");
	push(@cell_undef, "#undef CCTK_THORNSTRING\n");
	push(@cell_undef, "#undef CCTK_ARRANGEMENT\n");
	push(@cell_undef, "#undef CCTK_ARRANGEMENTSTRING\n");
	push(@cell_undef, "\n");
	push(@cell_undef, "#endif /* _CCTK_\U$cell_ref->{\"class_name\"}_undef\E_H */\n");
	push(@init, "#ifndef _CCTK_\U$init_ref->{\"class_name\"}\E_H\n");
	push(@init, "#define _CCTK_\U$init_ref->{\"class_name\"}\E_H\n");
	push(@init, "\n");
	push(@init, "/* This file is completely autogenerated, do not modify! */\n");
	push(@init, "\n");
	push(@init, "#include \"definethisthorn_$init_ref->{\"class_name\"}.h\"\n");
	push(@init, "\n");
	push(@init, $_) for (@{$init_ref->{"read_macro"}});
	push(@init, "\n");
	push(@init, $_) for (@{$init_ref->{"write_macro"}});
	push(@init, "\n");
	push(@init, $_) for (@{$init_ref->{"write_member"}});
	push(@init, "\n");
	push(@init, $_) for (@{$init_ref->{"special_macros"}});
	push(@init, "\n");
	push(@init, "#endif /* _CCTK_\U$init_ref->{\"class_name\"}\E_H */\n");

	# wite header
	util_writeFile(\@cell, $outputdir."/$cell_name");
	util_writeFile(\@cell_undef, $outputdir."/$cell_undef_name");
	util_writeFile(\@init, $outputdir."/$init_name");

	# copy definethisthorns header
	util_cp($config_ref->{"config_dir"}."/bindings/include/".
			$config_ref->{"evol_thorn"}."/definethisthorn.h",
			$outputdir."/definethisthorn_$cell_ref->{\"class_name\"}.h");
	util_cp($config_ref->{"config_dir"}."/bindings/include/".
			$config_ref->{"init_thorn"}."/definethisthorn.h",
			$outputdir."/definethisthorn_$init_ref->{\"class_name\"}.h");

	return;
}

#
# Main entry point.
# This function creates a complete libgeodecomp application.
# including:
#  - cell class
#  - init class
#  - main.cpp
#  - Makefile
# into directory ./$config
#
# param:
#  - config_ref: ref to config hash
#
# return:
#  - none
#
sub createLibgeodecompApp
{
	my ($config_ref) = @_;
	my ($outputdir, $init_class, $cell_class);
	my (%option, %thorninfo);
	my (%cell, %init, @main, @make, @paramh);

	# init
	$outputdir = "./".$config_ref->{"config"};
	parseThornList($config_ref, \%thorninfo, \%option);

	# mkdir output directory
	util_mkdir($outputdir) if (! -d $outputdir);

	# gen Makefile and write
	createLibgeodecompMakefile($config_ref, \%option, \@make);
	util_writeFile(\@make, $outputdir."/Makefile");

	# get cell, init
	createCellClass($config_ref, \%thorninfo, \%cell);
	createInitializerClass($config_ref, \%thorninfo, \%cell, \%init);

	# get class names
	$init_class = $init{"class_name"};
	$cell_class = $cell{"class_name"};

	# build main() and parameter header
	createMain(\%option, $init_class, $cell_class, \@main);
	createParameterHeader("parameter", \%init, \%cell, \@paramh);

	# write main, cell, init, parameter, selectors
	util_writeFile(\@main,             $outputdir."/main.cpp");
	util_writeFile(\@paramh,           $outputdir."/parameter.h");
	util_writeFile($cell{"cellcpp"},   $outputdir."/cell.cpp");
	util_writeFile($cell{"cellh"},     $outputdir."/cell.h");
	util_writeFile($init{"initcpp"},   $outputdir."/init.cpp");
	util_writeFile($init{"inith"},     $outputdir."/init.h");
	util_writeFile($cell{"selectors"}, $outputdir."/selectors.h");

	# setup include dir
	setupIncludeDir(\%init, \%cell, $config_ref, $outputdir);

	# copy cctk_*, parser files
	util_cp("$RealBin/src/include/*.h", $outputdir."/include");
	util_cp("$RealBin/src/parparser/parparser.h",   $outputdir);
	util_cp("$RealBin/src/parparser/parparser.cpp", $outputdir);
	util_cp("$RealBin/src/types/cactusgrid.h",      $outputdir);
	util_cp("$RealBin/src/types/cactusgrid.cpp",    $outputdir);

	return;
}

1;
