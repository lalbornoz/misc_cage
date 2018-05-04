#!/bin/sh
# $Id: amal.arabs.ps [NetBSD/i386 v5.1-RELEASE] $
# $Author: Lucio `vxp' Albornoz <l.illanes@gmx.de> <irc://irc.arabs.ps/arab> $
# XXX for `amal.arabs.ps' running NetBSD/i386 v5.1
#	-- periodic system maintenance
#
# Exit codes returned by this shell script [cf. sysexits (3)]:
#	EX_SOFTWARE	70	A signal prompting abnormal script termination
#				was received.
#	EX_OSERR	72	No world-writable temporary directory was
#				available (e.g. as per TMPDIR.)
#	EX_CANTCREAT	73	mktemp (1) failed to create a temporary file
#				deemed to be employed as log file.
#	EX_CONFIG	78	The backup specification file is non-existent,
#				unreadable, or empty.
#

#
# Global variables, default values, and subr
#

TMPDIR="${TMPDIR:-/tmp}" ;		# [cf. environ (7)]
HOST="`hostname`" ;	# Current host system name
DATE="`date`" ;		# Current system time
_CONF_PATH="${1:-/etc/backup.spec}" ;	# Backup specification file path name
_LOG_PATH="" ;		# Log file path name
_MAIL_LATTACH="" ;	# Slash (`/') separated list of attachment file names
_MAILTO="root" ;	# Logged output mail recipient and subject
_MAIL_SUBJECT="system backup output for ${HOST} on ${DATE}" ;
_DEFAULT_UMASK="027" ;	# Default umask (1), cf. backup.spec (5)
_BACKUP_PATH="/var/backup" ;		# [cf. backup.spec (5)]
_IFS="${IFS}" ;		# Temporarily saved IFS shell variable
_IFS() {		# Temporary IFS shell variable {,re}storing subr
[ 0 -eq $# ] && IFS="${_IFS}" || _IFS="${1}" ; };

#
#	Change the working directory to a temporary location and produce aswell
# as create a temporary file, taking the name of either the shell or the name
# of this script as prefix, and redirect stdout aswell as stderr to it, yielding
# a log file.  Fail immediately if unable cd (1) or to create or write to the
# latter. TODO use tee(1); consider std{err,out} buffering differences
cd "${TMPDIR}" || exit 72 ; _LOG_PATH="`mktemp -qt \"${0##*/}\"`" || exit 73 ;
exec >| "${_LOG_PATH}" 2>&1;

#
#	trap (1) shell exit aswell as an appreciable subset of signals to
# ensure that the accumulated backup process log always be mailed to
# the target recipient and that clean script termination take place, if
# interrupted.  Do note that mail (1) and cleanup is dispatched from
# within a subshell so as not to delay script exit given the need to
# terminate abnormally.
fini() {(
	#
	# Compile a whitespace (SP, ` ') separated argument list from the global
	# slash (` ') separated list of attachment file names to mail (1) along
	# with the logged output.
	local MAIL_ARGS="" ; _IFS "/" ;
	for _fname in ${_MAIL_LATTACH};
	do	MAIL_ARGS="${MAIL_ARGS:+${MAIL_ARGS} }-a ${_fname}" ;
	done;	_IFS;

	# Call mail (1) and remove the temporary log file.
	mail -s "${_MAIL_SUBJECT}" ${MAIL_ARGS} "${MAILTO}" < "${_LOG_PATH}" ;
	rm -f "${_LOG_PATH}";
)};

trap fini EXIT ; trap "echo \"[received signal, aborting]\" ; exit 70;"	\
SIGHUP SIGINT SIGTERM SIGUSR1 SIGUSR2;

# XXX
printf	"Performing system backup for %s on %s invoked by %s\n"		\
	"${HOST}" "${DATE}" "${LOGNAME}";

#
#	Iteratively read (1) specification lines from the backup specification
# file, ignoring comments and empty lines, updating global variables from
# tunable modifying lines in the former.  Produce a warning and exit (1)
# indicating failure if mentioned file is non-existent, unreadable, or empty.
[ -s "${_CONF_PATH}" ] && [ -r "${_CONF_PATH}" ] || {			
	echo "missing backup specification file \`${_CONF_PATH}', exiting." ;
	exit 78;
} && {
	printf "Reading backup specification from %s\n" "${_CONF_PATH}";
	while read user spec file type opts dayfreq max;
	do	case "${user}" in
		\#*|"")	continue; ;;
		*=*)	vname="" ; tunable="${user%=*}" ; value="${user#*=}";
			case "${tunable}" in
			mailto)		vname="_MAILTO" 	; ;;
			mail_subject)	vname="_MAIL_SUBJECT" 	; ;;
			default_umask)	vname="_DEFAULT_UMASK"	; ;;
			backup_path)	vname="_BACKUP_PATH"	; ;;
			*)	printf	"\t<ignoring unknown tunable \`%s', "\
					"${tunable}" ;
				printf	"offending line=\`%s'>\n" "${user}";
			esac	; ;;
		*)		printf	"\t<%s, %s, %s, %s, %s, %s, %s>\n"\
					"${user}" "${spec}" "${file}"	\
					"${type}" "${opts}" "${dayfreq}"\
					"${max}";
				  ;;
                esac
        done < "${_CONF_PATH}";

	#
	# XXX
	printf "\nBackup configuration:\n" ;
	printf "Default umask (1): %s\n" "${_DEFAULT_UMASK}" ;
	printf "Target backup root path: %s\n" "${_BACKUP_PATH}" ;
	printf "\n";
};

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker filetype=sh
