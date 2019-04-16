#!/bin/sh
# Assumes CentOS 7 x86_64 w/ `Server with GUI' group installation.
#

#
# Default variables
#
COLOUR_DRY_RUN="[36m"; COLOUR_FAILURE="[91m"; COLOUR_NEUTRAL="[93m";
COLOUR_RESET="[0m"; COLOUR_SUCCESS="[32m"; COLOUR_TIMESTAMP="[33m";
TIMESTAMP_FMT="%d-%^b-%Y %H:%M:%S"; TIMESTAMP_LOG_FMT="%H%M%S-%d%m%Y";

ELREPO_PACKAGES="kmod-nvidia.x86_64 nvidia-detect.x86_64 nvidia-x11-drv.x86_64";
ELREPO_URL_KEY="https://www.elrepo.org/RPM-GPG-KEY-elrepo.org";
ELREPO_URL_RPM="https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm";

# {{{ Private subroutines
logf() {
	local _fmt="" _nflag=0;
	if [ "x${1}" = "x-n" ]; then
		_nflag=1; _fmt="%s%s%s ${2}"; shift 2;
	else
		_fmt="%s%s%s ${1}${COLOUR_RESET}\n"; shift;
	fi;
	printf "${_fmt}"								\
		"${COLOUR_TIMESTAMP}" "$(date +"${TIMESTAMP_FMT}")" "${COLOUR_RESET}"	\
		"${@}";
};

rc() {
	local _log_fname="${1}" _nflag="${2}" _cmd="${3}" _cmd_line="" _rc=""; shift 3;
	if [ "${_nflag:-0}" -eq 0 ]; then
		_cmd_line="${_cmd}"; _cmd_line="${_cmd_line}${*:+ ${*}}";
		logf -n "%s%s: " "${COLOUR_NEUTRAL}" "${_cmd_line}";
		printf "%s Command line: %s\n"						\
			"$(date +"${TIMESTAMP_FMT}")"					\
			"${_cmd_line}" >> "${_log_fname}" 2>&1;
		"${_cmd}" "${@}" >> "${_log_fname}" 2>&1; _rc="${?}";
		if [ "${_rc}" -eq 0 ]; then
			printf "%ssuccess.%s\n"						\
				"${COLOUR_SUCCESS}" "${COLOUR_RESET}";
		else
			printf "%sfailed w/ exit status %d.%s\n"			\
				"${COLOUR_FAILURE}" "${_rc}" "${COLOUR_RESET}";
		fi;
	else
		logf "%s%s %s" "${COLOUR_DRY_RUN}" "${_cmd}" "${*}";
	fi;
};

usage() {
	echo "usage: ${0} [-h] [-n]" >&2;
	echo "       -n........: perform dry run (disables logging)" >&2;
};
# }}}

main() {
	local _log_fname="" _nflag=0 _opt="";

	while getopts hn _opt; do
	case "${_opt}" in
	h)	usage; exit 0; ;;
	n)	_nflag=1; ;;
	*)	usage; exit 1; ;;
	esac; done; shift $((${OPTIND}-1));
	if [ "${_nflag:-0}" -eq 0 ]; then
		_log_fname="${0%.sh}-$(date "+${TIMESTAMP_LOG_FMT}")-$(hostname -f).log";
		printf "" > "${_log_fname}";
	fi;

	set +o errexit;
	rc "${_log_fname}" "${_nflag}" yum update -y;
	rc "${_log_fname}" "${_nflag}" yum --import "${ELREPO_URL_KEY}";
	rc "${_log_fname}" "${_nflag}" yum install -y "${ELREPO_URL_RPM}";
	rc "${_log_fname}" "${_nflag}" yum clean all;
	rc "${_log_fname}" "${_nflag}" yum makecache;
	rc "${_log_fname}" "${_nflag}" yum install -y ${ELREPO_PACKAGES};
	rc "${_log_fname}" "${_nflag}" sed -i.dist -e 's/^\(GRUB_CMDLINE_LINUX\)="\(.*\)"$/\1="\2 nvidia.NVreg_EnablePCIeGen3=1"/' /etc/default/grub;
	set -o errexit;
};

set -o errexit -o noglob -o nounset; main "${@}";

# vim:tw=0
