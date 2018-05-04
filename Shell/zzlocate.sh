#!/bin/sh
#
[ $# -eq 0 ] && { echo "usage: $0 <ip|hostname> [ ... ]"; exit 1; };
_ZONE="zz.countries.nerd.dk"	# v- lorf
_REV_REGEX='^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})'

#
# Iterate over the arguments passed to the shell script, taking these
# as a sequence of {host names,IPv4 addresses} and determining the
# corresponding ISO 3166-1 country code via the DNS TXT record service
# (refer to <http://countries.nerd.dk/more.html> for details.)
#

while [ $# -gt 0 ]
do
	# Qualify and the current argument as either an IPv4 presentation
	# format address string (dotted decimal) or a host name (fallback,)
	# resolving the latter to the former given the necessity.
	hname="$1"
	spec="`echo \"${hname}\" |
	       sed -En '/^([0-9]{1,3}\.){3}[0-9]{1,3}/p' 2>/dev/null`"
	if [ -z "${spec}" ]; then
		addr="`dig \"${hname}\" IN A +short 2>/dev/null | tail -n1`";
		[ -z "${addr}" ] && { echo "-- unable to resolve \`${hname}', ignored";
				      shift; continue; };
	else
		addr="${spec}"
	fi

	# Approach the DNS server with the reversed mapping of the IPv4
	# address in question prefixed to the configured zone name,
	# querying its `TXT' record.
	hname="`echo ${addr} |							\
		sed -En "s/${_REV_REGEX}/\\4.\\3.\\2.\\1/p" 2>/dev/null`.${_ZONE}";
	cc="`dig "${hname}" IN TXT +short`"
	[ -z "${cc}" ] && { echo "-- unable to query TXT record for \`${addr}' (via \`${hname}'), ignored";
			    shift; continue; };
	echo "ISO 3166-1 country code for \`${addr}': `echo \"${cc}\" | sed 's/"//g'`"

	# Shift the positional parameters by one to fetch the next
	# argument in the next iteration.
	shift
done

# vim:ts=8 sw=8 noexpandtab
