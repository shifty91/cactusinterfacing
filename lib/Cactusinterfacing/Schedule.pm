
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
#  - methods at CCTK_INITIAL
#  - methods at CCTK_EVOL
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
	my (@indata, @schedule_data, %data, @evol_funcs, @init_funcs);
	my ($i, $nblocks);

	# parse schedule.ccl
	@indata          = read_file("$thorndir/schedule.ccl");
	@schedule_data   = parse_schedule_ccl($thorn, @indata);
	util_arrayToHash(\@schedule_data, \%data);

	$nblocks = $data{"\U$thorn n_blocks"};

	for ($i = 0; $i < $nblocks; $i++) {
		# only functions
		next if ($data{"\U$thorn block_$i type"} ne "FUNCTION");
		# only functions that sync someting
		#next if ($data{"\U$thorn block_$i sync"} eq "");
		# only functions written in C/C++, Fortran is not supported
		next if ($data{"\U$thorn block_$i lang"} ne "C");

		if ($data{"\U$thorn block_$i where"} eq "CCTK_EVOL") {
			push(@evol_funcs, $data{"\U$thorn block_$i name"});
		} elsif ($data{"\U$thorn block_$i where"} eq "CCTK_INITIAL") {
			push(@init_funcs, $data{"\U$thorn block_$i name"});
		}
	}

	# store data
	$out_ref->{"CCTK_EVOL"}    = \@evol_funcs;
	$out_ref->{"CCTK_INITIAL"} = \@init_funcs;

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
	my (%schedule_data);
	my ($func, $nfuncs);
	my (@sources, @func);

	# parse schedule.ccl
	getScheduleData($thorndir, $thorn, \%schedule_data);
	# number of functions found
	$nfuncs = @{$schedule_data{"\U$timestep\E"}};

	# check if we found an appropriate function
	if ($nfuncs <= 0) {
		_warn("No function found at \U$timestep\E Timestep.", __FILE__,
				__LINE__);
		push(@func, "/** No function found at \U$timestep\E **/");
		goto out;
	} elsif ($nfuncs > 1) {
		# user has to choose one function
		$func = util_choose("$nfuncs functions found at \U$timestep\E Timestep." .
							" Choose one", $schedule_data{"\U$timestep\E"});
	} else {
		# only one function found, take this one
		$func = $schedule_data{"\U$timestep\E"}[0];
	}

	# search in source files to find this function
	# just have a look at make.code.defn
	getSources($thorndir."/src", \@sources);

	# check if some sources where found
	if (@sources == 0) {
		_warn("Could not find any source files. Check your make.code.defn.",
			  __FILE__, __LINE__);
		push(@func, "/** No sources found! **/");
		goto out;
	}

	foreach my $source (@sources) {
		util_getFunction($source, $func, \@func);

		# lets see, if function was found
		goto out if (@func > 0);
	}

	# at this point the scheduled function could not be found in
	# any source file
	_warn("The scheduled function could not be found. Check your make.code.defn.",
			__FILE__, __LINE__);
	push(@func, "/** No function found at \U$timestep\E **/");

 out:
	# save
	$val_ref->{"\L$timestep\E_arr"} = \@func;

	return;
}

1;
