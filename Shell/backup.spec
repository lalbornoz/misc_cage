# $Id: amal.arabs.ps [NetBSD/i386 v5.1-RELEASE] $
# $Author: Lucio `vxp' Albornoz <l.illanes@gmx.de> <irc://irc.arabs.ps/arab> $
# backup.spec (5) for `amal.arabs.ps' running NetBSD/i386 v5.1
#       -- XXX
#
#	Empty lines and lines starting with a hash character (`#') are treated
# as comments and ignored.  Every other line is considered either setting or
# modifying a tunable, or a backup whose format is indicated below.
#
#	Lines modifying or setting a tunable must start with the name of the
# tunable in question followed by an equality sign (`=',) and the new value
# to set, enclosed in quotation marks (`'') or `"') if necessary, following
# sh (1) syntax and semantics.
#
#	Valid tunables are:
# mailto		XXX
# mail_subject		XXX
# default_umask		XXX
# backup_path		XXX
#

mailto="root"
mail_subject="daily backup output for ${_HOSTNAME}"
default_umask="027"
backup_path="/home/backup"

#
# user[:group[:umask]]	spec		file				type	opts		dayfreq	max
bint			seeborg		/home/bint/seeborg.*		rsync	rw		5	14
bint			eggdrop.SandNET	/home/bint/eggdrop		rsync	rw		7	7
_minecraft		etc		/home/_minecraft/hMod131	rsync	rw		7	7
_minecraft		world		/home/_minecraft/world		rsync	rw		3	14

arab			Mail		/home/arab/Mail			rsync	rw		7	7
arab			dotfiles	/home/arab			rsync	rw		30	6
arab			files		/home/arab/files		rsync	rw		7	7
arab			irclogs		/home/arab/.irssi/logs		rsync	rw		30	6
arab			sandnet		/home/arab/files/sandnet	rsync	rw		14	7
arab			shinit		/home/arab/.shinit/		rsync	rw		30	6

root			crontab		/var/cron/tabs			rsync	rw		7	14
root			etc		/etc				rsync	rw		7	14
root			pkg.etc		/usr/pkg/etc			rsync	rw		7	14
named:wheel		named		/var/chroot/named		rsync	rw		7	7
root			log		/var/log			rsync	rw		7	14	

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker filetype=sh
