#!/bin/sh
# $Id$
#

_AGENT_SOCKET="${HOME}/.ssh/agent.socket";
[ $# -lt 1 ] && { echo "usage: $0 <arguments to pass to ssh(1)>"; exit 1; };

cmdline="$@";
while /bin/true
do	[ -r "${_AGENT_SOCKET}" ] &&					\
	eval "env SSH_AUTH_SOCK=\"${_AGENT_SOCKET}\" ssh ${cmdline}"; sleep 2;
done;

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
