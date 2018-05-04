#!/bin/sh
# $Id$
# Requires:	BSD sh(1), test(1), sed(1), and grep(1),
#		Awk, ed(1),
#		formail(1),
#		{Free,Net,Open}BSD-style md5(1).
#

which md5 formail sed awk ed >/dev/null 2>&1 || exit 0;
[ -f ${HOME}/.killfile ] || {
	[ $# -eq 0 ] && { exit 0; };
	touch ${HOME}/.killfile || exit 1; }

[ $# -eq 0 ] && {			# Kill sender address
	for em in `	formail -tzxFrom: |\
			sed 's,^.*<\(.*\)>.*$,\1,'`
	do
		echo `md5 -s ${em} | awk '{print $NF}'` \# ${em}
	done >> ${HOME}/.killfile; exit 0; };

[ $# -eq 1 -a "x$1" = "x-d" ] && {	# Unkill sender address
	for em in `	formail -tzxFrom: |\
			sed 's,^.*<\(.*\)>.*$,\1,'`
	do
		printf	"/^`md5 -s \"${em}\" | awk '{print $NF}'` #/d\nwq\n"	|\
		ed -s	${HOME}/.killfile 2>/dev/null
	done; exit 0; };

[ $# -eq 1 ] && {			# exit (1) if sender address killed
	{ grep -q "`md5 -s \"$1\" | awk '{print $NF}'`	\
		" ${HOME}/.killfile; } 2>/dev/null || exit 1; };

exit 0					# ?

# vim:ts=8 sw=8 noexpandtab
