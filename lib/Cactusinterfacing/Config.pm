
##
## Config.pm
##
## Configuration for cactusinterfacing.
## Setups some variables, change for your needs.
##

package Cactusinterfacing::Config;

use strict;
use warnings;
use Exporter 'import';

# export
our @EXPORT_OK = qw($debug $verbose $tab);

# debug
our $debug   = 1;
our $verbose = 1;

# coding style
# used for indention of auto generated code
our $tab = "\t";

1;
