# $Id: $

use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION = "14.88";
%IRSSI = (
	authors		=> 'vxp',
	contact		=> 'irc.f1re.org #arab',
	name		=> 'buntab',
	description	=> 'BUNTFARBENBUNTFARBENBUNTFARBENBUNTFARBENBUNTFARBEN',
	license		=> 'ARABIC FUCK YOU LICNESE',
	url		=> 'http://truthaboutvxp.notlong.com/',
);


sub sig_complete {
	my ($complist, $window, $word, $linestart, undef) = @_;
	my ($witem) = ($window->{active});
	my ($compchar, $compnick) = (Irssi::settings_get_str('completion_char'), undef);

	return unless ($witem->{'type'} eq 'CHANNEL' && $word && !$linestart &&
		       rindex($word, $compchar) == -1);

	foreach my $nick ($witem->nicks()) {
		if(!index(lc($nick->{'nick'}), lc($word))) {
			my (@c) = (int(rand(14) + 1), int(rand(14) + 1));
			while($c[0] eq $c[1]) { $c[1] = int(rand(14) + 1); };

			$compnick = $nick->{'nick'} . "\003${c[0]},${c[1]}${compchar}";
			push @$complist, $compnick;
		};
	};
}

Irssi::signal_add_first('complete word', 'sig_complete');

# vim:ts=8 sw=8 noexpandtab
