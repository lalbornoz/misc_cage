#!/usr/pkg/bin/perl
# $Id$
#

# {{{ use
use strict; use warnings;
use feature qw(:5.10 switch);
# }}}
# {{{ use constants
use constant JSON_RE => qr,\\*"(tabs|title|url)\\*?":(?:\\*"([^"]*?)\\*")?,;
use constant HTML => {
	# {{{ head: HTML HEADer and BODY header
	"head" => <<EOF,
<!DOCTYPE html PUBLIC
	"-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
	<head>
		<title>HTML__FILE__</title>
		<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		<meta name="id" content="\$Id: \$" />
		<link rel="stylesheet" type="text/css" href="styles.css" />
	</head>
	<body>
EOF
	# }}}
	# {{{ tab_ul_new: Tab UL header
	"tab_ul_new" => <<EOF,
		<ul>
			<li>
				Tab: <a href="HTML__URL__">HTML__TITLE__</a>
				<ol>
EOF
	# }}}
	# {{{ tab_ul_end: Tab UL footer
	"tab_ul_end" => <<EOF,
				</ol>
			</li>
		</ul>
EOF
	# }}}
	# {{{ tab_ol_item: Tab URL list item
	"tab_ol_item" => <<EOF,
					<li>
						<a href="HTML__URL__">
							HTML__TITLE__
						</a>
					</li>
EOF
	# }}}
	# {{{ footer: HTML footer
	"footer" => <<EOF,
	</body>
</html>

<!--
	vim:ts=2 sw=2 tw=80 noexpandtab foldmethod=marker encoding=utf-8
  -->
EOF
	# }}}
};
# }}}
# {{{ our variables
our ($HTML__FILE__, $HTML__URL__, $HTML__TITLE__) = (undef, undef, undef);
# }}}
# {{{ subr
sub __eval {
	my $html = shift;
	foreach my $vname (grep {-1 != index($_, "HTML__")} (keys %{*main::})) {
	no strict qw(refs);
		$html =~ s,$vname,$$vname,g;
	}; return $html;
}
# }}}

die "usage: $0 file" unless (defined($ARGV[0]) && -r ($HTML__FILE__ = $ARGV[0]));
open(my $fh, "<", $HTML__FILE__) or die "open: $!";
local $/ = '';  my $json = <$fh>; close $fh;

print __eval(HTML->{"head"});
my ($open_tab, $new_tab) = (0, 0);
while($json =~ m,@{[ JSON_RE ]},g) {
	given($1) {
		when("tabs") {
			print __eval(HTML->{"tab_ul_end"}) if (1 <= $open_tab);
			$open_tab = ~($new_tab = 1);
		};

		when("title") {
			$HTML__TITLE__ = $2;
			$HTML__URL__ = "about:blank" unless defined($HTML__URL__);
			if(1 <= $new_tab) {
				print __eval(HTML->{"tab_ul_new"}); $new_tab = 0; $open_tab = 1;
			}	else { print __eval(HTML->{"tab_ol_item"}); };
			$HTML__URL__ = $HTML__TITLE__ = undef;
		};

		when("url") { $HTML__URL__ = $2; };
	};
}

print __eval(HTML->{"tab_ul_end"}) if(1 <= $open_tab);
print __eval(HTML->{"footer"});

# vim:ts=2 sw=2 tw=80 noexpandtab foldmethod=marker encoding=utf-8
