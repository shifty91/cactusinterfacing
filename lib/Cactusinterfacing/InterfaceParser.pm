#/*@@
#  @file    interface_parser.pl
#  @date    Wed Sep 16 15:07:11 1998
#  @author  Tom Goodale
#  @desc
#           Parses interface.ccl files
#  @enddesc
#  @version $Header$
#@@*/

##
## InterfaceParser.pm
## taken from Cactus (lib/sbin/interface_parser.pl)
##
## Copright (C) 2013 Kurt Kanzenbach <kurt@kmk-computers.de>
##  - renamed to InterfaceParser.pm
##  - made a perl modul
##  - added use strict, warnings
##  - coding style
##  - removed warnings of uninitialized values by adding checks
##    if these values are defined in parse_interface_ccl
##  - removed unused variables $data, $type, $variable in parse_interface_ccl
##  - removed create_interface_database, cross_index_interface_data,
##    get_friends_of_me, get_implementation_friends, get_implementation_ancestors.
##    check_implementation_consistency, check_interface_consistency,
##    PrintInterfaceStatistics subroutines
##

package Cactusinterfacing::InterfaceParser;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Utils qw(SplitWithStrings CST_error);

# export
our @EXPORT_OK = qw(parse_interface_ccl);


#/*@@
#  @routine    parse_interface_ccl
#  @date       Wed Sep 16 15:07:11 1998
#  @author     Tom Goodale
#  @desc
#  Parses an interface.ccl file and generates a database of the values.
#  @enddesc
#@@*/

sub parse_interface_ccl {
	my ($arrangement, $thorn, $data_ref, $interface_data_ref) = @_;
	my ($line_number, $line, $block, $description);
	my ($message, $hint);
	my ($funcname, $provided_by, $provided_by_language);
	my (@functions, $funcargs);
	my ($rest, $rettype);
	my ($quoted_description);
	my ($header);
	my ($implementation);
	my (%options);
	my (%known_groups);
	my (%known_variables);

	# Initialise some stuff to prevent perl -w from complaining.
	$interface_data_ref->{"\U$thorn INHERITS\E"}          = "";
	$interface_data_ref->{"\U$thorn FRIEND\E"}            = "";
	$interface_data_ref->{"\U$thorn PUBLIC GROUPS\E"}     = "";
	$interface_data_ref->{"\U$thorn PROTECTED GROUPS\E"}  = "";
	$interface_data_ref->{"\U$thorn PRIVATE GROUPS\E"}    = "";
	$interface_data_ref->{"\U$thorn USES HEADER\E"}       = "";
	$interface_data_ref->{"\U$thorn FUNCTIONS\E"}         = "";
	$interface_data_ref->{"\U$thorn PROVIDES FUNCTION\E"} = " ";
	$interface_data_ref->{"\U$thorn REQUIRES FUNCTION\E"} = " ";
	$interface_data_ref->{"\U$thorn USES FUNCTION\E"}     = " ";
	$interface_data_ref->{"\U$thorn ARRANGEMENT\E"}       = "$arrangement";

	# The default block is private.
	$block = "PRIVATE";

	for ($line_number = 0 ; $line_number < @$data_ref ; $line_number++) {
		$line = $data_ref->[$line_number];

		#		Parse the line
		if ($line =~ m/^\s*(PUBLIC|PROTECTED|PRIVATE)\s*$/i) {

			#			It's a new block.
			$block = "\U$1\E";
		} elsif ($line =~ m/^\s*IMPLEMENTS\s*:/i) {
			if ($line =~ m/^\s*IMPLEMENTS\s*:\s*([a-z]+[a-z_0-9]*)\s*$/i) {
				if (!$implementation) {
					$implementation = $1;
					$interface_data_ref->{"\U$thorn\E IMPLEMENTS"} =
					  $implementation;
				} else {
					$message = "Multiple implementations specified in $thorn";
					$hint =
"A thorn can only specify one implementation in its interface.ccl file, with the format implements:<implementation>";
					&CST_error(0, $message, $hint, __LINE__, __FILE__);
				}
			} else {
				$message = "Implementation line has wrong format in $thorn";
				$hint =
"A thorn must specify one implementation in its interface.ccl file with the format IMPLEMENTS: <implementation>";
				&CST_error(0, $message, $hint, __LINE__, __FILE__);
			}
		}

  # implementation names can be separated by ,\s, where , are stripped out below
		elsif ($line =~
m/^\s*(INHERITS|FRIEND)\s*:(([,\s]*[a-zA-Z]+[a-zA-Z_0-9]*)*[,\s]*)$/i
		  )
		{
			$interface_data_ref->{"\U$thorn $1\E"} .= $2;
			$interface_data_ref->{"\U$thorn $1\E"} =~ s/,/ /g;
		} elsif ($line =~ m/^\s*(PUBLIC|PROTECTED|PRIVATE)\s*:\s*$/i) {
			$block = "\U$1\E";
		} elsif ($line =~
			m/^\s*PROVIDES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*WITH\s*(.+)\s*$/i)
		{
			$funcname    = $1;
			$provided_by = $2;

			if ($provided_by =~ m/^(.*)\s+LANGUAGE\s+(.*\S)\s*$/i) {
				$provided_by          = $1;
				$provided_by_language = "\U$2";
				if ($provided_by_language eq 'FORTRAN') {
					$provided_by_language = 'Fortran';
				} elsif ($provided_by_language ne 'C') {
					my $message =
						"The providing function $provided_by in thorn $thorn "
					  . "has an invalid language specification.";
					my $hint = "Language must be either C or Fortran.";
					&CST_error(0, $message, $hint, __LINE__, __FILE__);
				}
			} else {

				#		 $provided_by_language = "Fortran";
				#		 $provided_by_language = "C";
				$message =
"The providing function $provided_by in thorn $thorn does not have a specified language. Please add, e.g., \"LANGUAGE C\"";
				&CST_error(0, $message, "", __LINE__, __FILE__);

			}

			if ($funcname eq $provided_by) {
				my $message = "The providing function $provided_by in thorn $thorn " .
					"has a name that is identical to the name of the provided " .
					"function $funcname. The names must be different.";
				my $hint = "Rename the providing function by prefixing its name with ".
					"'${thorn}_'.";
				&CST_error(0, $message, $hint, __LINE__, __FILE__);
			}

			$interface_data_ref->{"\U$thorn PROVIDES FUNCTION\E"} .=
			  "$funcname ";
			$interface_data_ref->{"\U$thorn PROVIDES FUNCTION\E $funcname WITH"}
			  .= "$provided_by ";
			$interface_data_ref->{"\U$thorn PROVIDES FUNCTION\E $funcname LANG"}
			  .= "$provided_by_language ";

		} elsif ($line =~ m/^\s*REQUIRES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*$/i) {
			$funcname = $1;
			$interface_data_ref->{"\U$thorn REQUIRES FUNCTION\E"} .=
			  "$funcname ";
		} elsif ($line =~ m/^\s*USES\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*$/i) {
			$funcname = $1;
			$interface_data_ref->{"\U$thorn USES FUNCTION\E"} .= "$funcname ";
		} elsif ($line =~
m/^\s*([a-zA-Z][a-zA-Z_0-9:]+)\s*FUNCTION\s*([a-zA-Z_0-9]+)\s*\((.*)\)\s*$/i
		  )
		{
			$rettype  = $1;
			$funcname = $2;
			$rest     = $3;

			$funcargs = $rest;

			$interface_data_ref->{"\U$thorn FUNCTIONS\E"} .= "${funcname} ";
			$interface_data_ref->{"\U$thorn FUNCTION\E $funcname ARGS"} .=
			  "${funcargs} ";
			$interface_data_ref->{"\U$thorn FUNCTION\E $funcname RET"} .=
			  "${rettype} ";
		} elsif ($line =~ m/^\s*SUBROUTINE\s*([a-zA-Z_0-9]+)\s*\((.*)\)\s*$/i) {
			$rettype  = "void";
			$funcname = $1;
			$rest     = $2;

			$funcargs = $rest;

			$interface_data_ref->{"\U$thorn FUNCTIONS\E"} .= "${funcname} ";
			$interface_data_ref->{"\U$thorn FUNCTION\E $funcname ARGS"} .=
			  "${funcargs} ";
			$interface_data_ref->{"\U$thorn FUNCTION\E $funcname RET"} .=
			  "${rettype} ";
		} elsif ($line =~
m/^\s*(CCTK_)?(CHAR|BYTE|INT|INT1|INT2|INT4|INT8|REAL|REAL4|REAL8|REAL16|COMPLEX|COMPLEX8|COMPLEX16|COMPLEX32)\s*(([a-zA-Z][a-zA-Z_0-9]*)\s*(\[([^]]+)\])?)\s*(.*)\s*$/i
		  )
		{
			#	   for($i = 1; $i < 10; $i++)
			#	   {
			#		 print "$i is ${$i}\n";
			#	   }
			my $vtype           = $2;
			my $current_group   = "$4";
			my $isgrouparray    = $5;
			my $grouparray_size = $6;
			my $options_list    = $7;

			#	   print "line is [$line]\n";
			#	   print "group name is [$current_group]\n";
			#	   print "options list is [$options_list]\n";

			if ($known_groups{"\U$current_group\E"}) {
				&CST_error(0, "Duplicate group $current_group in thorn $thorn",
					'', __LINE__, __FILE__);
				if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
					&CST_error(1, 'Skipping interface block',
						'', __LINE__, __FILE__);
					$line_number++ until ($data_ref->[$line_number] =~ m:\}:);
				}
				next;
			} else {
				$known_groups{"\U$current_group\E"} = 1;

				# Initialise some stuff to prevent perl -w from complaining.
				$interface_data_ref->{"\U$thorn GROUP $current_group\E"} = "";
			}

			$interface_data_ref->{"\U$thorn $block GROUPS\E"} .=
			  " $current_group";
			$interface_data_ref->{"\U$thorn GROUP $current_group\E VTYPE"} =
			  "\U$vtype\E";

			# Grab optional group description from end of $options_list
			if ($options_list =~ /(=?)\s*"([^"]*)"\s*$/) {
				if (!$1) {
					if (defined $data_ref->[ $line_number + 1] && # added check if defined
						$data_ref->[ $line_number + 1 ] =~ m/^\s*\{\s*$/) {
						&CST_error(
							1,
							"Group description for $current_group in thorn "
							  . "$thorn must be placed at end of variable block "
							  . "when variable block present",
							'',
							__LINE__,
							__FILE__
						);
					} else {
						$description        = $2;
						$quoted_description = quotemeta($description);
						$options_list =~ s/\s*"$quoted_description"//;
					}
				}
			}

			# split(/\s*=\s*|\s+/, $options_list);
			%options = SplitWithStrings($options_list, $thorn);

			# Parse the options
			foreach my $option (sort keys %options) {

				#		 print "DEBUG $option is $options{$option}\n";

				if ($option =~ m:DIM|DIMENSION:i) {
					$interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"}
					  = $options{$option};
				} elsif ($option =~ m:TYPE:i) {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E GTYPE"} =
					  "\U$options{$option}\E";
				} elsif ($option =~ m:TIMELEVELS:i) {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E TIMELEVELS"} =
					  "\U$options{$option}\E";
				} elsif ($option =~ m:GHOSTSIZE:i) {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E GHOSTSIZE"} =
					  "\U$options{$option}\E";
				} elsif ($option =~ m:DISTRIB:i) {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E DISTRIB"} =
					  "\U$options{$option}\E";
				} elsif ($option =~ m:SIZE:i) {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E SIZE"} =
					  "\U$options{$option}\E";
				} elsif ($option =~ m:TAGS:i) {
					if ($options{$option} =~ m/\s*^[\'\"](.*)[\'\"]$/) {
						$options{$option} = $1;
					}

					$options{$option} =~ s/\\/\\\\/g;
					$options{$option} =~ s/\"/\\\"/g;

					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E TAGS"} =
					  $options{$option};
				} else {
					&CST_error(
						0,
"Unknown option \"$option\" in group $current_group in interface.ccl for "
						  . "of thorn $thorn\n Perhaps you forgot a '\\' at the "
						  . "end of a continued line?\n"
						  . "The offending line is '$line'\n",
						'',
						__LINE__,
						__FILE__
					);
				}
			}

			# Put in defaults
			if (!$interface_data_ref->{"\U$thorn GROUP $current_group\E GTYPE"})
			{
				$interface_data_ref->{"\U$thorn GROUP $current_group\E GTYPE"}
				  = "SCALAR";
			}

			if (!$interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"}) {
				if (
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E GTYPE"} eq 'SCALAR')
				{
					$interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"}
					  = 0;
				} else {
					$interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"}
					  = 3;
				}
			}

			if (
				!$interface_data_ref->{
					"\U$thorn GROUP $current_group\E TIMELEVELS"})
			{
				$interface_data_ref->{
					"\U$thorn GROUP $current_group\E TIMELEVELS"} = 1;
			}

			if (
				!$interface_data_ref->{
					"\U$thorn GROUP $current_group\E DISTRIB"})
			{
				if (
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E GTYPE"} eq 'SCALAR')
				{
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E DISTRIB"} = 'CONSTANT';
				} else {
					$interface_data_ref->{
						"\U$thorn GROUP $current_group\E DISTRIB"} = 'DEFAULT';
				}
			}

			if (
				!$interface_data_ref->{
					"\U$thorn GROUP $current_group\E COMPACT"})
			{
				$interface_data_ref->{"\U$thorn GROUP $current_group\E COMPACT"}
				  = 0;
			}

			if ($interface_data_ref->{"\U$thorn GROUP $current_group\E GTYPE"}
				eq "SCALAR")
			{
				my $dim =
				  $interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"};
				if ($dim && $dim ne '0') {
					my $message =
"Inconsistent GROUP DIM $dim for SCALAR group $current_group of thorn $thorn";
					my $hint =
"The only allowed group dimension for scalar groups is '0'";
					&CST_error(0, $message, $hint, __LINE__, __FILE__);
					if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
						&CST_error(1, "Skipping interface block in $thorn",
							'', __LINE__, __FILE__);
						++$line_number
						  until ($data_ref->[$line_number] =~ m:\}:);
					}
					next;
				}
				$interface_data_ref->{"\U$thorn GROUP $current_group\E DIM"} =
				  0;

				my $distrib = $interface_data_ref->{
					"\U$thorn GROUP $current_group\E DISTRIB"};
				if ($distrib && $distrib ne 'CONSTANT') {
					my $message =
"Inconsistent GROUP DISTRIB $distrib for SCALAR group $current_group of thorn $thorn";
					my $hint =
"The only allowed group distribution for scalar groups is 'CONSTANT'";
					&CST_error(0, $message, $hint, __LINE__, __FILE__);
					if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
						&CST_error(1, "Skipping interface block in $thorn",
							'', __LINE__, __FILE__);
						++$line_number
						  until ($data_ref->[$line_number] =~ m:\}:);
					}
					next;
				}
				$interface_data_ref->{"\U$thorn GROUP $current_group\E DISTRIB"}
				  = "CONSTANT";
			}

			# Override defaults for grid functions
			if ($interface_data_ref->{"\U$thorn GROUP $current_group\E GTYPE"}
				eq "GF")
			{
				my $distrib = $interface_data_ref->{
					"\U$thorn GROUP $current_group\E DISTRIB"};
				if ($distrib && $distrib ne 'DEFAULT') {
					my $message =
"Inconsistent GROUP DISTRIB $distrib for GF group $current_group of thorn $thorn";
					my $hint =
"The only allowed group distribution for grid function groups is 'DEFAULT'";
					&CST_error(0, $message, $hint, __LINE__, __FILE__);
					if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
						&CST_error(1, "Skipping interface block in $thorn",
							'', __LINE__, __FILE__);
						++$line_number
						  until ($data_ref->[$line_number] =~ m:\}:);
					}
					next;
				}
				$interface_data_ref->{"\U$thorn GROUP $current_group\E DISTRIB"}
				  = "DEFAULT";
			}

			# Check that it is a known group type
			if ($interface_data_ref->{"\U$thorn GROUP $current_group\E GTYPE"}
				!~ m:^\s*(SCALAR|GF|ARRAY)\s*$:)
			{
				$message =
				  "Unknown GROUP TYPE "
				  . $interface_data_ref->{
					"\U$thorn GROUP $current_group\E GTYPE"}
				  . " for group $current_group of thorn $thorn";
				$hint = "Allowed group types are SCALAR, GF or ARRAY";
				&CST_error(0, $message, $hint, __LINE__, __FILE__);
				if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
					&CST_error(1, "Skipping interface block in $thorn",
						"", __LINE__, __FILE__);
					$line_number++ until ($data_ref->[$line_number] =~ m:\}:);
				}
				next;
			}

			# Check that it is a known distribution type
			if ($interface_data_ref->{"\U$thorn GROUP $current_group\E DISTRIB"}
				!~ m:DEFAULT|CONSTANT:)
			{
				$message =
				  "Unknown DISTRIB TYPE "
				  . $interface_data_ref->{
					"\U$thorn GROUP $current_group\E DISTRIB"}
				  . " for group $current_group of thorn $thorn";
				$hint = "Allowed distribution types are DEFAULT or CONSTANT";
				&CST_error(0, $message, "", __LINE__, __FILE__);
				if ($data_ref->[ $line_number + 1 ] =~ m:\{:) {
					&CST_error(1, "Skipping interface block in $thorn",
						'', __LINE__, __FILE__);
					$line_number++ until ($data_ref->[$line_number] =~ m:\}:);
				}
				next;
			}

			# Is it a vararray?
			if ($isgrouparray) {

				# get its size
				$interface_data_ref->{
					"\U$thorn GROUP $current_group\E VARARRAY_SIZE"} =
				  $grouparray_size;
			}

			# Fill in data for the scalars/arrays/functions
			$line_number++;
			if (defined $data_ref->[$line_number] && # added check if defined
				$data_ref->[$line_number] =~ m/^\s*\{\s*$/) {
				$line_number++;
				while ($data_ref->[$line_number] !~ m:\}:i) {
					@functions =
					  split(/[^a-zA-Z_0-9]+/, $data_ref->[$line_number]);
					foreach my $function (@functions) {
						if ($function eq $current_group) {
							if ($#functions == 1) {
								&CST_error(
									1,
									"Group and variable '$function' in thorn "
									  . "'$thorn' should be distinct",
									'',
									__LINE__,
									__FILE__
								);
							} else {
								&CST_error(
									0,
"The names of all variables '@functions' must "
									  . "be different from their group name "
									  . "'$current_group' in thorn '$thorn'",
									'',
									__LINE__,
									__FILE__
								);
							}
						}
						$function =~ s:\s*::g;

						if ($function =~ m:[^\s]+:) {
							if (!$known_variables{"\U$function\E"}) {
								$known_variables{"\U$function\E"} = 1;

								$interface_data_ref->{
									"\U$thorn GROUP $current_group\E"} .=
								  " $function";
							} else {
								&CST_error(
									0,
"Duplicate variable $function in thorn $thorn",
									'',
									__LINE__,
									__FILE__
								);
							}
						}
					}
					$line_number++;
				}

				# Grab optional group description
				$data_ref->[$line_number] =~ m:\}\s*"([^"]*)":;
				$description = $1;
			} else {
				my ($function);

				# If no block, create a variable with the same name as group.
				$function = $current_group;
				if (!$known_variables{"\U$function\E"}) {
					$known_variables{"\U$function\E"} = 1;

					$interface_data_ref->{"\U$thorn GROUP $current_group\E"} .=
					  " $function";
				} else {
					&CST_error(0,
						"Duplicate variable $function in thorn $thorn",
						'', __LINE__, __FILE__);
				}

# Decrement the line number, since the line is the first line of the next CCL statement.
				$line_number--;
			}
			$interface_data_ref->{"\U$thorn GROUP $current_group\E DESCRIPTION"}
			  = $description;
		} elsif (
			$line =~ m/^\s*(USES\s*INCLUDE)S?\s*(SOURCE)S?\s*:\s*(.*)\s*$/i)
		{
			$interface_data_ref->{"\U$thorn USES SOURCE\E"} .= " $3";
		} elsif (
			$line =~ m/^\s*(USES\s*INCLUDE)S?\s*(HEADER)?S?\s*:\s*(.*)\s*$/i)
		{
			$interface_data_ref->{"\U$thorn USES HEADER\E"} .= " $3";
		} elsif ($line =~
			m/^\s*(INCLUDE)S?\s*(SOURCE)S?\s*:\s*(.*)\s+IN\s+(.*)\s*$/i)
		{
			$header = $3;
			$header =~ s/ //g;
			$interface_data_ref->{"\U$thorn ADD SOURCE\E"} .= " $header";

			#	   print "Adding $header to $4\n";
			$interface_data_ref->{"\U$thorn ADD SOURCE $header TO\E"} = $4;
		} elsif ($line =~
			m/^\s*(INCLUDE)S?\s*(HEADER)?S?\s*:\s*(\S*)\s+IN\s+(\S*)\s*$/i)
		{
			$header = $3;
			$header =~ s/ //g;
			$interface_data_ref->{"\U$thorn ADD HEADER\E"} .= " $header";

			#	   print "Adding $header to $4\n";
			$interface_data_ref->{"\U$thorn ADD HEADER $header TO\E"} = $4;
		} else {
			if ($line =~ m:\{:) {
				&CST_error(0,
					'...Skipping interface block with missing keyword....',
					'', __LINE__, __FILE__);

				$line_number++ until ($data_ref->[$line_number] =~ m:\}:);
			} else {
				&CST_error(
					0,
"Unknown line in interface.ccl for thorn $arrangement/$thorn\n\"$line\"",
					'',
					__LINE__,
					__FILE__
				) if ($line);
			}
		}
	}

	return;
}

1;
