#!/bin/sh
#

_DEFAULT_LOGFILE="/home/pub/modules/backup.ns1/var/log/nginx/www.arabs.ps.access.log" ;
for line in `awk '						 \
		{ ips[$1]++ }					 \
	END	{ for(ip in ips) { print ips[ip] ":" ip; }; }'	 \
	"${1:-${_DEFAULT_LOGFILE}}"				|\
	sort -nk1`
do	_IFS="${IFS}" ; IFS=":" ; set -- ${line} ; IFS="${_IFS}" ;
	count="${1}" ; ip="${2}" ;
	printf	"%-5d %-16s %s\n"				 \
		"${count}" "${ip}"				 \
		"`dig -4t PTR -x \"${ip}\" +short +time=1 | head -n1`";
done

# vim:ts=8 sw=8 noexpandtab
