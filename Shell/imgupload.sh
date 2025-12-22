#!/bin/sh

usage() {
	printf "usage: %s [-X] fname[..]\n" "${1##*/}" 2>&1;
};

imgupload() {
	local	_fname="" _key="" _nurls=0 _opt="" _rc=0	\
		_rc_last=0 _url="" _urls="" _Xflag=0;

	while getopts X _opt; do
	case "${_opt}" in
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

		exo-open --launch TerminalEmulator "${0}" \""${_fname}"\";
		return 0;
	fi;

	for _fname in "${@}"; do
		_rc_last=0;
		_url="$(curl -v -F file="@${_fname}" "https://ballpit.net" 2>&1)" || _rc_last=1;

		if [ "${_rc_last}" -eq 0 ]; then
			_url="$(printf "%s" "${_url}" |\
				sed -ne '/location:/s/^.*location: \(.*\)$/\1/p' |\
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

	printf "Press any key to exit.\n";
	read _key;

	return 0;
};

set -o errexit -o noglob -o nounset; imgupload "${@}";
