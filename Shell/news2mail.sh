#!/bin/sh
# $Id$
# Tested on OpenBSD 4.5, FreeBSD 7.1, and NetBSD 5.0.1.
# Requires:	slrnpull(1) from Slrn,
#		SuS sh(1), date(1), cat(1), and find(1),
#		mktemp(1),
#		{n,{GNU,} }Awk,
#		procmail(1) and formail(1).
#

# {{{ subr
say() {
	local _args=""; [ -z "${1##-n}" ] && { _args="-n"; shift; };
	echo ${_args} `date +"${_TS_FMT}" 2>/dev/null` "$*";
}
# }}}
# {{{ tunables
_SPOOL_PFX="${HOME}/.news"
_TS_FMT="%m/%d/%Y %H:%M:%S"
# }}}
# {{{ init
# }}}

#
# Note that slrnpull(1) likely insists on its controlling TTY to be one to decide
# over whether logging output is constrained to the log file under the /spool directory/
# or not, thereby the latter is {pruned,purged,emptied} prior to each slrnpull(1)
# invokation.
say "Running slrnpull(1)"
echo -n >| "${_SPOOL_PFX}/log" 2>/dev/null
env NNTPSERVER=newszilla6.xs4all.nl slrnpull -d "${_SPOOL_PFX}" >/dev/null 2>&1 ; _rc=$?;
cat "${_SPOOL_PFX}/log" 2>/dev/null
[ ${_rc} -ne 0 ] && { say "slrnpull(1) returned non-zero exit value, aborting."; exit 2; };


for gp in `awk '/: [0-9]+\/[0-9]+/ {					\
			sub(/:/, "", $3); sub(/\/.+$/, "", $4);		\
			print $3 ":" $4;				\
		}' "${_SPOOL_PFX}/log" 2>/dev/null`
do
	_IFS="${IFS}" ; IFS=":" ; set -- ${gp} ; IFS="${_IFS}";

	group="$1"; nposts="$2";
	say -n "Group \`${group}': "
	subdir="${_SPOOL_PFX}/news/`echo \"${group}\" | sed 's,\.$,,; s,\.,/,g;' 2>/dev/null`"

	if ! [ -d "${subdir}" -a -x "${subdir}" ]; then
		echo "corresponding subdir lacks eXecute permission bit or non-existent, ignored.";
	else
		echo "procmail(1)ing ${nposts} posts.";

		# N.B.	This Intrinsically assumes that post file names will never contain
		#	a whitespace.
		for pf in `find "${subdir}" -type f -iname '[^.]*' -print 2>/dev/null`
		do
			_maillog_fname="`mktemp -t n2mp 2>/dev/null`"
			[ $? -ne 0 ] && {
				say "  mktemp(1) returned non-zero, no /stderr/ logging will occur.";
				_maillog_fname="/dev/null";
			};

			say -n "  `basename ${pf}`: "
			cat "${pf}" | formail -i "To: ${group}" | procmail 2> "${_maillog_fname}"
			if [ $? -ne 0 ]; then
				echo "non-zero exit status, refer to \"${_maillog_fname}\" for /stderr/ output.";
			else
				echo -n "reformatted and processed, ";
				if rm -f "${pf}" 2>/dev/null; then
					echo "deleted.";
				else
					echo "was unable to rm(1).";
				fi

				[ "${_maillog_fname}" != "/dev/null" ] && { rm -f "${_maillog_fname}"; };
			fi
		done
	fi
done

# vim:ts=8 sw=8 noexpandtab foldmethod=marker
