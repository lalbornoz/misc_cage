#!/bin/sh
# Anonymous/controlled-access rsync(1) via SSH command
# execution/dispatching wrapper script meant to be enforced
# as per-pubkey command in ie. ``~/.ssh/authorized_keys''.
#  -- by vxp/arab, deployed/tested on ``azhar.local'' running
#     FreeBSD 7.0-RELEASE  <vxp@gmx.net>, vxp on EFnet. 
# $Id: $
#

# Ignore the relevant subset of POSIX signal(3)s.
trap '' hup int quit term usr1 usr2

# Make sure we're being invoked via sshd(8).
[ -z "${SSH_CONNECTION}" ] && {
	echo "$0 is meant to be accessed via ssh(1); exiting."; exit 2; };

# Minimal amount of sanity checking before we continue:
export PATH=/bin:/usr/bin:/usr/sbin:/usr/libexec:/usr/pkg/bin
which cut logger rsync jot sleep >/dev/null 2>&1 || exit 3;
_UID="${UID:-`id -u 2>/dev/null`}"; _GID="${GID:-`id -g 2>/dev/null`}";
[ -z "${_UID}" -o -z "${_GID}" ] && exit 4;

# ...handling an incoming client's connection.
CLIENT_IP="`echo ${SSH_CONNECTION} | cut -f1 -d\ `" 2>/dev/null
[ -z "${CLIENT_IP}" ] && {
	logger -is -t pubrsync -p user.debug "unable to determine client's IP"; exit 6; };

# Dispatch rsync(1), thereby transparently establishing an SSH-
# configured and encrypted communication channel between both
# peers or simply bail out if anything else but ``rsync'' was
# specified as command to execute.
case "${SSH_ORIGINAL_COMMAND}" in
	# rsync(1)
	rsync\ *)
		logger -is -t pubrsync "${CLIENT_IP} requested \`${SSH_ORIGINAL_COMMAND}', dispatching rsync (1) as \``id -nu 2>/dev/null`'." 2>/dev/null
		rsync --config=etc/rsyncd.conf --server --daemon .
		;;

	# Unknown, deny
	*)
		logger -is -t pubrsync -p security.warn "${CLIENT_IP} tried to execute \`${SSH_ORIGINAL_COMMAND}'"
		;;
esac

# Enforce a pseudo-random delay to prevent us from exhibiting
# any perceivable patterns in regard to response time, etc.
sleep `jot 1 1 5` >/dev/null 2>&1

# vim:ts=8 sw=8 noexpandtab
