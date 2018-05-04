#!/bin/sh
# $Id$
# 	rsync (1) wrapping script facilitating secure, transactionally logged
# {full, incremental} backups via forced command execution facility provisioned
# by sshd (8).  rsync (1) invokations are constrained to occur with a controlled
# subset of available options according to whether a full or an incremental
# backup against a priorly produced full tree to compare against is requested.
#
# Tested with:
#	* Stock bourne sh (1) and rsync v3.0.5 (protocol version 30)
#	  on FreeBSD {6,7}-RELEASE and OpenBSD v4.5-RELEASE, and
#	* GNU bash (1) v3.1.17(2)-release and rsync v2.6.8 (protocol version 29)
#	  on Slackware v11.0.
#
# Requires:
#	* SuS(?) Bourne sh (1), sleep (1), and id (1),
#	* {BSD, SuS} sed (1), and
#	* rsync (1).
#

#
# Tunables
#

LOG_PATH="${HOME}/rrsync.log"
LOG_TIMESTAMP="[%d/%m/%Y %H:%M:%S]"
SLEEP_MAX=10

# {{{ Exit statuses and corresponding format strings
#	Status	Format string
_ERR_TBL="
	1	Unknown error
	2	Unable to create log file \`%s'
	3	Unable to write to log file \`%s'

	4	Unable to touch \`%s/.rsyncd.conf'
	5	Missing vital commands in PATH
	6	Unable to determine client's IP (SSH_CONNECTION: \`%s')
	7	Missing \`SSH_ORIGINAL_COMMAND' environ (7)ment variable
	8	Command \`%s' to be executed was not \`rsync'

	9	Invalid or missing {SRC, DEST} (\`%s', \`%s') specification{,s}
	10	Missing vital option string (Remaining command line: \`%s')
	11	Unable to determine operational mode (Remaining command line: \`%s')
	12	Illegal option character \`%s' specified in \`%s'
	13	Illegal long option \`%s' specified in \`%s'
	14	Full backup requested and DESTination path \`%s' could not be created
	15	Incremental backup requested and /--backup-dir/ DESTination path \`%s' invalid or inaccessible
	16	Unable to create incremental backup destination directory \`%s'
	17	Missing vital environment variables"
# }}} 
# {{{ Wrapper subr
# Determine whether the supplied argument is a decimal integer not containing
# any characters except for /[0-9]/.
isnumber() { [ "x${1#*[!0-9]}" = "x${1}" ] && { return 0; } || { return 1; }; }

# Exits the script with the supplied argument as exit status and optionally
# formats the corresponding description employing the format string from the
# error table indexed by the supplied exit status and any possibly following
# arguments.
_exit() {
	local nolog=0;
	[ "x${1}" = "x--" ] && { nolog=1 ; shift ; } || { nolog=0; };
	local status="$1" ; isnumber "${status}" || { status=1; };

	[ 0 -eq ${nolog} ] && {
		local IFS="
";		set -- ${_ERR_TBL} ; eval local fmt=\$\{${status}\};
		fmt="${fmt:-(null)}" ; log `printf "${fmt##*[0-9]	}" $@`;
	}; exit ${status} ;
}

# Pushes the supplied arguments terminated by a newline into the current
# log file, creating it beforehand if necessary.
log() {
	[ -f "${LOG_PATH}" ] || {
		touch "${LOG_PATH}" || _exit -- 2 "${LOG_PATH}"; };
	[ -w "${LOG_PATH}" ] || _exit -- 3 "${LOG_PATH}";
	echo	"`date +\"${LOG_TIMESTAMP}\"` "		\
		"C${CLIENT_IP:--}  $@" >> "${LOG_PATH}"	;
}
# }}}
# {{{ Command line validation and transformation
# XXX document this bloody maze
validate() {
	local _src _dst _cmdline _opt ; set -- ${SSH_ORIGINAL_COMMAND} ;

	# Extract and remove the SRC and DEST arguments.
	_src="$(eval echo \$\{`expr $# - 1`\})" ; _dst="$(eval echo \$\{$#\})" ;
	   [ "x." = "x${_src}" ] && [ "x" != "x${_dst}" ]		\
	|| {	_exit 9 "${_src}" "${_dst}"; }				\
	&& {	 set -- ${@#% * *}; }; [ 2 -le $# ]			\
	|| {	_exit 10 "${@}" };

	# Determine whether to /push/ to the remote RSYNC peer or
	# to /pull/ from the latter.
	   [ "x--server" = "x${1}" ]					\
	|| {	_exit 11 "${@}"; }					\
	&& [ "x--sender" == "x${2}" ]					\
	&& {	_cmdline="${1} ${2}"		; shift 2 ; }		\
	|| {	_cmdline="${1}"			; shift ; };

	_opt="`echo \"${1}\" | sed '
	# {{{ Subset of permitted short options
		s,\.,,g;			# Backward compatibility
		s,[rlptgoD],,g;			# -a, --archive
		s,b,,g;				# -b, --backup
		s,e,,g;				# -e, --rsh[=COMMAND]
		s,H,,g;				# -H, --hard-links
		s,i,,g;				# -i, --itemize-changes
		s,v,,g;				# -v, --verbose
		s,z,,g;				# -z, --compress
		s,^-,,g;
	'`";
	# }}}
	[ "x" != "x${_opt}" ]						\
	|| {	_exit 12 "${_opt}" "${1}"; }				\
	&& {	_cmdline="${_cmdline} ${1}"	; shift 2>/dev/null ; };

	_opt="`echo \"${@}\" | sed '
	# {{{ Subset of permitted long options
		s,--backup-dir=[^ ]*,,g;	# --backup-dir=DIR
		s, ,,g;
	'`";
	# }}}
	[ "x" != "x${_opt}" ]						\
	|| {	_exit 13 "${_opt}" "${@}"; }				\
	&& {	cmdline="${_cmdline} "					\
			"--config=${HOME}/.rsyncd.conf ${@}" ;
		return 0 ; };
}
# }}}
# {{{ XXX
# XXX what
what() {
	dest="`pwd`/`basename ${dest}`/[0-9][0-9][0-9][0-9][0-1][0-9][0-3][0-9]"
	dest="`eval echo ${dest}`"
	[ "x${opt#*b}" = "x${opt}" ] && {					# Full backup
		[ -d "${dest}" ] || {
			mkdir -p "`dirname ${dest}`/`date +%C%y%m%d`" || return 17; };
		backup=0 ; cmdline="${cmdline} . ${dest}/"
	} || {									# Incremental backup
		[ -d "${dest}" ] || return 18;
		bdir="`dirname ${dest}`/`expr \( \`date +%d\` % 7 \) + 1`"	# Day of week
		[ -d "${bdir}" ] || { mkdir "${bdir}" || return 19; };
		backup=1 ; cmdline="${cmdline} --backup-dir=${bdir} . ${dest%%/}"
	};
}
# }}}

CLIENT_IP="${SSH_CONNECTION%% *}" ;
   [ -r "${HOME}/.rsyncd.conf" ]
||   touch ${HOME}/.rsyncd.conf			|| { _exit 4 "${HOME}"; }		\
&&   which sed id rsync sleep 2>/dev/null	|| { _exit 5; }		\
&& [ "x" = "x${CLIENT_IP}" ]			|| { _exit 6 "${SSH_CONNECTION}"; }	\
&& [ "x" = "x${SSH_ORIGINAL_COMMAND}" ]		&& { _exit 7; }		\
&& [ "xrsync" != "x${SSH_ORIGINAL_COMMAND}" ]	&& { _exit 8; }		\
|| {	log	"Invoked, SSH_ORIGINAL_COMMAND=\`${SSH_ORIGINAL_COMMAND}'" ;
	trap	'' hup int quit term usr1 usr2 tstp ; umask 077 ; validate ;
};

log	"Dispatching rsync(1) as \``id -nu 2>/dev/null`', "		\
	"and \`${cmdline}' as option string." ;
 rsync	${cmdline} ;
log	"Finished, exiting." ;
sleep	`_rand 1 ${SLEEP_MAX}` >/dev/null 2>&1 ;

# vim:ts=8 sw=8 noexpandtab foldmethod=marker
