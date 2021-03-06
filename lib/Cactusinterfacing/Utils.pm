#/*@@
#  @file      CSTUtils.pl
#  @date      4 July 1999
#  @author    Gabrielle Allen
#  @desc
#  Various utility routines.
#  @enddesc
#  @version $Header$
#@@*/

##
## Utils.pm
##
## Contains utility function for printing, input, etc.
##
## taken from Cactus (lib/sbin/CSTUtils.pl), see comments
##
## Copyright (C) 2013, 2014 Kurt Kanzenbach <kurt@kmk-computers.de>
##  - renamed to Utils.pm
##  - made a perl module
##  - added use strict, warnings
##  - coding style
##  - rewrite of CST_error to use my _err function
##  - added util_*, info, dbg, _warn, _err subroutines
##  - removed some subroutines
##

package Cactusinterfacing::Utils;

use strict;
use warnings;
use Exporter 'import';
use File::Copy;
use File::Which;
use File::Path qw(mkpath remove_tree);
use Cactusinterfacing::Config qw(%cinf_config);

# export
our @EXPORT_OK = qw(read_file RemoveComments CST_error SplitWithStrings _err
					_warn dbg info vprint util_writeFile util_mkdir util_trim
					util_cp util_arrayToHash util_readFile util_input
					util_indent util_getFunction util_choose util_readDir
					util_tidySrcDir util_rmdir util_chooseMulti util_buildFunction);

#
# Extract a function body from a given source file.
#
# param:
#  - file   : file name specified by absolute path
#  - name   : name of function to extract
#  - out_ref: ref to an array where to store function body
#
# return:
#  - true if function were found, false if not
#
sub util_getFunction
{
	my ($file, $name, $out_ref) = @_;
	my (@lines, $data, $level, $found);

	util_readFile($file, \@lines);

	# init
	$level = 0;
	$found = 0;

	# remove prototypes, functions calls etc...
	$data  = join("", @lines);
	$data  =~ s/$name\s*\([\w, :&\*]*\)\s*;//g;
	@lines = split("\n", $data);

	# get function's body
	foreach my $line (@lines) {
		chomp $line;

		# search for start
		if (!$found && $line =~ /$name\s*\([\w, :&\*]*\)\s*\{/s) {
			$found = 1;
			$level++;
			next;
		}
		if (!$found && $line =~ /$name\s*\([\w, :&\*]*\)/s) {
			$found = 1;
			next;
		}

		# increase/decrease level
		$level++ if ($found && $line =~ /\{/);
		if ($found && $line =~ /\}/) {
			$level--;
			last unless ($level);
		}

		# store
		push(@$out_ref, $line) if ($found && $level);
	}

	shift @$out_ref if (@$out_ref && @$out_ref[0] =~ /^\s*\{/);

	return $found;
}

#
# Builds a function.
#
# param:
#  - body_ref: function body, may be array ref or scalar ref
#  - proto   : prototype
#  - out_ref : ref where to store array
#  - temp    : template [optional]
#  - indent  : indent   [optional]
#
# return:
#  - none, function will be stored in out_ref
#
sub util_buildFunction
{
	my ($body_ref, $proto, $out_ref, $temp, $indent) = @_;
	my (@header);

	# adjust params
	$indent	= 1 unless (defined $indent);

	# build func
	push(   @header  , "$temp\n") if (defined $temp);
	push(   @header  , "$proto\n");
	push(   @header  , "{\n");
	unshift(@$out_ref, @header);

	# array
	if (ref $body_ref eq "ARRAY") {
		for (@$body_ref) {
			chomp($_);
			$_ .= "\n";
		}
		push(@$out_ref, @$body_ref);
	}
	# scalar
	if (ref $body_ref eq "SCALAR") {
		my @lines = split /\n{1}/, $$body_ref;
		$_ = $_ . "\n" for (@lines);
		push(@$out_ref, @lines);
	}
	push(@$out_ref, "}\n");

	# indent
	util_indent($out_ref, $indent);

	return;
}

#
# Indent existing c/c++ code by using '{' and '}'.
#
# param:
#  - arr_ref: ref to array of code
#  - offset : very useful to start at a given level of indention
#
# return:
#  - none
#
sub util_indent
{
	my ($arr_ref, $offset) = @_;
	my ($level, $found);

	# remove existing indention
	s/^[ \t]+//g for (@$arr_ref);

	$level = $offset;
	foreach my $line (@$arr_ref) {
		# check for braces
		$found = 0;
		$found = 1 if ($line =~ /\{\s*$/);
		$level--   if ($line =~ /\}\s*$/);

		# print, but only if $line not empty
		$line = $cinf_config{"tab"} x $level . $line if ($line ne "" && $line ne "\n");

		$level++ if ($found);
	}

	return;
}

#
# Tidies all source files in given directory. This function uses the external
# tool `astyle' for that. If `astyle' is not found on the system or using
# `astyle' is disabled, this function does simply nothing.
#
# param:
#  - directory: directory where to cleanup sources files
#
# return:
#  - none
#
sub util_tidySrcDir
{
	my ($directory) = @_;
	my ($options, $astyle);

	return unless ($cinf_config{"use_astyle"});

	$astyle = which("astyle");
	return unless ($astyle);

	$options  = "$cinf_config{\"astyle_options\"} --recursive $directory/'*.cpp' $directory/'*.h' ";
	$options .= "$directory/include/'*.h'";

	`$astyle $options`;
	_warn("Executing `astyle' failed with exitcode $? !")
		if ($?);

	return;
}

#
# Choose between answers stored in arr_ref.
# User has to choose a valid answer.
#
# param:
#  - message: message to display
#  - arr_ref: ref of array where the answers are stored
#
# return:
#  - answer given by user (value)
#
sub util_choose
{
	my ($message, $arr_ref) = @_;
	my ($i, $answer);

	print $message . ":\n";

	for ($i = 0; $i < @$arr_ref; $i++) {
		print "  [$i] $arr_ref->[$i]\n";
	}

	print "Choice: ";
	$answer = <STDIN>;
	_err("No answer given!") unless (defined $answer);
	$answer =~ s/^\s*//g;
	$answer =~ s/\s*$//g;

	_err("\"$answer\" is not a valid choice!")
		if ($answer !~ /^\d+$/ || $answer >= $i);

	return $arr_ref->[$answer];
}

#
# Choose between answers stored in arr_ref.
# User can choose multiple answers. Examples:
# "Choice: " 0,1,2 or simply
# "Choice: " 0
#
# param:
#  - message: message to display
#  - arr_ref: ref of array where the answers are stored
#
# return:
#  - answers given by user in form of an array
#
sub util_chooseMulti
{
	my ($message, $arr_ref) = @_;
	my ($i, $answer, @token, @ret);

	print $message . ":\n";

	for ($i = 0; $i < @$arr_ref; $i++) {
		print "  [$i] $arr_ref->[$i]\n";
	}

	print "Choice: ";
	$answer = <STDIN>;
	_err("No answer given!") unless (defined $answer);
	$answer =~ s/^\s*//g;
	$answer =~ s/\s*$//g;

	# parse user input
	_err("\"$answer\" is not a valid choice!")
		unless ($answer =~ /^(?:\d+,?)+$/);
	@token = split ',', $answer;
	foreach my $choice (@token) {
		_err("\"$choice\" is not a valid choice!")
			if ($choice !~ /\d+/ || $choice >= $i);
		push(@ret, $arr_ref->[$choice]);
	}

	return @ret;
}

#
# Get user input by asking a question
# to the user.
#
# param:
#  - question: question you want to ask
#
# return:
#  - the answer
#
sub util_input
{
	my ($question) = @_;
	my ($answer);

	print "$question: ";
	$answer = <STDIN>;
	_err("No answer given!") unless (defined $answer);
	chomp $answer;

	return $answer;
}

#
# Creates a directory given by parameter dir.
# It works recursively like `mkdir -p'.
#
# param:
#  - dir: directory to be created
#
# return:
#  - none, exits on error
#
sub util_mkdir
{
	my ($dir) = @_;

	eval { mkpath($dir) };
	_err("Cannot create directory $dir: $@") if ($@);

	return;
}

#
# Removes a complete directory recursively.
#
# param:
#  - dir: directory to be deleted
#
# return:
#  - none, exits on error
#
sub util_rmdir
{
	my ($dir) = @_;
	my ($err);

	remove_tree($dir, {error => \$err});
	_err("Cannot delete directory $dir!") if (@$err);

	return;
}

#
# Error checked copy.
#
# It is possible to use wildcars here:
#  - example: util_cp("*.h", "/tmp");
#
# param:
#  - src_in: source
#  - dest  : destination
#
# return:
#  - none
#
sub util_cp
{
	my ($src_in, $dest) = @_;
	my (@sources);

	@sources = glob $src_in;

	foreach my $src (@sources) {
		copy($src, $dest) ||
			_err("Cannot copy $src to $dest: $!.");
	}

	return;
}

#
# Convert param or schedule array from parser output
# into a hash for further processing.
#
# param:
#  - arr_ref : ref to array
#  - hash_ref: ref to hash
#
# return:
#  - none, result will be stored in hash_ref
#
sub util_arrayToHash
{
	my ($arr_ref, $hash_ref) = @_;
	my ($i);

	for ($i = 0; $i < @$arr_ref; $i = $i + 2) {
		$hash_ref->{$arr_ref->[$i]} = $arr_ref->[$i+1];
	}

	return;
}

#
# Read a file and return its content.
#
# param:
#  - file   : file to read
#  - out_ref: ref to array where to store content
#
# return:
#  - none, content will be stored in out_ref
#
sub util_readFile
{
	my ($file, $out_ref) = @_;
	my ($fh, $line);

	open($fh, "<" ,"$file") ||
		_err("Cannot open file $file: $!");

	push(@$out_ref, <$fh>);

	close $fh;

	return;
}

#
# Write an array of lines into a file.
#
# param:
#  - arr_ref: ref to array with content to write
#  - file   : file to write to
#
# return:
#  - none
#
sub util_writeFile
{
	my ($arr_ref, $file) = @_;
	my ($fh);

	open($fh, ">", "$file") ||
		_err("Cannot open $file for writing: $!");

	print $fh $_ for (@$arr_ref);

	close $fh;

	return;
}

#
# Do directory listing (like `ls'). The .dotfiles will be skipped.
# Returns () if directory is empty or does not exist.
#
# param:
#  - dir    : directory
#  - out_ref: ref of an array to store content
#
# return:
#  - none, values will be stored in out_ref
#
sub util_readDir
{
	my ($dir, $out_ref) = @_;
	my ($dh, $file);

	unless (opendir($dh, $dir)) {
		@$out_ref = ();
		return;
	}

	while ($file = readdir $dh) {
		# skip dotfiles
		next if ($file =~ /^\./);
		push(@$out_ref, $file);
	}

	closedir $dh;

	return;
}

#
# Trim left and right.
#
# param:
#  - string: string to trim
#
# return:
#  - trimmed string
#
sub util_trim
{
	my ($string) = @_;

	$string =~ s/^\s+//;
	$string =~ s/\s+$//;

	return $string;
}

#
# Info print.
#
# param:
#  - msg : message to print
#  - file: file
#  - line: line
#
# return:
#  - none
#
sub info
{
	my ($msg, $file, $line) = @_;
	print "[INFO $file:$line]: $msg\n";

	return;
}

#
# Verbose print only if verbose is set.
#
# param:
#  - msg : message to print
#
# return:
#  - none
#
sub vprint
{
	my ($msg) = @_;
	print "$msg\n" if ($cinf_config{"verbose"});

	return;
}

#
# Debug print, only if debug is set.
#
# param:
#  - msg: message to print
#
# return:
#  - none
#
sub dbg
{
	my ($msg) = @_;
	my (undef, undef, undef, $sub)  = caller(1);
	my (undef, $file, $line, undef) = caller(0);

	print STDERR "[ERROR in $sub $file:$line]: $msg\n";

	return;
}

#
# Prints error message and exit.
#
# param:
#  - msg: message to print
#
# return:
#  - none
#
sub _err
{
	my ($msg) = @_;
	my (undef, undef, undef, $sub)  = caller(1);
	my (undef, $file, $line, undef) = caller(0);

	print STDERR "[ERROR in $sub $file:$line]: $msg\n";

	exit -1;
}

#
# Warning print.
#
# param:
#  - msg: message to print
#
# return:
#  - none
#
sub _warn
{
	my ($msg) = @_;
	my (undef, undef, undef, $sub)  = caller(1);
	my (undef, $file, $line, undef) = caller(0);

	print STDERR "[WARNING in $sub $file:$line]: $msg\n";

	return;
}

#/*@@
#  @routine	  CST_error
#  @date	  4 July 1999
#  @author	  Gabrielle Allen
#  @desc
#  Print an error or warning message
#  @enddesc
#@@*/
#
# Adjusted to use my own error function and exit.
#
sub CST_error {
	my ($level, $mess, $help, $line, $file) = @_;

	_err($mess."\nSuggested help: ".$help, $line, $file);

	return;
}

#/*@@
#  @routine	   read_file
#  @date	   Wed Sep 16 11:54:38 1998
#  @author	   Tom Goodale
#  @desc
#  Reads a file deleting comments and blank lines.
#  @enddesc
#  @calls
#  @calledby
#  @history
#  @hdate Fri Sep 10 10:25:47 1999 @hauthor Tom Goodale
#  @hdesc Allows a \ to escape the end of a line.
#  @endhistory
#@@*/
#
# Adjusted to use my own error function and exit.
#
sub read_file {
	my ($file) = @_;
	my (@indata);
	my ($fh, $line);

	open($fh, "<", "$file") || _err("Cannot open $file.");

	$line = "";

	while (<$fh>) {
		chomp;

		# Add to the currently processed line.
		$line .= $_;

		# Check if this line will be continued
		if ($line =~ m:[^\\]\\$:) {
			$line =~ s:\\$::;
			next;
		}

		# Remove comments.
		$line = &RemoveComments($line);

		# Ignore empty lines.
		if ($line !~ m/^\s*$/) {
			push(@indata, $line);
		}

		$line = "";
	}

	# Make sure to dump out the last line, even if it ends in a \
	if ($line ne "") {
		push(@indata, $line);
	}

	close $fh;

	return @indata;
}

#/*@@
#  @routine	   RemoveComments
#  @date
#  @author	   Tom Goodale, Yaakoub El Khamra
#  @desc
#  Removes comments from lines
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#  @var		line
#  @vdesc	line to remove comments from
#  @vtype	string
#  @vio		in
#  @endvar
#
#  @returntype line
#  @returndesc
#	 line without comments
#  @endreturndesc
#@@*/
sub RemoveComments {
	my ($line)    = @_;
	my $nocomment = $line;
	my $insstring = 0;
	my $indstring = 0;
	my $escaping  = 0;
	my $token     = "";

	for my $i (split(//, $line)) {
		if ($i eq '\\') {
			if ($escaping) {
				$token .= $i;
			}

			$escaping = 1 - $escaping;
		} elsif ($i eq '"' && !$insstring && !$escaping) {
			$token     = "";
			$indstring = 1 - $indstring;
		} elsif ($i eq "'" && !$indstring && !$escaping) {
			$token     = "";
			$insstring = 1 - $insstring;
		} elsif ($i =~ /^\s+$/ && !$insstring && !$indstring && !$escaping) {
			$token = "";
		} elsif ($i eq '=' && !$insstring && !$indstring && !$escaping) {
			$token = "";
		} elsif ($i eq '#' && !$insstring && !$indstring && !$escaping) {
			$nocomment =~ s/\#.*//;
			return $nocomment;
		} else {
			if ($escaping) {
				$token .= "\\";
				$escaping = 0;
			}
			$token .= "$i";
		}
	}

	if ($insstring || $indstring) {
		print "Error: Unterminated string while parsing ccl file";
		print $nocomment;
	}

	if ($escaping) {
		$token .= '\\';
	}

	return $nocomment;
}

#/*@@
#  @routine	   SplitWithStrings
#  @date	   Tue May 21 23:45:54 2002
#  @author	   Tom Goodale
#  @desc
#  Splits a string on spaces and = ignoring
#  any occurence of these in strings.
#  @enddesc
#  @calls
#  @calledby
#  @history
#
#  @endhistory
#
#  @var		expression
#  @vdesc	Expression to split
#  @vtype	string
#  @vio		in
#  @endvar
#
#  @returntype list
#  @returndesc
#	 Split representation of input expression.
#  @endreturndesc
#@@*/
sub SplitWithStrings {
	my ($expression, $thorn) = @_;

	my $insstring = 0;
	my $indstring = 0;
	my $escaping  = 0;

	my @tokens = ();

	my $token = "";

	# First split the string into string tokens and split tokens we are
	# allowed to split.

	for my $i (split(//, $expression)) {
		if ($i eq '\\') {
			if ($escaping) {
				$token .= $i;
			}
			$escaping = 1 - $escaping;
		} elsif ($i eq '"' && !$insstring && !$escaping) {
			if (length $token > 0 || $indstring) {
				push(@tokens, $token);
			}

			$token     = "";
			$indstring = 1 - $indstring;
		} elsif ($i eq "'" && !$indstring && !$escaping) {
			if (length $token > 0 || $insstring) {
				push(@tokens, $token);
			}

			$token = "";

			$insstring = 1 - $insstring;
		} elsif ($i =~ /^\s+$/ && !$insstring && !$indstring && !$escaping) {
			if (length $token > 0 || $insstring) {
				push(@tokens, $token);
			}

			$token = "";
		} elsif ($i eq '=' && !$insstring && !$indstring && !$escaping) {
			if (length $token > 0 || $insstring) {
				push(@tokens, $token);
			}

			$token = "";
		} else {
			if ($escaping) {
				$token .= "\\";
				$escaping = 0;
			}
			$token .= "$i";
		}
	}

	if ($insstring || $indstring) {
		print "Error: Unterminated string while parsing interface for thorn : $thorn\n";
	}

	if ($escaping) {
		$token .= '\\';
	}

	if (length $token > 0) {
		push(@tokens, $token);
	}

	return @tokens;
}

1;
