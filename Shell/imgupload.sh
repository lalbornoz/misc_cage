#!/bin/sh

usage() {
	printf "usage: %s [-X] fname\n" "${1##*/}" 2>&1;
};

imgupload() {
	local _ _fname="" _opt="" _url="" _Xflag=0;

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

	_url="$(curl -v -F file="@${_fname}" "https://ballpit.net" 2>&1 |\
		sed -ne '/location:/s/^.*location: \(.*\)$/\1/p')" || return 1;

	printf "%s" "${_url}" | xclip -sel primary;
	printf "%s" "${_url}" | xclip -i -sel clipboard;

	printf "Screenshot uploaded as %s\n" "${_url}";
	printf "Link copied to clipboard.\n";
	printf "Press any key to exit.\n";
	read _;

	return 0;
};

set -o errexit -o noglob -o nounset; imgupload "${@}";
