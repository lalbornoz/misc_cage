#!/bin/sh
# $Id$
#
trap abort_exec HUP INT QUIT PIPE TERM USR1 USR2
which mktemp wget perl jot sort >/dev/null 2>&1 || { _exit 2 ; };
#
# {{{ Exit statuses and corresponding descriptions
nexit2="missing vital commands, aborting."
nexit3="mktemp (1) failed, aborting."
nexit4="lacking search query string, aborting."
nexit5="conflicting options, aborting."
nexit6="search yielded no results, aborting."
nexit50="Unknown error"
# }}}
# {{{ subr
_exit() {
	local status="$1" ;
	[ "x${status##[0-9]*}" = "x" ] || { status=50; };

	nexit="`eval echo \$\{nexit${status}\}`"
	[ "x${nexit}" != "x" ] && {
		echo "error: ${nexit}" 1>&2 ; };
	exit ${status}
}

abort_exec() {
	rm -f "${cjar}" >/dev/null 2>&1
	printf "\naborted, exiting." ; exit 1 ;
}

_wget() {
	local argv url
	argv="--read-timeout=5 --waitretry=2 --tries=128"
	[ "x$1" = "x-" ] && {
		argv="${argv}	--post-data='user_choice=Enter'	\
				--load-cookies ${cjar}		\
				--save-cookies ${cjar}" ; shift ; };
	url="$@" ; wget ${argv} -qO- "${url}"
}

urls() {
	[ ${stdin} -eq 1 ] && { 		# List on STDIN
		for url in `cat`; do
			echo "${url}"
		done
	} || {					# Search w/ query string
		url="http://youporn.com/search?query=${query}"

		pmax=`	_wget		 ${url}		|\
			perl	-lne	'push @p, $1 if	 \
					 m,<a href="/[^"]+page=([^"]+)">[0-9]+<,;'	 \
				-e	'END { print $p[scalar(@p) - 1]; }'`
		pmax="${pmax:-0}" ; [ ${pmax} -eq 0 ] && { _exit 6 ; };

		for n in `jot ${pmax}`
		do
			for urls in `	_wget	${url}\&page=${n}			|\
					perl	-lne					 \
						'print "http://www.youporn.com/$1"	 \
						 if m,<a href="(/watch/\d+/[^/]+/)">,'	|\
					sort -u` ; do  echo "${urls}" ; done
		done ; };
}

flv() {
	local url="$1"
	_wget - `_wget "${url}"			|\
		 perl	-lne			 \
			'print $1		 \
			 if m,<a href="(http://download.youporn.com/download/\d+/[^"]+)">FLV,'`
}
# }}}
# {{{ var
cjar=`mktemp -t ypflv` || { _exit 3 ; };
# }}}
# {{{ option handling
list=0 ; stdin=0 ;
[ "x$1" = "x-r" ] && { shift ; stdin=1 ; };
[ "x$1" = "x-l" ] && { shift ; list=1 ; };

query="$@" ;
#[ ${stdin} -eq 0 ] && [ $# -gt 0 ] || { _exit 4 ; };
[ ${stdin} -eq 1 -a ${list} -eq 1 ] && { _exit 5 ; };
# }}}

for url in `urls`; do
	echo "${url}" ; [ ${list} -eq 1 ] || { flv "${url}" ; };
done

rm -f "${cjar}" >/dev/null 2>&1

# vim:ts=8 sw=8 noexpandtab foldmethod=marker
