##
## CreateLibgeodecompApp.pm
##
## This module builds the complete LibGeoDecomp application.
## All classes like cell, initializer will be made up and written to disk.
##
##

package Cactusinterfacing::CreateLibgeodecompApp;

use strict;
use warnings;
use Exporter 'import';
use FindBin qw($RealBin);
use Cactusinterfacing::Config qw(%cinf_config);
use Cactusinterfacing::Utils qw(util_readFile util_writeFile util_cp util_mkdir
								util_tidySrcDir _err util_rmdir);
use Cactusinterfacing::Make qw(createLibgeodecompMakefile);
use Cactusinterfacing::CreateCellClass qw(createCellClass);
use Cactusinterfacing::CreateInitializerClass qw(createInitializerClass);
use Cactusinterfacing::Libgeodecomp qw(buildCctkSteerer getBOVWriter
									   getVisItWriter);
use Cactusinterfacing::ThornList qw(parseThornList);

# exports
our @EXPORT_OK = qw(createLibgeodecompApp);

# tab
my $tab = $cinf_config{"tab"};

#
# Builds the complete main.cpp.
#
# param:
#  - opt_ref  : ref to option hash
#  - bov_ref  : ref to bov writer array
#  - visit_ref: ref to visit writer array
#  - init_ref : ref to init hash
#  - cell_ref : ref to cell hash
#  - out_ref  : ref to an array where to store the complete main.cpp
#
# return:
#  - none, main() will be stored in out_ref
#
sub createMain
{
	my ($opt_ref, $bov_ref, $visit_ref, $init_ref, $cell_ref, $out_ref) = @_;
	my ($mpi, $cell_class);

	# init
	$mpi        = $opt_ref->{"mpi"};
	$cell_class = $cell_ref->{"class_name"};

	# build main.cpp
	push(@$out_ref, "#include <iostream>\n");
	push(@$out_ref, "#include <libgeodecomp.h>\n");
	push(@$out_ref, "#include <libgeodecomp/io/bovwriter.h>\n") if ($mpi);
	push(@$out_ref, "#include <libgeodecomp/io/serialbovwriter.h>\n") if (!$mpi);
	push(@$out_ref, "#include <libgeodecomp/io/visitwriter.h>\n");
	push(@$out_ref, "#include \"cell.h\"\n");
	push(@$out_ref, "#include \"init.h\"\n");
	push(@$out_ref, "#include \"parparser.h\"\n");
	push(@$out_ref, "#include \"cctksteerer.h\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "using namespace LibGeoDecomp;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "static void cleanup()\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, $tab."// free cactus grid hierarchy\n");
	push(@$out_ref, $tab."delete ".$cell_class."::staticData.cctkGH;\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");
	createRunSimulation($opt_ref, $bov_ref, $visit_ref, $init_ref, $cell_ref, $out_ref);
	push(@$out_ref, "\n");
	push(@$out_ref, "int main(int argc, char** argv)\n");
	push(@$out_ref, "{\n");
	if ($mpi) {
		push(@$out_ref, $tab."MPI_Init(&argc, &argv);\n");
		push(@$out_ref, "\n");
	}
	push(@$out_ref, $tab."runSimulation(argv[1]);\n");
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
# Builds a runSimulation function.
#
# param:
#  - opt_ref  : ref to options hash
#  - bov_ref  : ref to bov writer array
#  - visit_ref: ref to visit writer array
#  - init_ref : ref to init hash
#  - cell_ref : ref to cell hash
#  - out_ref  : ref to store runSimulation function
#
# return:
#  - none, runSimulation function will be stored in out_ref
#
sub createRunSimulation
{
	my ($opt_ref, $bov_ref, $visit_ref, $init_ref, $cell_ref, $out_ref) = @_;
	my ($mpi, $dim, $init_class, $cell_class, $static_pointer);

	# init
	$mpi            = $opt_ref->{"mpi"};
	$dim            = $cell_ref->{"dim"};
	$init_class     = $init_ref->{"class_name"};
	$cell_class     = $cell_ref->{"class_name"};
	$static_pointer = "&" . $cell_class . "::staticData";

	push(@$out_ref, "static void runSimulation(const char *paramFile)\n");
	push(@$out_ref, "{\n");
	push(@$out_ref, $tab."ParParser parser(paramFile);\n");
	push(@$out_ref, $tab."parser.parse();\n");
	push(@$out_ref, $tab."int outputFrequency = parser.Hdf5Out();\n");
	push(@$out_ref, $tab."CactusGrid *cctkGH = parser.getCctkGH();\n");
	push(@$out_ref, $tab."// set cctkGH pointer to cell/init class\n");
	push(@$out_ref, $tab.$cell_class."::staticData.cctkGH = cctkGH;\n");
	push(@$out_ref, $tab.$init_class."::cctkGH = cctkGH;\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."$init_class *init = new $init_class(parser.itMax());\n");
	push(@$out_ref, $tab."CctkSteerer *steerer = new CctkSteerer($static_pointer);\n");
	push(@$out_ref, "\n");

	# switch simulator
	if ($mpi) {
		push(@$out_ref, $tab."HiParSimulator::HiParSimulator<$cell_class, RecursiveBisectionPartition<$dim> > sim(init);\n");
	} else {
		push(@$out_ref, $tab."SerialSimulator<$cell_class> sim(init);\n");
	}

	# first add a tracing writer for every simulation
	if (!$mpi) {
		push(@$out_ref, $tab."sim.addWriter(new TracingWriter<$cell_class>(outputFrequency, init->maxSteps()));\n");
	} else {
		push(@$out_ref, $tab."if (MPILayer().rank() == 0)\n");
		push(@$out_ref, $tab.$tab."sim.addWriter(new TracingWriter<$cell_class>(outputFrequency, init->maxSteps()));\n");
	}

	# add bov writers
	push(@$out_ref, $tab."sim.addWriter($_);\n") for (@$bov_ref);

	# add visit writer
	if (@$visit_ref && @$visit_ref > 0) {
		my ($tab_offset);

		$tab_offset = $mpi ? 2 : 1;

		push(@$out_ref, "#ifdef LIBGEODECOMP_WITH_VISIT\n");
		push(@$out_ref, $tab."VisItWriter<$cell_class> *visItWriter = 0;\n");
		push(@$out_ref, $tab."if (MPILayer().rank() == 0) {\n") if ($mpi);
		push(@$out_ref, $tab x $tab_offset.$_) for (@$visit_ref);
		push(@$out_ref, $tab."}\n") if ($mpi);
		push(@$out_ref, $tab."sim.addWriter(visItWriter);\n") if (!$mpi);
		push(@$out_ref, $tab."sim.addWriter(new CollectingWriter<$cell_class>(visItWriter));\n") if ($mpi);
		push(@$out_ref, "#endif\n");
	}

	# add steerer
	push(@$out_ref, $tab."sim.addSteerer(steerer);\n");
	push(@$out_ref, "\n");
	push(@$out_ref, $tab."sim.run();\n");
	push(@$out_ref, "}\n");
	push(@$out_ref, "\n");

	return;
}

#
# Creates the header where the parameter macros are stored
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
	my ($setup_cell, $setup_init, $setup_thorn);

	# init
	$dim             = $cell_ref->{"dim"};
	$init_class_name = $init_ref->{"class_name"};
	$cell_class_name = $cell_ref->{"class_name"};
	# strip _'s
	$init_class_name =~ s/_//g;
	$cell_class_name =~ s/_//g;
	# build macro names
	$setup_init  = "_SETUP_\U$init_class_name\E_PARAMETERS";
	$setup_cell  = "_SETUP_\U$cell_class_name\E_PARAMETERS";
	$setup_thorn = "SETUPTHORNPARAMETERS";

	# create header
	push(@$out_ref, "#ifndef _\U$name\E_H_\n");
	push(@$out_ref, "#define _\U$name\E_H_\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "/* This file is completely autogenerated, do not modify! */\n");
	push(@$out_ref, "\n");
	# actually it's good to know the dimension and width of ghostzones
	push(@$out_ref, "#define CCTKGHDIM $dim\n");
	push(@$out_ref, "#define GHOSTZONEWIDTH $cinf_config{\"ghostzone_width\"}\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#define $setup_thorn \\\n");
	push(@$out_ref, $tab."do { \\\n");
	push(@$out_ref, $tab.$tab."$setup_init; \\\n");
	push(@$out_ref, $tab.$tab."$setup_cell; \\\n");
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
# Creates a definethisthorn header file for cell or initializer class.
# FIXME: "#define THORN_IS_$thornname 1" is missing.
#
# param:
#  - config : name of configuration
#  - type   : either "Cell" or "Initializer"
#  - out_ref: ref to array where to store resulting header file
#
# return:
#  - none, resulting file will be stored in out_ref
#
sub createDefineHeader
{
	my ($config, $type, $out_ref) = @_;

	# check type
	$type = "Cell" unless ($type || $type eq "Cell" || $type eq "Initializer");

	# create actual header file
	push(@$out_ref, "#ifndef DEFINE_THIS_THORN_H\n");
	push(@$out_ref, "#define DEFINE_THIS_THORN_H\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "/* This file is completely autogenerated, do not modify! */\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#define CCTK_THORN $type\n");
	push(@$out_ref, "#define CCTK_THORNSTRING \"$type\"\n");
	push(@$out_ref, "#define CCTK_ARRANGEMENT $config\n");
	push(@$out_ref, "#define CCTK_ARRANGEMENTSTRING \"$config\"\n");
	push(@$out_ref, "\n");
	push(@$out_ref, "#endif /* DEFINE_THIS_THORN_H */\n");

	# done
	return;
}

#
# This function sets up the include directory. It creates
# it if it doesn't exist. It constructs three header files
# which contain the specific macros for cell and init classes.
# At last it creates the definethisthorn header files and
# writes them into the include directory.
#
# param:
#  - init_ref  : ref to init data hash
#  - cell_ref  : ref to cell data hash
#  - config_ref: ref to config data hash
#  - outputdir : output directory
#
# return:
#  - none, exits on error, just because this function is essentiell
#
sub setupIncludeDir
{
	my ($init_ref, $cell_ref, $config_ref, $outputdir) = @_;
	my (@cell, @cell_undef, @init, @paramh, @cell_thorndef, @init_thorndef);
	my ($cell_name, $cell_undef_name, $init_name);

	# init
	$cell_name       = "cctk_" . $cell_ref->{"class_name"} . ".h";
	$cell_undef_name = "cctk_" . $cell_ref->{"class_name"} . "_undef.h";
	$init_name       = "cctk_" . $init_ref->{"class_name"} . ".h";
	$outputdir      .= "/include";

	# create directory for cctk_ header files
	util_mkdir($outputdir) unless (-d $outputdir);

	# build parameter header
	createParameterHeader("parameter", $init_ref, $cell_ref, \@paramh);

	# build definethisthorn header
	createDefineHeader($config_ref->{"config"}, "Cell", \@cell_thorndef);
	createDefineHeader($config_ref->{"config"}, "Initializer", \@init_thorndef);

	# generate header
	push(@cell, "#ifndef _CCTK_\U$cell_ref->{\"class_name\"}\E_H\n");
	push(@cell, "#define _CCTK_\U$cell_ref->{\"class_name\"}\E_H\n");
	push(@cell, "\n");
	push(@cell, "/* This file is completely autogenerated, do not modify! */\n");
	push(@cell, "\n");
	push(@cell, "#include \"definethisthorn_Cell.h\"\n");
	push(@cell, "\n");
	push(@cell, $_) for (@{$cell_ref->{"special_macros"}});
	push(@cell, "\n");
	push(@cell, "#endif /* _CCTK_\U$cell_ref->{\"class_name\"}\E_H */\n");
	push(@cell_undef, "#ifndef _CCTK_\U$cell_ref->{\"class_name\"}_undef\E_H\n");
	push(@cell_undef, "#define _CCTK_\U$cell_ref->{\"class_name\"}_undef\E_H\n");
	push(@cell_undef, "\n");
	push(@cell_undef, "/* This file is completely autogenerated, do not modify! */\n");
	push(@cell_undef, "\n");
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
	push(@init, "#include \"definethisthorn_Initializer.h\"\n");
	push(@init, "\n");
	push(@init, $_) for (@{$init_ref->{"special_macros"}});
	push(@init, "\n");
	push(@init, "#endif /* _CCTK_\U$init_ref->{\"class_name\"}\E_H */\n");

	# write header
	util_writeFile(\@paramh,        $outputdir . "/parameter.h");
	util_writeFile(\@cell,          $outputdir . "/$cell_name");
	util_writeFile(\@cell_undef,    $outputdir . "/$cell_undef_name");
	util_writeFile(\@init,          $outputdir . "/$init_name");
	util_writeFile(\@cell_thorndef, $outputdir . "/definethisthorn_Cell.h");
	util_writeFile(\@init_thorndef, $outputdir . "/definethisthorn_Initializer.h");

	return;
}

#
# Main entry point.
# This function creates a complete LibGeoDecomp application.
# including:
#  - cell class
#  - init class
#  - selector classes
#  - static data class
#  - parameter parser class
#  - lots of include files which contain macros
#  - main.cpp
#  - Makefile
# into directory ./$config where $config is the name of the cactus configuration.
# The output directory is configurable by config_ref, key is "outputdir".
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
	my ($outputdir, $mpi, $writer_type);
	my (%option, %thorninfo);
	my (%cell, %init, @main, @make, @cctksteerer, @bovwriter, @visitwriter);

	# init
	parseThornList($config_ref, \%thorninfo, \%option);
	$outputdir   = $config_ref->{"outputdir"} . "/" . $config_ref->{"config"};
	$mpi         = $option{"mpi"};
	$writer_type = $mpi ? "normal" : "serial";

	# create directory where to store code, delete it first
	util_rmdir($outputdir) if     (-d $outputdir);
	util_mkdir($outputdir) unless (-d $outputdir);

	# gen Makefile and write
	createLibgeodecompMakefile($config_ref, \%option, \@make);
	util_writeFile(\@make, $outputdir."/Makefile");

	# get cell, init, writers
	createCellClass($config_ref, \%thorninfo, \%option, \%cell);
	createInitializerClass($config_ref, \%thorninfo, \%cell, \%init);
	buildCctkSteerer($cell{"class_name"}, $cell{"static_data_class"}{"class_name"},
					 \@cctksteerer);
	getBOVWriter($cell{"inf_data"}, $cell{"class_name"}, $writer_type, \@bovwriter);
	getVisItWriter($cell{"inf_data"}, $cell{"class_name"}, \@visitwriter);

	# build main()
	createMain(\%option, \@bovwriter, \@visitwriter, \%init, \%cell, \@main);

	# write main, cell, init, selectors, static data class and steerer
	util_writeFile(\@main,                 $outputdir."/main.cpp");
	util_writeFile($cell{"cellcpp"},       $outputdir."/cell.cpp");
	util_writeFile($cell{"cellh"},         $outputdir."/cell.h");
	util_writeFile($init{"initcpp"},       $outputdir."/init.cpp");
	util_writeFile($init{"inith"},         $outputdir."/init.h");
	util_writeFile($cell{"static_data_class"}{"statich"}, $outputdir."/staticdata.h");
	util_writeFile(\@cctksteerer,          $outputdir."/cctksteerer.h");

	# setup include dir
	setupIncludeDir(\%init, \%cell, $config_ref, $outputdir);

	# copy cctk_*, parser files and types
	util_cp("$RealBin/src/include/*.h", $outputdir."/include");
	util_cp("$RealBin/src/parparser/parparser.h",   $outputdir);
	util_cp("$RealBin/src/parparser/parparser.cpp", $outputdir);
	util_cp("$RealBin/src/types/cactusgrid.h",      $outputdir);
	util_cp("$RealBin/src/types/cactusgrid.cpp",    $outputdir);
	util_cp("$RealBin/src/vector/vector.h",         $outputdir)
		if ($cinf_config{"use_vectorization"});

	# tidy source code
	util_tidySrcDir($outputdir);

	return;
}

1;
