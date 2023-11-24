#!/bin/sh

pop_IFS() { IFS="${_IFS}"; unset _IFS; };
push_IFS() { _IFS="${IFS}"; IFS="${1}"; };

rc() {
	local _nflag="${1}" _cmd="${2}";
	shift 2;

	printf "%s %s\n" "${_cmd}" "${*}";
	case "${_nflag}" in
	1)	printf "Run the above command? (y|N) "; read _choice;
		case "${_choice}" in
		[yY])	return 0;;
		*)	return 1; ;;
		esac; ;;
	*)	;;
	esac;
};

rsync_app() {
	local _nflag="${1}" _path_dst="app" _path_src="/data/app";
	if rc "${_nflag}" rsync -aiPv --blocking-io --delete "exec:/${_path_src}/" "${_path_dst}/";
	then
		rsync -e "adb shell" --blocking-io -aiPv --delete "exec:/${_path_src}/" "${_path_dst}/";
	fi;
};

ls_app() {
	local _nflag="${1}" _fname_dst="app.lst" _path_src="app";
	ls -alR "${_path_src}" > "${_fname_dst}";
};

tar_app() {
	local _nflag="${1}" _path_dst="app";
	if rc "${_nflag}" tar -cpf - "${_path_dst}" \> "${_path_dst%/}.tar";
	then
		tar -cpf - "${_path_dst}" > "${_path_dst%/}.tar";
	fi;
};

rsync_data() {
	local _nflag="${1}" _path_dst="data" _path_src="/data/data";
	if rc "${_nflag}" rsync -aiPv --blocking-io --delete "exec:/${_path_src}/" "${_path_dst}/";
	then
		rsync -e "adb shell" --blocking-io -aiPv --delete "exec:/${_path_src}/" "${_path_dst}/";
	fi;
};

ls_data() {
	local _nflag="${1}" _fname_dst="data.lst" _path_src="data";
	ls -alR "${_path_src}" > "${_fname_dst}";
};

tar_data() {
	local _nflag="${1}" _path_dst="data";
	if rc "${_nflag}" tar -cpf - "${_path_dst}" \> "${_path_dst%/}.tar";
	then
		tar -cpf - "${_path_dst}" > "${_path_dst%/}.tar";
	fi;
};

rsync_media() {
	local _nflag="${1}" _path_dst="media" _path_src="/data/media/0";

	if rc "${_nflag}" rsync -e "adb shell" -aiPv --blocking-io --delete "exec:/${_path_src}/" "${_path_dst}/";
	then
		rsync -e "adb shell" -aiPv --blocking-io --delete "exec:/${_path_src}/" "${_path_dst}/";
	fi;
};

ls_media() {
	local _nflag="${1}" _fname_dst="media.lst" _path_src="media";
	ls -alR "${_path_src}" > "${_fname_dst}";
};

tar_media() {
	local _nflag="${1}" _path_dst="media"
	if rc "${_nflag}" tar -cpf - "${_path_dst}" \> "${_path_dst%/}.tar";
	then
		tar -cpf - "${_path_dst}" > "${_path_dst%/}.tar";
	fi;
};

usage() {
	local _rc="${1:-1}";
	printf "usage: %s [-n] [-s] <addr> <port> <code-pair> <port-pair>\n" "${0##*/}" >&2;
	exit "${_rc}";
};

main() {
	local	_addr="" _code_pair="" _device="" _nflag=0 _opt=""	\
		_port="" _port_pair="" _sflag=0;

	while getopts hns _opt; do
	case "${_opt}" in
	h)	usage 0; ;;
	n)	_nflag=1; ;;
	s)	_sflag=1; ;;
	*)	usage 1; ;;
	esac; done;
	shift $((${OPTIND}-1));

	if [ "${#}" -ne 4 ]; then
		printf "error: missing <addr> <port> <code-pair> <port-pair>\n" >&2; usage 2;
	else
		_addr="${1}"; _port="${2}" _code_pair="${3}" _port_pair="${4}";
	fi;

	push_IFS "
";	for _device in $(find . -maxdepth 1 -mindepth 1 -type d); do
		pop_IFS;
		_device="${_device#./}";
		(cd "${_device}";
		 trap 'pkill -f "adb .* fork-server "' ALRM EXIT HUP INT TERM USR1 USR2;
		 adb pair "${_addr}:${_port_pair}" "${_code_pair}";
		 adb connect "${_addr}:${_port}";
		 adb root;
		 if [ "${_sflag}" -eq 0 ]; then
		 	rsync_app "${_nflag}";
		 	ls_app "${_nflag}";
		 	tar_app "${_nflag}";
		 	rsync_data "${_nflag}";
		 	ls_data "${_nflag}";
		 	tar_data "${_nflag}";
		 fi;
		 rsync_media "${_nflag}";
		 ls_media "${_nflag}";
		 tar_media "${_nflag}";
		);
		push_IFS "
";	done;
};

set -o errexit -o noglob -o nounset; main "${@}";
