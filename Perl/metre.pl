#!/usr/bin/env perl
# $Id: $
use strict; use warnings;

die "usage: $0 metre_name metre_tgt scale_n scale_name"
unless 4 == ($#ARGV + 1);

my @colours = (14, 5, 5, 4, 4, 7, 7, 8, 8, 3, 3, 9, 9);
my %metre = (
	name => $ARGV[0], tgt => $ARGV[1],
	scale_name => $ARGV[3], scale_n => int($ARGV[2])
);

my $n = 1;
print	"\x0f" . $metre{'name'} ."\00314-\0030o\00314-\003metre " .
	"for \002" . $metre{'tgt'} . "\002\x1f:\x1f " .
	"\00314[\003" .
		join(
			'',
			grep {
				$_ = "\003" .
				$colours[($metre{'scale_n'} < $n) ? 0 : $n++] .
				"$_\x0f"} split //, ("|" x 12)
		) .
	"\00314]\003 " .

	"\x1f\003" .
		$colours[
			($#colours < $metre{'scale_n'})
			?  $#colours
			: ($metre{'scale_n'} % ($#colours + 1))
		] .
		uc($metre{'scale_name'}) .
	"\003\x1f" .

	"\n";

# vim:ts=8 sw=8 tw=80 noexpandtab
