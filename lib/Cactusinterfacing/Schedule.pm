##
## Schedule.pm
##
## Contains routines to get schedule data.
##

package Cactusinterfacing::Schedule;

use strict;
use warnings;
use Exporter 'import';
use Storable 'dclone';
use Tie::IxHash;
use Cactusinterfacing::Utils qw(read_file util_arrayToHash util_getFunction
								_warn util_choose util_chooseMulti);
use Cactusinterfacing::Make qw(getSources);
use Cactusinterfacing::ScheduleParser qw(parse_schedule_ccl);

# exports
our @EXPORT_OK = qw(getScheduleData
					getEvolFunction getEvolFunctions
					getInitFunction getInitFunctions);

#
# Parse the schedule.ccl.
# Store important information into a hash, including:
#  - methods at CCTK_INITIAL and CCTK_EVOL
#  - synonyms
#  - after and before information
#  - thorndir to find the function
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
		$out_ref->{$name}{"thorndir"} = $thorndir;
	}

	return;
}

#
# Wrapper function for getFunctionsAt.
# Cactus timestep is CCTK_EVOL to get the evolution function.
#
# param:
#  - sched_ref: ref to schedule data hash
#  - out_ref  : ref to hash where to store function
#
# return:
#  - none, function will be store in out_ref
#
sub getEvolFunction
{
	my ($sched_ref, $out_ref) = @_;
	my (%funcs);

	getFunctionsAt($sched_ref, "CCTK_EVOL", "single", \%funcs);

	foreach my $key (keys %funcs) {
		$out_ref->{$key} = $funcs{$key};
		last;
	}

	return;
}

#
# Wrapper function for getFunctionsAt.
# Cactus timestep is CCTK_EVOL to get the evolution functions.
#
# param:
#  - sched_ref: ref to schedule data hash
#  - out_ref  : ref to hash where to store functions
#
# return:
#  - none, functions will be store in out_ref
#
sub getEvolFunctions
{
	my ($sched_ref, $out_ref) = @_;

	getFunctionsAt($sched_ref, "CCTK_EVOL", "multi", $out_ref);

	return;
}

#
# Wrapper function for getFunctionsAt.
# Cactus timestep is CCTK_INITIAL to get the init function.
#
# param:
#  - sched_ref: ref to schedule data hash
#  - out_ref  : ref to hash where to store functions
#
# return:
#  - none, function will be store in out_ref
#
sub getInitFunction
{
	my ($sched_ref, $out_ref) = @_;
	my (%funcs);

	getFunctionsAt($sched_ref, "CCTK_INITIAL", "single", \%funcs);

	foreach my $key (keys %funcs) {
		$out_ref->{$key} = $funcs{$key};
		last;
	}

	return;
}

#
# Wrapper function for getFunctionsAt.
# Cactus timestep is CCTK_INITIAL to get the init functions.
#
# param:
#  - sched_ref: ref to schedule data hash
#  - out_ref  : ref to hash where to store functions
#
# return:
#  - none, functions will be store in out_ref
#
sub getInitFunctions
{
	my ($sched_ref, $out_ref) = @_;

	getFunctionsAt($sched_ref, "CCTK_INITIAL", "multi", $out_ref);

	return;
}

#
# Gatheres functions at a specific cactus timestep.
# This function searches through all source files of the
# given thorn(s) to find the searched functions.
#
# param:
#  - sched_ref: ref to schedule data hash
#  - timestep : cactus timestep (e.g. CCTK_EVOL for evolution)
#  - type     : maybe "single" or "multi" to indicate whether to get one
#               or multiple functions
#  - out_ref  : ref to hash where to store function(s)
#
# return:
#  - none, function(s) will be stored in out_ref
#
sub getFunctionsAt
{
	my ($sched_ref, $timestep, $type, $out_ref) = @_;
	my (@thorndirs, %nodes, @functions, @sources, $nfuncs);

	# prepare arguments
	tie %{$out_ref}, 'Tie::IxHash';
	$timestep = "\U$timestep\E";

	# get an array of functions at the specific timestep in right order
	prepareDAG(\%nodes, $sched_ref, $timestep);
	sortDAG(\%nodes, \@functions);

	# get directories of all thorns
	uniqThornDirs($sched_ref, \@thorndirs);

	# number of functions found
	$nfuncs = @functions;

	# check if we found an appropriate function
	if ($nfuncs <= 0) {
		_warn("No function found at \U$timestep\E Timestep.");
		goto fail;
	} elsif ($nfuncs > 1) {
		# user has to choose functions
		chooseFunctions($type, $timestep, \@functions);
	}

	# search in source files to find the functions
	# just have a look at make.code.defn
	getSources($_ . "/src", \@sources) for (@thorndirs);

	# check if some sources where found
	if (@sources == 0) {
		_warn("Could not find any source files. Check your make.code.defn.");
		goto fail;
	}

	# get functions
	foreach my $func (@functions) {
		my (@code_func, $found);

		$found = 0;
		foreach my $source (@sources) {
			if (util_getFunction($source, $func, \@code_func)) {
				$out_ref->{$func}{"name"} = $func;
				$out_ref->{$func}{"data"} = \@code_func;
				$found = 1;
				last;
			}
		}

		if (!$found) {
			# the scheduled function could not be found in any source file
			_warn("The scheduled function could not be found. Check your make.code.defn.");
			$out_ref->{$func}{"name"} = $func;
			$out_ref->{$func}{"data"} = [ "/** No function found at \U$timestep\E timestep **/" ];
		}
	}

	return;

 fail:
	# no function found
	$out_ref->{"dummyFunction"}{"name"} = "dummyFunction";
	$out_ref->{"dummyFunction"}{"data"} = [ "/** No function found at \U$timestep\E timestep or no source files found **/" ];

	return;
}

#
# This function goes through the functions passed by sched_ref and
# stores a array of all thorndirs (unique).
#
# param:
#  - sched_ref: ref to schedule data hash
#  - out_ref  : ref to array where to store the unique thorndirs
#
# return:
#  - none, result will be stored in out_ref
#
sub uniqThornDirs
{
	my ($sched_ref, $out_ref) = @_;
	my (%seen);

	foreach my $func (keys %{$sched_ref}) {
		push(@$out_ref, $sched_ref->{$func}{"thorndir"});
	}

	# filter duplicates
	@{$out_ref} = grep { !$seen{$_}++ } @{$out_ref};

	return;
}

#
# This function chooses one or more functions depending on type.
#
# param:
#  - type    : "single" or "multi"
#  - timestep: timestep of functions
#  - func_ref: ref to function names array
#
# return:
#  - none, choosed functions will be stored in func_ref
#
sub chooseFunctions
{
	my ($type, $timestep, $func_ref) = @_;
	my ($nfuncs);

	$type   = "single" unless ($type || $type =~ /^single$/i || $type =~ /^multi$/i);
	$nfuncs = @$func_ref;

	if ($type =~ /^single$/i) {
		my ($function);

		$function = util_choose("$nfuncs functions found at \U$timestep\E Timestep.".
								" Choose one", $func_ref);
		@$func_ref = ( $function );
	} else {
		@$func_ref = util_chooseMulti("$nfuncs functions found at \U$timestep\E Timestep.".
									   " Choose some", $func_ref);
	}

	return;
}

#
# Returns the real name of the aliased function.
# If more than one function is found ('cause two thorns implement
# same interface), the first will be returned and warning will
# be displayed.
#
# param:
#  - alias   : the alias name of the function
#  - data_ref: ref to schedule data hash
#
# return:
#  - the real name of the aliased function
#
sub alias2RealName
{
	my ($alias, $data_ref) = @_;
	my ($real_name);

	$real_name = "";
	foreach my $function (keys %{$data_ref}) {
		if ($data_ref->{$function}{"as"} eq $alias) {
			_warn("Multiple functions found alias \"$alias\". Using the first one found.")
				unless ($real_name eq "");
			$real_name = $function;
		}
	}

	_err("Cannot find a real name for aliased function \"$alias\".")
		if ($real_name eq "");

	return $real_name;
}

#
# Returns the alias for a given function.
#
# param:
#  - real_name: name of the function
#  - data_ref : ref to schedule data hash
#
# return:
#  - the alias for the given function
#
sub realName2Alias
{
	my ($real_name, $data_ref) = @_;
	my ($alias);

	$alias = "";
	foreach my $function (keys %{$data_ref}) {
		if ($function eq $real_name) {
			_err("Found two or more aliases for the same function \"$real_name\". ".
				 "Something went wrong.") unless ($alias eq "");
			$alias = $data_ref->{$function}{"as"};
		}
	}

	_err("Cannot find a alias for function \"$real_name\".")
		if ($alias eq "");

	return $alias;
}

#
# Checks whether a symbol is a function.
#
# param:
#  - symbol  : symbol of function
#  - data_ref: ref to schedule data hash
#
# return:
#  - true if symbol is a name of a function
#
sub isFunction
{
	my ($symbol, $data_ref) = @_;

	foreach my $function (keys %{$data_ref}) {
		return 1 if ($function eq $symbol);
	}

	return 0;
}

#
# Checks whether a symbol is a alias.
#
# param:
#  - symbol  : symbol of alias
#  - data_ref: ref to schedule data hash
#
# return:
#  - true if symbol is a alias of a function
#
sub isAlias
{
	my ($symbol, $data_ref) = @_;

	foreach my $function (keys %{$data_ref}) {
		return 1 if ($symbol eq $data_ref->{$function}{"as"});
	}

	return 0;
}

#
# This functions uses the schedule information to create a DAG
# by evaluating the after and before information for a specific
# timestep.
# DAG format: key for hash is the real name of function,
#             every node contains a reference counter and the
#             outgoing nodes
#
# param:
#  - nodes_ref: ref to nodes hash
#  - data_ref : ref to schedule data hash
#  - timestep : timestep to build DAG for
#
# return:
#  - none, DAG will be stored in nodes_ref
#
sub prepareDAG
{
	my ($nodes_ref, $data_ref, $timestep) = @_;

	# first create nodes and set ref counter to zero
	foreach my $function (keys %{$data_ref}) {
		# right timestep?
		next unless ($timestep eq $data_ref->{$function}{"timestep"});
		$nodes_ref->{$function}{"ref_cnt"}   = 0;
		$nodes_ref->{$function}{"out_nodes"} = ();
	}

	return unless (keys %{$nodes_ref});

	# now create DAG by evaluating after and before
	foreach my $function (keys %{$data_ref}) {
		my ($after, $before);

		# init
		$after  = $data_ref->{$function}{"after"};
		$before = $data_ref->{$function}{"before"};

		# parse after
		goto before if ($after eq "");
		goto before if (!isAlias($after, $data_ref) && !isFunction($after, $data_ref));
		$after = isAlias($after, $data_ref) ? alias2RealName($after, $data_ref) : $after;

		$nodes_ref->{$function}{"ref_cnt"} += 1;
		push(@{$nodes_ref->{$after}{"out_nodes"}}, $function);

		# parse before
	before:
		next if ($before eq "");
		next if (!isAlias($before, $data_ref) && !isFunction($before, $data_ref));
		$before = isAlias($before, $data_ref) ? alias2RealName($before, $data_ref) : $before;

		$nodes_ref->{$before}{"ref_cnt"} += 1;
		push(@{$nodes_ref->{$function}{"out_nodes"}}, $before);
	}

	return;
}

#
# This functions sorts the DAG created by prepareDAG.
# Note: nodes_ref will be empty afterwards (maybe change that later on).
#
# param:
#  - nodes_ref: ref to nodes hash, created by prepareDAG
#  - out_ref  : ref to array where the sorted functions will be stored
#
# return:
#  - none, sorted functions will be stored in out_ref
#
sub sortDAG
{
	my ($nodes_ref, $out_ref) = @_;
	my ($deleted, %nodes_cp);

	while (scalar keys %{$nodes_ref} > 0) {
		$deleted = 0;
		# changes to the graph are made on a copy which is rotated after each step
		%nodes_cp = %{ dclone $nodes_ref };
		foreach my $function (keys %{$nodes_ref}) {
			# get nodes with ref counter 0
			if ($nodes_ref->{$function}{"ref_cnt"} == 0) {
				# save
				push(@$out_ref, $function);
				# decr. ref counter of all outgoing nodes
				foreach my $node (@{$nodes_ref->{$function}{"out_nodes"}}) {
					$nodes_cp{$node}{"ref_cnt"} -= 1;
				}
				# delete node
				delete $nodes_cp{$function};
				$deleted = 1;
			}
		}

		# prevent endless loop
		_err("The Graph for the schedule data is cyclic!. Aborting now.")
			unless ($deleted);

		# rotate
		$nodes_ref = \%nodes_cp;
	}

	return;
}

1;
