#!/bin/sh
# $Id$
# Parses the pertinent lines inside /auth.log/ produced by sshd(8) for
# failed authentications, printing the corresponding user name,
# local TCP port number, address and the unauthenticated host name it resolves
# to.
#
# Requires:	An sshd(8) installation with a sufficiently elevated `LogLevel',
#		syslogd(8) configured logging to /auth.log/ as required,
#		ISC BIND's host(1),
#		[mg]awk(1),
#		SuS conforming sort(1), sh(1), test(1), and printf(1)
#

LOG_FNAME="/var/log/authlog"
printf "%-16s  %-14s  %-39s %s\n" "USERNAME" "AUTHENTICATOR" "ADDRESS" "HOST NAME"
for line in										\
		`awk '									\
		/sshd\[[0-9]+\]: Failed/						\
				{							\
					match($0, /[^ ]+ for [^ ]+ from [0-9a-f.:]+ port [0-9]+ [^ ]+/);	\
					split(substr($0, RSTART, RLENGTH), a);		\
					printf "%s%s%s:%s\n",			\
						a[3], a[5], a[8], a[1];			\
				}							\
		/sshd\[[0-9]+\]: Invalid/						\
				{							\
					match($0, /user [^ ]+ from [0-9a-f.:]+/);	\
					split(substr($0, RSTART, RLENGTH), a);		\
					print a[2] "" a[4] "" "-";			\
				}' ${LOG_FNAME} | sort -k1`
do
	_IFS="${IFS}"; IFS=""; set -- ${line}; IFS="${_IFS}";
	user="$1"; addr="$2"; auth="$3";
	[ -n "${user}" -a -n "${addr}" -a -n "${auth}" ] || continue;
	ha=`host -t PTR "${addr}" | awk '/pointer / {print $NF}' 2>/dev/null`
	[ $? -ne 0 -o -z "${ha}" -o "${ha}" = "3(NXDOMAIN)" ] && ha="";
	printf "%-16s [%-14s] %-39s %s\n" "${user}" "${auth}" "${addr}" "${ha}"
done

# vim:ts=8 sw=8 noexpandtab
