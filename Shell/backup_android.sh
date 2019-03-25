#!/bin/sh

main() {
	local _ab_tmp_fname="" _dst_tmp_fname="" _dst_fname="";

	if [ "${#}" -eq 0 ]\
	|| [ -z "${_dst_fname:=${1}}" ]; then
		echo "error: missing target backup archive filename" >&2;
		echo "usage: ${0##*/} fname" >&2;
		exit 1;
	elif [ -e "${_dst_fname}" ]; then
		echo "error: target backup archive \`${_dst_fname}' already exists" >&2;
		exit 2;
	else
		_ab_tmp_fname="$(mktemp -up "${PWD}" "backup.XXXXXXXX.ab")";
		trap "rm -f \"${_ab_tmp_fname}\" 2>/dev/null" EXIT HUP INT TERM USR1 USR2;
		_dst_tmp_fname="$(mktemp -p "$(dirname "$(readlink -f "${_dst_fname}")")" "backup.XXXXXXXX.tgz")";
		trap "rm -f \"${_ab_tmp_fname}\" \"${_dst_tmp_fname}\" 2>/dev/null" EXIT HUP INT TERM USR1 USR2;

		if [ "$(uname -o)" = "Cygwin" ]; then
			adb backup -all -apk -shared -f "$(cygpath -w "${_ab_tmp_fname}")";
		else
			adb backup -all -apk -shared -f "${_ab_tmp_fname}";
		fi;
		awk 'END{printf("\x1f\x8b\x08\x00\x00\x00\x00\x00")}' < /dev/null > "${_dst_tmp_fname}";
		tail -c +25 "${_ab_tmp_fname}" >> "${_dst_tmp_fname}";
		mv "${_dst_tmp_fname}" "${_dst_fname}"; rm -f "${_ab_tmp_fname}";
		trap "" EXIT HUP INT TERM USR1 USR2;
	fi;
};

set -o errexit -o noglob -o nounset; main "${@}";
