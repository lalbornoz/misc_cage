#!/bin/sh

main() {
	local _dst_fname="" _src_fname="" _tmp_fname="";
	for _src_fname in "${@}"; do
		_dst_fname="${_src_fname%.ab}.tgz";
		_tmp_fname="$(mktemp -p "$(dirname "$(readlink -f "${_dst_fname}")")")";
		trap "rm -f \"${_tmp_fname}\" 2>/dev/null" EXIT HUP INT TERM USR1 USR2;
		awk 'END{printf("\x1f\x8b\x08\x00\x00\x00\x00\x00")}' < /dev/null > "${_tmp_fname}";
		tail -c +25 "${_src_fname}" >> "${_tmp_fname}";
		mv "${_tmp_fname}" "${_dst_fname}";
		trap "" EXIT HUP INT TERM USR1 USR2;
	done;
};

set -o errexit -o noglob -o nounset; main "${@}";
