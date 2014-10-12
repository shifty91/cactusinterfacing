
##
## ThornList.pm
##
## Modul for parsing a Cactus ThornList to get information about the thorns.
##

package Cactusinterfacing::ThornList;

use strict;
use warnings;
use Exporter 'import';
use Cactusinterfacing::Utils qw(util_readFile _err _warn);

# export
our @EXPORT_OK = qw(parseThornList getInherits getFriends isInherit isFriend);

#
# Checks whether thorn 1 inherits from thorn 2.
#
# param:
#  - info_ref: ref to thorninfo hash
#  - ar_0    : first arrangement/thorn
#  - ar_1    : second arrangement/thorn
#
# return:
#  - true if ar_0 inherits from ar_1 else false
#
sub isInherit
{
	my ($info_ref, $ar_0, $ar_1) = @_;
	my (@inherits);

	getInherits($ar_0, $info_ref, \@inherits);

	return ((scalar grep { $ar_1 =~ /^$_$/i } @inherits) || $ar_0 =~ /^$ar_1$/i);
}

#
# Checks whether thorn 1 is friend with thorn 2.
#
# param:
#  - info_ref: ref to thorninfo hash
#  - ar_0    : first arrangement/thorn
#  - ar_1    : second arrangement/thorn
#
# return:
#  - true if ar_0 is friend from ar_1 else false
#
sub isFriend
{
	my ($info_ref, $ar_0, $ar_1) = @_;
	my (@friends);

	getFriends($ar_0, $info_ref, \@friends);

	return ((scalar grep { $ar_1 =~ /^$_$/i } @friends) || $ar_0 =~ /^$ar_1$/i);
}

#
# FIXME: implement this
#
sub isShared
{
	return 0;
}

#
# Get all inherits.
# Inheritance is transitiv, therefore this
# functions works recursivly.
#
# param:
#  - ar_thorn    : arrangement/thorn
#  - info_ref    : ref to thorninfo hash
#  - inherits_ref: ref to hash where inherits will be stored
#
# return:
#  - none, all inherits will be stored in inherits_ref
#
sub getInherits
{
	my ($ar_thorn, $info_ref, $inherits_ref) = @_;
	my ($impl, $inherits, $friends, $shares) =
		@{$info_ref->{$ar_thorn}}{qw(impl inherits friends shares)};
	my (@values, $hash_ref);

	return if ($inherits eq "");

	@values = split(',', $inherits);
	# remove whitespaces
	s/\s// for @values;
	#push(@$inherits_ref, @values);

	foreach my $val (@values) {
		# get ar_thorn
		foreach my $key (keys %{$info_ref}) {
			if ($val =~ /^$info_ref->{$key}{"impl"}$/i) {
				push(@$inherits_ref, $key);
				getInherits($key, $info_ref, $inherits_ref);
				last;
			}
		}
	}

	return;
}

#
# Get all friends.
# Friendships are transitiv, therefore this
# functions works recursivly.
#
# param:
#  - ar_thorn   : arrangement/thorn
#  - info_ref   : ref to thorninfo hash
#  - friends_ref: ref to hash where friends will be stored
#
# return:
#  - none, all friends will be stored in friends_ref
#
sub getFriends
{
	my ($ar_thorn, $info_ref, $friends_ref) = @_;
	my ($impl, $inherits, $friends, $shares) =
		@{$info_ref->{$ar_thorn}}{qw(impl inherits friends shares)};
	my (@values);

	return if ($friends eq "");

	@values = split(',', $friends);
	# remove whitespaces
	s/\s// for @values;
	#push(@$friends_ref, @values);

	foreach my $val (@values) {
		# get ar_thorn
		foreach my $key (keys %{$info_ref}) {
			if ($val =~ /^$info_ref->{$key}{"impl"}$/i) {
				push(@$friends_ref, $key);
				getInherits($key, $info_ref, $friends_ref);
				last;
			}
		}
	}

	return;
}

#
# FIXME: implement this.
# Not implemented but should work like the functions above.
#
sub getShares
{
	return;
}

#
# Gatheres information about thorns from ThornList and stores into
# info reference where arrangement/thorn is the key.
# The value is an hash containing implementation, inherits, friends
# and shares.
#
# param:
#  - configdir : directory of cactus configs
#  - thorns_ref: ref where data will be stored
#  - info_ref  : ref to thorninfo hash
#
# return:
#  - none, data will be stored in thorns_ref and info_ref
#
sub getThorns
{
	my ($configdir, $thorns_ref, $info_ref) = @_;
	my (@lines);

	util_readFile("$configdir/ThornList", \@lines);

	foreach my $line (@lines) {
		my (@options);
		# skip comments
		next if $line =~ /^\s*#/;
		# skip empty lines
		next if $line =~ /^\s*$/;

		# expected format: arrangement/thorn # implements (inherits) [friends] {shares}
		if ($line =~ /^(\w+\/\w+)\s*#\s*(\w+)\s*\(([\w,\- ]*)\)\s*\[([\w,\- ]*)\]\s*\{([\w,\- ]*)\}\s*$/) {
			@options = ($2, $3, $4, $5);
			push(@$thorns_ref, $1);
			s/\s//g for (@options);
			$info_ref->{$1}{"impl"}     = $options[0];
			$info_ref->{$1}{"inherits"} = $options[1];
			$info_ref->{$1}{"friends"}  = $options[2];
			$info_ref->{$1}{"shares"}   = $options[3];
		} else {
			_err("Unexpected format found in $configdir/ThornList. Aborting now.",
				 __FILE__, __LINE__);
		}
	}

	return;
}

#
# Stores options into option refrence, including:
#  - mpi, important for Makefile, int main(), etc...
#  - io_jpeg
#  - io_ascii
#  - io_hdf5
#  - io_iso
#  - d_pugh
#  - d_carpet
#  - s_socket
#  - s_httpd
#
# param:
#  - thorn_ref : ref to thorninfo hash
#  - option_ref: ref where data will be stored
#
# return:
#  - none, options will be stored in option_ref
#
sub getOptions
{
	my ($thorn_ref, $option_ref) = @_;

	# get options
	foreach my $thorn (@$thorn_ref) {
		$option_ref->{"mpi"}      = 1 if ($thorn =~ /mpi/i);
		$option_ref->{"io_jpeg"}  = 1 if ($thorn =~ /iojpeg$/i);
		$option_ref->{"io_ascii"} = 1 if ($thorn =~ /ioascii$/i);
		$option_ref->{"io_hdf5"}  = 1 if ($thorn =~ /iohdf5$/i);
		$option_ref->{"io_iso"}   = 1 if ($thorn =~ /isosurfacer$/i);
		$option_ref->{"d_pugh"}   = 1 if ($thorn =~ /pugh/i);
		$option_ref->{"d_carpet"} = 1 if ($thorn =~ /carpet/i);
		$option_ref->{"s_socket"} = 1 if ($thorn =~ /socket$/i);
		$option_ref->{"s_httpd"}  = 1 if ($thorn =~ /httpd$/i);
	}

	# perform some checks
	if ($option_ref->{"io_iso"}) {
		#_warn("IsoSurfacer IO Method is not supported: using BOVWriter instead!",
		#		__FILE__, __LINE__);
		$option_ref->{"io_hdf5"} = 1;
	}

	return;
}


#
# Parse thorn list to get all thorns
# with their implementations, inherits, friends and shares.
# Moreover some options like mpi usage is stored.
#
# param:
#  - config_ref   : ref to config hash
#  - thorninfo_ref: ref to thorninfo hash
#  - option_ref   : ref to option hash
#
# return:
#  - none, data will be stored in thorninfo_ref and option_ref
#    (see functions above)
#
sub parseThornList
{
	my ($config_ref, $thorninfo_ref, $option_ref) = @_;
	my (@thorns);

	# read ThornList
	getThorns($config_ref->{"config_dir"}, \@thorns, $thorninfo_ref);
	# get options
	getOptions(\@thorns, $option_ref);
	# check if mpi is forced
	$option_ref->{"mpi"} = 1 if ($config_ref->{"force_mpi"});

	return;
}

1;
