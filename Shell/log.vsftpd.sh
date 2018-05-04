#!/bin/sh
# $Id$
# Parses an /xferlog/ style FTP server access log, printing left- and
# right-justified addresses and correspondinly resolving host names
# (authority unconfirmed as per ie. RDNS,) resp.
#
# Requires:	An ftpd(8) logging w/ /xferlog/ format,
#		ISC BIND's host(1),
#		[mg]awk(1),
#		SuS conforming sort(1), sh(1), test(1), and printf(1)
#

LOG_FNAME="/var/log/vsftpd.log"
printf "%16s %s\n" "ADDRESS" "HOSTNAME"
for addr in										\
		`awk '/CONNECT: Client "[^"]+"/						\
				{							\
					match($0, /"[^"]+"/);				\
					print substr($0, RSTART + 1, RLENGTH - 2);	\
				}' ${LOG_FNAME} |					\
		 sort -k1 -u`
do
	ha=`host -t PTR "${addr}" | awk '/pointer / {print $NF}' 2>/dev/null`
	[ $? -ne 0 -o -z "${ha}" -o "${ha}" = "3(NXDOMAIN)" ] && ha="";
	printf "%16s %s\n" ${addr} ${ha}
done

# vim:ts=8 sw=8 noexpandtab
