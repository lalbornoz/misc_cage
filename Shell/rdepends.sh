#!/bin/sh
#

usage() {
	echo "usage: ${0} [-l] [--] pkgs..." >&2;
	echo "       -l.......: include libraries" >&2;
};

main() {
	local _lflag=0 _opt="" _pkgs="";
	while getopts hl _opt; do
	case "${_opt}" in
	h)	usage; exit 0; ;;
	l)	_lflag=1; ;;
	*)	usage; exit 1; ;;
	esac; done; shift $((${OPTIND}-1));
	_pkgs="$(apt-cache rdepends --installed "${@}"		|\
			sed -n	-e '/^Reverse Depends:$/d'	 \
				-e 's/^\s\+//'			 \
				-e 'p'				|\
			sort					|\
			uniq)";
	if [ "${_lflag:-0}" -eq 1 ]; then
		echo "${_pkgs}";
	else
		echo "${_pkgs}" | sed -ne '/^lib/!p';
	fi;
}

set -o errexit -o noglob; main "${@}";
