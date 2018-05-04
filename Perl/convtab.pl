# $Id: $

use Irssi;
use Irssi::TextUI;
use strict;

use vars qw($VERSION %IRSSI);

$VERSION = "14.88";
%IRSSI = (
	authors		=> 'vxp',
	contact		=> 'irc.f1re.org #arab',
	name		=> 'convtab',
	description	=> '0x09 ({HT,<TAB>}) -> 8 spaces',
	license		=> 'ARABIC FUCK YOU LICNESE',
	url		=> 'http://truthaboutvxp.notlong.com/',
);

Irssi::signal_add_first('send text', sub {
	$_[0] =~ s/\x09/        /g;
	Irssi::signal_continue @_;
});

# vim:ts=8 sw=8 noexpandtab
