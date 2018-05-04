#!/usr/bin/env perl
# $Id$
#

# {{{ use
use 5.10.0; use strict; use warnings;
use IO::Socket::INET 1.18;
# }}}
# {{{ use constants
use constant PING_FREQUENCY	=> 15;	# In seconds
use constant NICK		=> "kill";
use constant PASS		=> "pD66Qx0kXQocpl53l3x";
use constant USER		=> "arab";
use constant GECOS		=> "knubbze kill bot";
use constant CHANNEL		=> "#arab";
use constant OPER_NAME		=> "arab";
use constant OPER_PASS		=> "mJ6Mg6U6ZnuXl1PAFoZMPW1lrzrR8uqFu/SN";
# }}}
# {{{ our variables
our $socket;
our $rate = [ 5, 2 ];
# }}}
# {{{ Signal handlers
$SIG{ALRM} = sub { print $socket "PING :1488\r\n"; alarm(PING_FREQUENCY); };
# }}}

local	$/ = "\r\n";
$socket =
	IO::Socket::INET->new(
		PeerAddr => "69.42.217.188",
		PeerPort => 6667, Proto => "tcp")
	or die "IO::Socket::INET: $!";
print	$socket "NICK ". NICK ."\r\nPASS ". PASS ."\r\n";
print	$socket "USER ". USER ." 0 0 :". GECOS ."\r\n";

while(my $line = <$socket>) {
	chomp($line); my ($f, $k, $t) = ($line =~ m,^(:[^ ]+)? ([^ ]+) ?(.+)?,);
	next unless ($f and $k and $t);

	if($f =~ m,^:?v!arab\@127\.0\.0\.1$,
	&& $t =~ m,^([^ ]+) :?!rate$,i) {
		print $socket "PRIVMSG $1 :". $rate->[0] ." ". $rate->[1] ."\r\n";
	} elsif(
	   $f =~ m,^:?v!arab\@127\.0\.0\.1$,
	&& $t =~ m,^[^ ]+ :?!rate (\d+) (\d+)$,i) {
		$rate->[0] = $1; $rate->[1] = $2;
	} elsif("PING" eq $k) {
		print $socket "PONG :$t\r\n";
	} elsif("001" eq $k) {
		print $socket "OPER ". OPER_NAME ." ". OPER_PASS ."\r\n";
		alarm(PING_FREQUENCY);
	} elsif("381" eq $k) {
		print $socket "JOIN ". CHANNEL ."\r\n";
	} elsif(
	   $f =~ m,^:?([^!]+)!knubbze\@,
	&& rand($rate->[0]) < $rate->[1]) {
		print $socket "KILL $1 :test\r\n";
	};
};

# vim:ts=8 sw=8 noexpandtab foldmethod=marker
