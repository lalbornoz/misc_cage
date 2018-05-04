#!/usr/bin/perl
use strict; use warnings;
my %hnato = ("A" => "ALFA", "B" => "BRAVO", "C" => "CHARLIE", "D" => "DELTA", "E" => "ECHO", "F" => "FOXTROT", "G" => "GOLF", "H" => "HOTEL", "I" => "INDIA", "J" => "JULIETT", "K" => "KILO", "L" => "LIMA", "M" => "MIKE", "N" => "NOVEMBER", "O" => "OSCAR", "P" => "PAPA", "Q" => "QUEBEC", "R" => "ROMEO", "S" => "SIERRA", "T" => "TANGO", "U" => "UNIFORM", "V" => "VICTOR", "W" => "WHISKEY", "X" => "XRAY", "Y" => "YANKEE", "Z" => "ZULU");
foreach my $cw (split //, (join " ", @ARGV)) {
	if(!grep {lc($cw) eq lc($_)} keys %hnato) { print $cw; next; }
	print lc($hnato{ucfirst($cw)}) . " ";
}; print "\n"
