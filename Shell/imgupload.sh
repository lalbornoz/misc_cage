#!/bin/sh

usage() {
	printf "usage: %s [-v] [-w] [-X] fname[..]\n" "${1##*/}" 2>&1;
	printf "       -v.........: pass -v to curl\n" 2>&1;
	printf "       -w.........: wait for input before exit\n" 2>&1;
	printf "       -X.........: run windowed via exo-open --launch TerminalEmulator\n" 2>&1;
};

imgupload() {
	local	_curl_args_extra="" _fname="" _key="" _nurls=0 _opt=""	\
		_rc=0 _rc_last=0 _url="" _urls="" _vflag=0 _wflag=0	\
		_Xflag=0;

	while getopts hwvX _opt; do
	case "${_opt}" in
	h)	usage "${0}"; return 0; ;;
	v)	_vflag=1; _curl_args_extra="-v"; ;;
	w)	_wflag=1; ;;
	X)	_Xflag=1; ;;
	*)	usage "${0}"; return 1; ;;
	esac; done;
	shift $((${OPTIND}-1));
	if [ "${#}" -lt 1 ]; then
		usage "${0}"; return 1;
	else
		_fname="${1}";
	fi;

	if [ "${_Xflag}" = 1 ]; then
		if [ "${_fname#/}" = "${_fname}" ]; then
			_fname="${PWD}/${_fname}";
		fi;

		if [ "${_wflag}" -eq 1 ]; then
			exo-open --launch TerminalEmulator "${0}" -w \""${_fname}"\";
		else
			exo-open --launch TerminalEmulator "${0}" \""${_fname}"\";
		fi;
		return 0;
	fi;

	for _fname in "${@}"; do
		if ! [ -e "${_fname}" ]; then
			printf "Warning: file \`%s' not found, skipping.\n" "${_fname}" 2>&1;
			continue;
		fi;

		_rc_last=0;
		_url="$(curl				\
			-s				\
			-F file="@${_fname}"		\
			${_curl_args_extra}		\
			"https://hardfiles.org")"	\
				|| _rc_last=1;

		if [ "${_rc_last}" -eq 0 ]; then
			_url="$(printf "%s" "${_url}" |\
				sed -e 's/[\r\n]*//g')";
			_urls="${_urls:+${_urls} }${_url}";
			: $((_nurls+=1));
		else
			printf "Failed uploading %s: %s\n" "${_fname}" "${_url}";
			_rc=1;
		fi;
	done;

	printf "%s" "${_urls}" | xclip -sel primary;
	printf "%s" "${_urls}" | xclip -i -sel clipboard;

	if [ "${_urls:+1}" = 1 ]; then
		if [ "${_nurls}" -gt 1 ]; then
			printf "Images uploaded as %s\n" "${_urls}";
			printf "Links copied to clipboard.\n";
		else
			printf "Image uploaded as %s\n" "${_urls}";
			printf "Link copied to clipboard.\n";
		fi;
	fi;

	if [ "${_wflag}" -eq 1 ]; then
		printf "Press any key to exit.\n";
		read _key;
	fi;

	return 0;
};

set -o errexit -o noglob -o nounset; imgupload "${@}";
