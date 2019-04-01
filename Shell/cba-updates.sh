#!/bin/sh

# {{{ Default variables
DEFAULT_COLOUR_FAILURE="91";
DEFAULT_COLOUR_SUCCESS="32";
DEFAULT_COLOUR_TIMESTAMP="33";
DEFAULT_USER="toor";
# }}}
# {{{ Private subroutines
logf() {
	local _fmt="${1}" _ts_fmt="%d-%^b-%Y %H:%M:%S"; shift;
	printf "[${DEFAULT_COLOUR_TIMESTAMP}m%s[0m ${_fmt}" "$(date +"${_ts_fmt}")" "${@}";
};

printf_rc() {
	local _rc="${1}" _fmt="${2}"; shift 2;
	if [ "${_rc}" -eq 0 ]; then
		printf "[${DEFAULT_COLOUR_SUCCESS}m${_fmt}[0m" "${@}";
	else
		printf "[${DEFAULT_COLOUR_FAILURE}m${_fmt}[0m" "${@}";
	fi;
};
# }}}

update_host() {
	local _host="${1}" _lflag="${2}" _user="${3}" _log_data="" _log_fname="";

	_log_fname="${0##*/}.${_host%%.}.log";
	logf "%s:" "${_host}";
	ssh -l"${_user}" -T "${_host}" '
		fini() { local _log_fname="${1}"; echo "${rc_last:-0} fini"; cat "${_log_fname}"; rm -f "${_log_fname}"; };
		init() { dpkg_new_fnames=""; pkgs=""; pkgs_filtered=""; pkgs_rdepends=""; rc=""; rc_last=""; log_fname="$(mktemp)" || exit 1; };
		status() { local _rc="${1}"; echo "${*}"; rc_last="${_rc}"; if [ "${_rc}" -ne 0 ]; then exit "${_rc}"; fi; };
		init; trap "fini \"${log_fname}\"" EXIT HUP INT QUIT TERM USR1 USR2;

		# apt-get -y update
		apt-get -y update >>"${log_fname}" 2>&1;
		status "${?}" update;

		# apt-get -y dist-upgrade
		pkgs="$(apt-get -y dist-upgrade 2>&1)"; rc="${?}";
		printf "%s\n" "${pkgs}" >>"${log_fname}";
		pkgs="$(printf "%s\n" "${pkgs}"								|
			awk '\''
				$0 == "The following packages will be upgraded:" {m=1; next}
				m {if ($0 !~ /^  /) {m=0} else {print}}'\'')";
		pkgs_filtered="$(printf "%s\n" "${pkgs}"						|
			sed -ne "s/  */\n/gp" | sed -ne "/^ *$/d" -e "/^lib/d" -e "p" | paste -sd " ")";
		pkgs="$(printf "%s\n" "${pkgs}"						|
			sed -ne "s/  */\n/gp" | sed -ne "/^ *$/d" -e "p" | paste -sd " ")";
		status "${rc}" dist-upgrade "${pkgs_filtered}";

		# apt-get -y autoremove --purge
		apt-get -y autoremove --purge >>"${log_fname}" 2>&1;
		status "${?}" autoremove;

		# rm -f /var/cache/apt/archives/*.deb
		rm -f /var/cache/apt/archives/*.deb >>"${log_fname}" 2>&1;
		status "${?}" clean;

		if [ -n "${pkgs}" ]; then
			# apt-cache rdepends --installed
			pkgs_rdepends="$(apt-cache rdepends --installed ${pkgs} 2>&1)"; rc="${?}";
			printf "%s\n" "${pkgs_rdepends}" >>"${log_fname}";
			pkgs_rdepends="$(printf "%s\n" "${pkgs_rdepends}"				|
				sed -ne "/^Reverse Depends:\$/d" -e "/^lib/d" -e "s/^\s\+//" -e "p"	|
				sort | uniq | paste -sd " ")";
			status "${rc}" rdepends "${pkgs_rdepends}";

			# find /etc -name *.dpkg-new
			dpkg_new_fnames="$(find /etc -name *.dpkg-new 2>/dev/null)";
			status "${?}" dpkg-new "${dpkg_new_fnames}";
		fi' |\
	while read -r _rc _type _msg; do
	case "${_type}" in
	autoremove|clean|update)
			printf_rc "${_rc}" " %s" "${_type}"; ;;
	dist-upgrade|dpkg-new|rdepends)
			printf_rc "${_rc}" " %s(%s)" "${_type}" "${_msg}"; ;;
	fini)		if [ "${_lflag:-0}" -eq 1 ]\
			|| [ "${_rc}" -ne 0 ]; then
				printf_rc "${_rc}" " %s" "[fetching log]";
				touch "${_log_fname}";
				while IFS= read -r _log_data; do
					printf "%s\n" "${_log_data}" >>"${_log_fname}";
				done;
			fi; break; ;;
	*)		printf " [${DEFAULT_COLOUR_FAILURE}m?[0m"; break; ;;
	esac; done; printf ".\n";
};

usage() {
	echo "usage: ${0} [-h] [-l] [-u user] [--] hosts..." >&2;
	echo "       -l.......: always save logs (defaults to save on failure only)" >&2;
	echo "       -u user..: username to login with (defaults to ${DEFAULT_USER})" >&2;
};

main() {
	local _host="" _lflag=0 _msg="" _opt="" _rc="" _type="" _user="${DEFAULT_USER}";
	while getopts hlu: _opt; do
	case "${_opt}" in
	h)	usage; exit 0; ;;
	l)	_lflag=1; ;;
	u)	_user="${OPTARG}"; ;;
	*)	usage; exit 1; ;;
	esac; done; shift $((${OPTIND}-1));
	for _host in "${@}"; do
		update_host "${_host}" "${_lflag}" "${_user}";
	done;
};

set -o errexit -o noglob -o nounset; main "${@}";

# vim:tw=0
