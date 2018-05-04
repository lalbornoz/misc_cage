#!/bin/sh
# $Id: amal.arabs.ps [NetBSD/i386 v5.1-RELEASE] $
# $Author: Lucio `vxp' Albornoz <l.illanes@gmx.de> <irc://irc.arabs.ps/arab> $
#

_LOGNAME="${LOGNAME:-`id -nu 2>/dev/null`}" || exit 1 ;
_AGENT_LINK="${HOME}/.ssh/agent.socket" ;
_AGENT_BASEPATH="/tmp" ;
_AGENT_GLOB="ssh-*" ;
_AGENT_FIFO_GLOB="agent.[0-9]*" ;
_AGENT_PATTERN="*agent." ;
_E="\x1b\x5b" ; _B="${_E}1;33;37m" ; _U="${_E}4m" ; _R="${_E}0m";

yflag="${1#-}" ;

_agent_sockets="" ; _agent_sockets_rm="";

printf "${_B}find${_R}${_U}(1)${_R}ing available SSH agent sockets ";
printf "belonging to ${_B}${_LOGNAME}${_R}.\n" ;

for	 _agent_path in							\
	`find	"${_AGENT_BASEPATH}"					\
		-user "${_LOGNAME}" -type d				\
		-iname "${_AGENT_GLOB}" 2>/dev/null`;
do	for	 _agent_socket in					\
		`find	"${_agent_path}"				\
			-user "${_LOGNAME}" -type s			\
			-iname "${_AGENT_FIFO_GLOB}" 2>/dev/null`;
	do	_agent_pid="${_agent_socket#${_AGENT_PATTERN}}";
		printf " ${_B}*${_R} Found ${_U}${_agent_socket}${_R} ";
		printf "(PID: ${_B}${_agent_pid}${_R}";
		ps -lp "${_agent_pid}" >/dev/null 2>&1 && {
			printf ")\n" ;
			_agent_sockets="${_agent_sockets} ${_agent_socket}";
		} || {	_agent_sockets_rm="${_agent_sockets_rm} ${_agent_socket}" ;
			printf ", ${_B}dead${_R}.)\n";
		};
	done ;
done ;

[ -n "${_agent_sockets_rm}" ] && {
	printf "\n" ;
	printf "Removing the following dead SSH agent sockets, "
	printf "including their parent directories:\n";
	for _agent_socket in ${_agent_sockets_rm};
	do	printf " ${_B}*${_R} ${_U}${_agent_socket}${_R}\n"; done ;
		[ -z "${yflag}" ] || [ -n "${yflag##[yY]}" ] && {
			printf "Continue? [yN] " ; read yflag;
		} ; case "${yflag}" in 
	[yY])	for _agent_socket in ${_agent_sockets_rm};
		do	rm -rf "`dirname \"${_agent_socket}\"`"; done ;
		;;

	*)	;;
	esac ;
};

[ -n "${_agent_sockets}" ] && {
	for _agent_socket in ${_agent_sockets};
	do	printf "Link ${_U}${_agent_socket}${_R} to " ;
		printf "${_U}${_AGENT_LINK}${_R}? [yN] " ;
printf "${yflag}";
		[ -z "${yflag}" ] || [ -n "${yflag##[yY]}" ] && {
			read yflag;
		} || {	printf "y\n" ; } ; case "${yflag}" in
		[yY])	ln -fs "${_agent_socket}" "${_AGENT_LINK}" ;
			break;
			;;

		*)	;;
		esac ;
	done ;
} || {
	printf "(0 active SSH agent sockets remaining)\n";
};

printf "Exiting.\n";

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
