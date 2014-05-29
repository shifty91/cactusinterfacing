
##
## Schedule.pm
##
## Contains routines to get schedule data.
##

package Cactusinterfacing::Schedule;

use strict;
use warnings;
use Exporter 'import';
use Data::Dumper;
use Cactusinterfacing::Utils qw(read_file util_arrayToHash util_getFunction
								util_indent _warn util_choose);
use Cactusinterfacing::Make qw(getSources);
use Cactusinterfacing::ScheduleParser qw(parse_schedule_ccl);

# exports
our @EXPORT_OK = qw(getScheduleData getEvolFunction getInitFunction);

#
# Parse the schedule.ccl.
# Store important information into a hash, including:
#  - methods at CCTK_INITIAL and CCTK_EVOL
#  - synonyms
#  - after and before information
#
# param:
#  - thorndir: directory of thorn
#  - thorn   : name of thorn
#  - out_ref : ref to hash where to store data
#
# return:
#  - none, data will be stored in out_ref
#
sub getScheduleData
{
	my ($thorndir, $thorn, $out_ref) = @_;
	my (@indata, @schedule_data, %data);
	my ($i, $nblocks);

	# parse schedule.ccl
	@indata        = read_file("$thorndir/schedule.ccl");
	@schedule_data = parse_schedule_ccl($thorn, @indata);
	util_arrayToHash(\@schedule_data, \%data);

	$nblocks = $data{"\U$thorn n_blocks\E"};

	for ($i = 0; $i < $nblocks; ++$i) {
		my ($name, $type, $lang, $after, $before, $where, $as);

		# init data
		$name   = $data{"\U$thorn block_$i name\E"};
		$type   = $data{"\U$thorn block_$i type\E"};
		$lang   = $data{"\U$thorn block_$i lang\E"};
		$after  = $data{"\U$thorn block_$i after\E"};
		$before = $data{"\U$thorn block_$i before\E"};
		$where  = $data{"\U$thorn block_$i where\E"};
		$as     = $data{"\U$thorn block_$i as\E"};

		# only functions
		next unless ($type =~ /FUNCTION/i);
		# only functions written in C/C++, Fortran is not supported
		next unless ($lang =~ /C/i);
		# at the moment only functions at CCTK_EVOL and CCTK_INITIAL timestep
		# are used so far
		next unless ($where =~ /CCTK_EVOL/i || $where =~ /CCTK_INITIAL/i);

		# store important information, assuming the function name as unique
		$out_ref->{$name}{"as"}       = $as;
		$out_ref->{$name}{"after"}    = $after;
		$out_ref->{$name}{"before"}   = $before;
		$out_ref->{$name}{"timestep"} = "\U$where\E";
	}

	return;
}

#
# Wrapper function for getFunctionAt.
# Cactus timestep is CCTK_EVOL to get the evolution function.
#
# param:
#  - thorndir: directory of thorn
#  - thorn   : name of thorn
#  - val_ref : ref to value hash
#
# return:
#  - none, stores array of evol function into value hash, key
#    is "cctk_evol_arr"
#
sub getEvolFunction
{
	my ($thorndir, $thorn, $val_ref) = @_;

	getFunctionAt($thorndir, $thorn, "CCTK_EVOL", $val_ref);

	return;
}

#
# Wrapper function for getFunctionAt.
# Cactus timestep is CCTK_INITIAL to get the init function.
#
# param:
#  - thorndir: directory of thorn
#  - thorn   : name of thorn
#  - val_ref : ref to value hash
#
# return:
#  - none, stores array of init function into value hash, key
#    is "cctk_initial_arr"
#
sub getInitFunction
{
	my ($thorndir, $thorn, $val_ref) = @_;

	getFunctionAt($thorndir, $thorn, "CCTK_INITIAL", $val_ref);

	return;
}

#
# Gatheres a function at a specific cactus timestep.
# This function searches through all source files of the
# given thorn to find the searched function.
#
# param:
#  - thorndir: directory of thorn
#  - thorn   : name of thorn
#  - timestep: cactus timestep (e.g. CCTK_EVOL for evolution)
#  - val_ref : ref to value hash
#
# return:
#  - none, stores array of function into value hash, key
#    is "$timestep_arr"
#
sub getFunctionAt
{
	my ($thorndir, $thorn, $timestep, $val_ref) = @_;
	my (%schedule_data, @functions, @sources, @code_func, $func, $nfuncs);

	# prepare arguments
	$timestep = "\U$timestep\E";

	# parse schedule.ccl
	getScheduleData($thorndir, $thorn, \%schedule_data);

	# get an array of functions at the specific timestep
	foreach my $function (keys %schedule_data) {
		next if ($schedule_data{$function}{"timestep"} ne $timestep);
		push(@functions, $function);
	}

	# number of functions found
	$nfuncs = @functions;

	# check if we found an appropriate function
	if ($nfuncs <= 0) {
		_warn("No function found at \U$timestep\E Timestep.", __FILE__,
			  __LINE__);
		push(@code_func, "/** No function found at \U$timestep\E **/");
		goto out;
	} elsif ($nfuncs > 1) {
		# user has to choose one function
		$func = util_choose("$nfuncs functions found at \U$timestep\E Timestep." .
							" Choose one", \@functions);
	} else {
		# only one function found, take this one
		$func = $functions[0];
	}

	# search in source files to find this function
	# just have a look at make.code.defn
	getSources($thorndir."/src", \@sources);

	# check if some sources where found
	if (@sources == 0) {
		_warn("Could not find any source files. Check your make.code.defn.",
			  __FILE__, __LINE__);
		push(@code_func, "/** No sources found! **/");
		goto out;
	}

	foreach my $source (@sources) {
		util_getFunction($source, $func, \@code_func);

		# lets see, if function was found
		goto out if (@code_func > 0);
	}

	# at this point the scheduled function could not be found in
	# any source file
	_warn("The scheduled function could not be found. Check your make.code.defn.",
		  __FILE__, __LINE__);
	push(@code_func, "/** No function found at \U$timestep\E **/");

 out:
	# save
	$val_ref->{"\L$timestep\E_arr"} = \@code_func;

	return;
}

1;
