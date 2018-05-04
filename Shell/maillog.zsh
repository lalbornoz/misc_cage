#!/usr/bin/env zsh
# $Id$
#

# Tunables
EMAIL_TO="infamousx@gmail.com";
EMAIL_CC=(	receipts@trialpay.com ne2k@hotmail.com			\
		help.im.alive@live.com atsvision@hotmail.com		\
		helixis@hotmail.com ass3mbl3r@hotmail.com		\
		zubwolf@gmx.net vanek026@gmail.com			\
		superzevs@hotmail.com elsdoneu@hotmail.com		\
		m1z3ry@hotmail.com embalmed@gmail.com			\
		tripps6969@hotmail.com racheldabrown@gmail.com		\
		rockos_modern_maddness@hotmail.com parts101@hotmail.com	\
		pc_devil_2000@hotmail.com karbraxis@gmail.com		\
		vap0r@flashmail.com voss.james@live.com			\
		wispurs@msn.com supers@animenfo.com lupert75@gmail.com	\
		fassool_forever@hotmail.com gluttony@gmail.com		\
		life.is.just.a.dream@hotmail.com solybot@gmail.com	\
		babyguh@gmail.com blackdude@gmail.com			\
		jacqueline.singh@gmail.com timecop@gmail.com		\
		n3rd@yahoo.com arezouli@gmail.com liquidlaurie@shaw.ca	\
		xoxoleezaxoxo@yahoo.com	aurelie816@hotmail.com 		\
		mbaehr@gmail.com a43@scudly.com slapballs@gmail.com	\
		shelbylynnnelson@hotmail.com vikkilea@gmail.com		\
		crunkfxckingcore@hotmail.com markus.graf@hochschule.li	\
		shannonlykinjosh@hotmail.com vyourman@yahoo.com		\
		david.pulis@gmail.com dpulis@ubmglobaltrade.com		\
		seandonn@gmail.com dontasklaisa@hotmail.com		\
		gamedude99@hotmail.com cumaddiction@hotmail.com		\
		hootersknockers@hotmail.com a7madi_10@hotmail.com	\
		agc@NetBSD.org mrg@NetBSD.org pooka@NetBSD.org		\
		chs@NetBSD.org yamt@NetBSD.org matt@NetBSD.org		\
		christos@NetBSD.org alexander.rowson@gmail.com		\
		lightningfan@mail.com brenna.mcguire86@gmail.com	\
		thizzley@gmail.com schische@gmx.de			\
		felix-bloginput@fefe.de	riverside@sd43.bc.ca		\
		srobinson@sd43.bc.ca sroos@sd43.bc.ca			\
		tclerkson@sd43.bc.ca christine.boisvert@hotmail.com	\
		christine.boisvert@telus.net wok@mancfags.com		\
		thomaspension@gmail.com receipts@trialpay.com		\
		support@he.net arezrasouli@gmail.com kouper@gmail.com	\
);

EMAIL_SUBJECT="/!\\\\ FUCK YEAH AMERICA /!\\\\";
LOG_PATH="${HOME}/.irssi/logs/SandNET/#arab.log";

# Subr
fini() { [ "x${TMP_PATH}" != "x" ] && { rm -f "${TMP_PATH}" 2>/dev/null; }; };
trap fini HUP INT QUIT PIPE TERM USR1 USR2;
TMP_PATH="`mktemp -qt maillog.XXXX`" || exit 2;


printf	"To: ${EMAIL_TO}\nCc: ${(j:, :)EMAIL_CC}\n"	>| "${TMP_PATH}";
printf	"Subject: ${EMAIL_SUBJECT}\n"			>> "${TMP_PATH}";
printf	"\n\n"						>> "${TMP_PATH}";
tail	-n10000 "${LOG_PATH}" | sed -n '1!G;$p;h;' |\
perl	/home/arab/bin/fixlog.pl			>> "${TMP_PATH}";

[ "x-v" = "x${1}" ] && { cat				   "${TMP_PATH}";
	printf "send [Y/n] "; read choice;
	case "${choice}" in
	[yY]*)	echo "sending"  ; ;;
	[nN]*|*)
		echo "not sent" ; fini ; exit 0 ;;
	esac;
};

msmtp	-t						 < "${TMP_PATH}";
fini;

# vim:ts=8 sw=8 noexpandtab filetype=sh
