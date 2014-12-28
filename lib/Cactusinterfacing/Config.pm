
##
## Config.pm
##
## Configuration for the cactusinterfacing tool.
## This module setups some variables, change them for your needs.
##

package Cactusinterfacing::Config;

use strict;
use warnings;
use Exporter 'import';

# export
our @EXPORT_OK = qw(%cinf_config);

our %cinf_config;				# cactus interfacing configuration hash

################################################################################
# End of module code                                                           #
################################################################################

BEGIN
{
	############################################################################
	# Configuration section begins here                                        #
	############################################################################

	# these are the default configuration parameter, they might be
	# overwritten by an optional config file $HOME/.cactus_inf.rc
	# change these variables for your needs.

	# choose whether to use debug or verbose output
	my $debug   = 1;
	my $verbose = 1;

	# coding style
	# used for indention of auto generated code
	my $tab = "\t";

	# this variable specifies whether astyle should be used for formatting
	# autogenerated code
	my $use_astyle = 1;

	# Some of the autogenerated code may not fit into a specific coding style per
	# default. This is why `astyle' will be used to reformat the code. The following
	# variable specifies the options passed to `astyle'. This default options adapt
	# the LibGeoDecomp's coding style. Change to whatever you want. If `astyle' is
	# not found on the system, the code will be left untouched.
	my $astyle_options = "--indent=spaces=4 --brackets=linux --indent-labels ".
		"--pad-oper --unpad-paren --pad-header ".
		"--keep-one-line-statements --suffix=none ".
		"--convert-tabs --indent-preprocessor";

	# the topology which should be used
	# valid topologies are:
	#  - Cube
	#  - Torus
	my $topology = "Cube";

	# if a scalar boundary condition is used, you can set the actual value here
	my $scalar = 0;

	# ghostzone width
	my $ghostzone_width = 1;

	# vectorization
	my $use_vectorization = 0;
	my $vector_width = 8;

	################################################################################
	# Configuration section ends here                                              #
	################################################################################

	# specify which options can be overwritten by config file
	my @allowed_options = ('debug', 'verbose', 'tab', 'use_astyle',
						   'astyle_options', 'topology', 'scalar',
						   'ghostzone_width', 'use_vectorization',
						   'vector_width');

	#
	# Checks the values specified by the user above.
	#
	# param:
	#  - none
	#
	# return:
	#  - true if everything is okay, else false
	#
	sub checkConfiguration
	{
		my ($ret, $debug, $tab, $topology, $ghostzone_width, $use_astyle,
			$use_vectorization, $vector_width);

		$debug             = $cinf_config{debug};
		$tab               = $cinf_config{tab};
		$topology          = $cinf_config{topology};
		$ghostzone_width   = $cinf_config{ghostzone_width};
		$use_astyle        = $cinf_config{use_astyle};
		$use_vectorization = $cinf_config{use_vectorization};
		$vector_width      = $cinf_config{vector_width};
		$ret               = 1;

		# check general options
		$ret = 0 if ($debug !~ /^\d+$/ || $verbose !~ /^\d+$/);
		$ret = 0 if ($tab !~ /^[ ]+|\t$/);
		$ret = 0 if ($topology !~ /^Cube|Torus$/);
		$ret = 0 if ($ghostzone_width !~ /^\d+$/);
		$ret = 0 if ($use_astyle !~ /^\d+$/);
		$ret = 0 if ($use_vectorization !~ /^\d+$/);
		$ret = 0 if ($vector_width !~ /^\d+$/);

		return $ret;
	}

	#
	# This functions initializes the config hash to default values.
	# Just in case no rc file is provided.
	#
	# param:
	#  - none
	#
	# return:
	#  - none
	#
	sub setupDefaultValues
	{
		%cinf_config = (
			debug             => $debug,
			verbose           => $verbose,
			tab               => $tab,
			use_astyle        => $use_astyle,
			astyle_options    => $astyle_options,
			topology          => $topology,
			scalar            => $scalar,
			ghostzone_width   => $ghostzone_width,
			use_vectorization => $use_vectorization,
			vector_width      => $vector_width,
		   );

		return;
	}

	#
	# Reads the .cactus_inf.rc configuration file and setups the cinf_config
	# hash accordingly. The format is expected as follows:
	#   key = value
	# Lines beginning with # are treated as comments.
	#
	# params:
	#  - none
	#
	# return:
	#  - true, if rc file found and parsed correctly, else false
	#
	sub readConfiguration
	{
		my ($file, $fh, $ret, $line, $i);

		return unless (defined $ENV{HOME});

		# init
		$file = "$ENV{HOME}/.cactus_inf.rc";
		$i    = 1;
		$ret  = 1;

		return 0 unless (-r $file);

		_err("Cannot open file $file: $!")
			unless (open($fh, "<", $file));

		# read config file into config hash
		while ($line = <$fh>) {
			my ($option, $value) = (undef, undef);
			# skip empty lines
			next if ($line =~ /^\s*$/);
			# skip comments
			next if ($line =~ /^\s*#/);
			# parse line
			($option, $value) = $line =~ /^\s*(\w+)\s*=\s*([\w\- ]+)\s*$/;
			# syntax error
			unless (defined $option) {
				print STDERR "[WARNING " . __FILE__ . ":" . __LINE__ . "]: " .
					"Syntax error in $file at line $i while reading config -> Ignoring...\n";
				$ret = 0;
				next;
			}
			# logical error
			unless (grep { $_ =~ /^$option$/ } @allowed_options) {
				print STDERR "[WARNING " . __FILE__ . ":" . __LINE__ . "]: " .
					"Invalid option $option in config file $file at line $i found -> Ignoring...\n";
				$ret = 0;
				next;
			}
			$cinf_config{$option} = $value;
		} continue {
			++$i;
		}

		close $fh;

		return $ret;
	}

	# setup configuration
	setupDefaultValues();
	readConfiguration();
	unless (checkConfiguration()) {
		print STDERR "[ERROR " . __FILE__ . ":" . __LINE__ . "]: " .
			"Configuration is not valid. Check Config.pm or your .cactus_inf.rc\n";
		exit -1;
	}
}

1;
