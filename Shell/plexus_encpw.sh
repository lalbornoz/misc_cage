#!/bin/sh
#
# Tested on:
# o FreeBSD v9.1-RELEASE
#

#
# Tunables
_PASSWORD_REGEX='^[[:space:]]*password[[:space:]]*=[[:space:]]*"[^"]\+"[[:space:]]*;[[:space:]]*$';
_PASSWORD_NENCRYPT_REGEX='^[[:space:]]*encrypted[[:space:]]*=[[:space:]]*no[[:space:]]*;$';
_REHASH_IRCD_CMD="pkill -HUP ircd";
_TIMESTAMP_FMT="%Y/%m/%d %H:%M:%S";

#
# Global variables
CONF_PATH="${1:-opers.conf}";
MKPASSWD_PATH="${2:-../bin/mkpasswd}";
MKPASSWD_ARGS="${3:--b}";

#
# Subroutines
_printf() {
local _fmt="${1}" ; shift;
	printf "[%s] ${_fmt}" "`date +"${_TIMESTAMP_FMT}"`" "$@"
}



if ! [ -x "${MKPASSWD_PATH}" ];
then	_printf "Path to mkpasswd (1) \`${MKPASSWD_PATH}' points at non-executable and/or -existent file.\n";
	exit 1;
elif ! _conf_tmp_path="$(mktemp "$(basename "${0}").$(hostname -s).XXXXX")";
then	exit 2;
else	cat "${CONF_PATH}" >| "${_conf_tmp_path}";
	abort_exec() { printf "\n" ; _printf "-- ABORTED ---\n" ; exit 3; };
	clean_exec_exit() { rm -f "${_conf_tmp_path}" 2>/dev/null ; _printf "Exiting.\n"; };
	trap abort_exec HUP INT QUIT PIPE TERM USR1 USR2 ; trap clean_exec_exit EXIT;
	_npwd=0 ; _npwd_enc=0;
fi;

for _ln in `grep -n "${_PASSWORD_REGEX}" "${CONF_PATH}" | awk -F: '{print $1}'`;
do	_npwd="$(( 1 + ${_npwd} ))";
	if ! sed -n "$(( 1 + ${_ln}))p" "${CONF_PATH}" | grep -q "${_PASSWORD_NENCRYPT_REGEX}" 2>/dev/null;
	then	continue;
	else	_printf "Password #% 5u: %s:% 5u: " "${_npwd}" "${CONF_PATH}" "${_ln}";
		_passwd="$(sed -n "${_ln}s/^.*\"\\(.*\\)\".*\$/\\1/p" "${CONF_PATH}")" 2>/dev/null;
		printf "\`%s' => " "${_passwd}";

		if ! _passwd_new="`${MKPASSWD_PATH} ${MKPASSWD_ARGS} -p "${_passwd}" 2>&1`";
		then	printf "\[error from mkpasswd(1): \`${_passwd_new}'\]\n" ; exit 4;
		else	printf "\`%s'.\n" "${_passwd_new}";
		fi;

		_passwd_new="`echo "${_passwd_new}" | sed 's,\\$,\\\\&,g'`";
		sed -i "" "${_ln}"'s,^\(.*password.*=.*\)".*"\(.*;$\),\1"'"${_passwd_new}"'"\2,' "${_conf_tmp_path}" 2>/dev/null;
		sed -i "" "$(( 1 + ${_ln}))"'s,^\(.*encrypted.*=.*\)no\(.*;$\),\1yes\2,' "${_conf_tmp_path}" 2>/dev/null;
		_npwd_enc="$(( 1 + ${_npwd_enc} ))";
	fi;
done;

_printf "Found %u passwords, encrypted %u passwords.\n" "${_npwd}" "${_npwd_enc}";

if [ 0 -eq "${_npwd_enc}" ]; then exit 0 ; fi;

_printf "Show diff (1)? (Y|n) " ; read _choice;
case "${_choice}" in
[Nn])	;;
*)	diff -u "${CONF_PATH}" "${_conf_tmp_path}" | less ; ;;
esac;

_conf_path_orig="${CONF_PATH}.orig-`openssl rand -hex 8 2>/dev/null`";
_printf "(Original configuration file will be backed up as \`%s' subsequently.)\n" "${_conf_path_orig}";
_printf "Commit? (N|y) " ; read _choice ;
case "${_choice}" in [Yy]) ;; *) exit 0 ; ;; esac;

mv "${CONF_PATH}" "${_conf_path_orig}" ; mv "${_conf_tmp_path}" "${CONF_PATH}";
_printf "Signal ircd (8) to rehash w/ \`%s?' (Y|n) " "${_REHASH_IRCD_CMD}" ; read _choice;
case "${_choice}" in [Nn]) ;; *) ${_REHASH_IRCD_CMD} ;; esac;

# vim:ts=8 sw=8 tw=120 noexpandtab foldmethod=marker fileencoding=utf-8
