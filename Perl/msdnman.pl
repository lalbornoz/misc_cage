#!/usr/bin/env perl
# $Id$
local $\ = "\n";
# {{{ Massive wall of text
# msdnman.pl (c) 2010 by Lucio `vxp' Albornoz <l.illanes@gmx.de>
#
# 	Queries the MSDN for the specified keyword via Google[1], formatting the
# resulting HTML to resemble the man (1) command's output[XXX].
# Replaces the almost archetypally worthless let alone gigantic fucking
# maze of C# garbage of the same name[2].
#
#	Do note that whilst an alternative service of retrieval has been
# provisioned free of cost for some time as part of the `MSDN/TechNet
# Publishing System (MTPS) Content Service'[3], it invariably delivers HTML
# within an XML container to whomever would bother with feeding it SOAP,
# effectively rendering an incredibly expensive and inefficient replacement
# for the above drawn out method.
# 	As of Nov 2010, no form of indexing nor searching[4,5] is available
# either, as if to cast a zenith of inexplicably worthless irrelevance upon
# the already sufficiently dubious amassment of rubbish thoroughly drenched
# in aesthetically app{ea,al}ling salivations.
# }}}
# {{{ TODO
# 	* Cache either contentId-to-keyword maps (e.g. ms682658 => ExitProcess,)
# 	  or entire ({,un}rendered) pages (or both)
# 	* Socket I/O and HTTP timeout[s]
#	* fuck up Zz$fetchGetURL all over again
# }}}
# {{{ Reference URL
# [1] <https://code.google.com/apis/ajaxsearch/documentation/reference.html#_intro_fonje>
# [2] <http://services.msdn.microsoft.com/ContentServices/ContentService.asmx>
# [3] <https://code.google.com/p/msdnman/>
# [4] <http://msdn.microsoft.com/en-us/magazine/cc163541.aspx>
# [5] <http://services.msdn.microsoft.com/>
# }}}
#
# {{{ use
use strict; use warnings;
use File::Spec; use File::Path qw(make_path); use Fcntl;
use HTTP::Lite 2.2; use URI::Escape; use HTML::TreeBuilder;
# }}}
# {{{ use constant
use constant CACHE_PATH		=> File::Spec->catfile($ENV{"HOME"}, ".msdnman");
use constant GOOGLE_URL		=> "http://ajax.googleapis.com/ajax/services/search/web?v=1.0&hl=en&rsz=1&q=";
use constant GOOGLE_QUERY	=> "allintitle: site:msdn.microsoft.com/en-us/library";
# }}}
# {{{ MSDN document HTML tag tree matching table
use constant TAG_TBL		=> [
	{
		"name"		=> "NAME",
		"criteria"	=> ["_tag", "DIV", "class", "title"],
	},
	{
		"name"		=> "SYNOPSIS",
		"criteria"	=> ["_tag", "DIV", "class", "libCScode"],
		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
	},
	{
		"name"		=> "DESCRIPTION",
		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
		"before"	=> ["_tag", "H3"],	# Ordinarily /Syntax/
	},
	{
		"name"		=> "DESCRIPTION",
		"criteria"	=> ["_tag", "DL"],
		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
		"after"		=> ["_tag", "SPAN", "id", "ctl00_mainContentContainer_ctl01"],
	},
#	{
#		"name"		=> "RETURN VALUE",
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "H3"],	# Ordinarily /Return Value/ ... /Remarks/
#	},
#	{
#		"name"		=> "REMARKS",
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "H3"],	# Ordinarily /Remarks/ ... /Examples/
#	},
#	{
#		"name"		=> "EXAMPLES",
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "H3"],	# Ordinarily /Examples/ ... /Requirements/
#	},
#	{
#		"name"		=> "REQUIREMENTS",
#		"criteria"	=> ["_tag", "TABLE"],
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "H3"],	# Ordinarily /Requirements/
#	},
#	{
#		"name"		=> "SEE ALSO",
#		"criteria"	=> ["_tag", "DL"],
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "H3"],	# Ordinarily /<a id="see_also"><!----></a>See Also/
#	},
];
# }}}
#

my ($query, $http, $body, $status, $url) = ($ARGV[0] or die "usage: $0 query");
make_path(CACHE_PATH) or die "makepath(". CACHE_PATH ."): $!"
unless ((-e CACHE_PATH) && (-d CACHE_PATH));

# XXX consult cache, issue Google search query, update cache
$http = new HTTP::Lite or die "HTTP::Lite->new(): $@"; $http->http11_mode(1);
$status = $http->request(GOOGLE_URL . uri_escape(GOOGLE_QUERY ." ". $query))
or die "HTTP::Lite->request(): $!";

unless (($body = $http->body()) && $body =~ m,"responseStatus":\s*([0-9]+),
&& (($status = $1) == 200)) { die "Malformed response from Google ($status)"; };
($url) = ($body =~ m,"url":"(.+?)",) or die "empty response from Google";

# XXX consult cache, fixup URL, issue MSDN query, update cache
my ($oid) = ($url =~ m,/([^/()]+)[^/]*?\.aspx?$,) or die "invalid MSDN URL $url";
sysopen(CACHE, File::Spec->catfile(CACHE_PATH, $oid), O_RDWR | O_CREAT)
or die "sysopen: $!";
if (-s File::Spec->catfile(CACHE_PATH, $oid)) { local $/; $body = <CACHE>; }
else {	$url =~ s/(\.aspx?)$/()$1/ unless ($url =~ m/\(,?.*?\)\.aspx?$/);
	$url =~ s/\(,?(.*?)\)(\.aspx?)$/($1,printer)$2/; $http->reset();
	$http->request($url) or die "HTTP::Lite->request(): $!";
 	print CACHE ($body = $http->body());
};	close CACHE  or die "close: $!";

# XXX parse HTML
my $tree = HTML::TreeBuilder->new_from_content($body)
or die "HTML::TreeBuilder->new_from_content(): $@"; $tree->elementify();
foreach my  $section (my (@sections) = (@{&TAG_TBL})) {
	my ($n); die unless ($section->{"criteria"} or $section->{"before"}
	or $section->{"after"}); $n = $tree->look_down(@{$section->{'parent'}})
	if $section->{'parent'};

#	{
#		"name"		=> "DESCRIPTION",
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"before"	=> ["_tag", "H3"],	# Ordinarily /Syntax/
#	},
#	{
#		"name"		=> "DESCRIPTION",
#		"criteria"	=> ["_tag", "DL"],
#		"parent"	=> ["_tag", "DIV", "id", "mainSection"],
#		"after"		=> ["_tag", "SPAN", "id", "ctl00_mainContentContainer_ctl01"],
#	},

	$n = ($n or $tree)->look_down(@{$section->{'criteria'}})
	if $section->{'criteria'};
	print $section->{'name'} .": ". (($n && $n->as_text()) or "(null)");
	print "CHILD"; foreach my $key (keys %$n) { print "$key=". $n->{$key}; };
	print "PARENT"; foreach my $key (keys %{$n->{"_parent"}}) { print "$key=". $n->{"_parent"}->{$key}; };
	print "-----";
};

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
