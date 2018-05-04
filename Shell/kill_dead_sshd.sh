#!/bin/sh
# $Id: amal.arabs.ps [NetBSD/i386 v5.1-RELEASE] $
# $Author: Lucio `vxp' Albornoz <l.illanes@gmx.de> <irc://irc.arabs.ps/arab> $
#

_TTY="`basename \"\`tty\`\"`" || exit 1 ;
_LOGNAME="${LOGNAME:-`id -un`}" || exit 2 ;
_E="\x1b\x5b" ; _B="${_E}1;33;37m" ; _U="${_E}4m" ; _R="${_E}0m";
yflag="${1#-}" ;

printf "${_B}kill${_R}${_U}(1)${_R}ing all ${_B}sshd${_R} ${_U}(8)${_R} " ;
printf "processes beloging to ${_B}${_LOGNAME}${_R} whose controlling " ;
printf "terminal is not ${_U}${_TTY}${_R}.\n" ;

[ -z "${yflag}" ] || [ -n "${yflag##[yY]}" ] && {
	printf "Continue? [yN] " ; read yflag;
};

case "${yflag}" in
[yY])	for _pid in							 \
	`pgrep	-lf -U "${_LOGNAME}"					|\
	 awk	   '/sshd: '"${_LOGNAME}"'/				 \
		&& !/sshd: '"${_LOGNAME}"'@'"${_TTY}"'/ { print $1 }'`;
	do	printf "${_B}kill${_R}${_U}(1)${_R}ing process ${_pid}: ";
		kill "${_pid}" && printf "done\n" ;
	done ;

	;;
*)	;;
esac;	printf "Exiting.\n";

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
