#!/usr/bin/env perl
# $Id$
#

use strict; use warnings;
use constant DEFAULT_PREFIX => 'table.geo_';

die "usage: $0 geo-worldip.conf"
unless (defined($ARGV[0]) && (-r $ARGV[0]));
open my $fh, $ARGV[0] or die "open: $!";
 my %cidr = (); push @{$cidr{$2}}, $1 while(<$fh> =~ m,^(.+?) (..);$,g);
close $fh;

foreach my $key (keys %cidr) {
	open $fh, ">>", DEFAULT_PREFIX . $key or die "open: $!";
	 print $fh join("\n", @{$cidr{$key}}) . "\n";
	close $fh;
};

# vim:ts=8 sw=8 noexpandtab
