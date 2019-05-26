#!/bin/sh

cmp_torrents_list() {
	local _torrents_list_fname="${1}" _purge_list_fname="${2}" _torrent_path="";
	while read -r _torrent_path; do
		if ! grep -Fq "${_torrent_path}" "${_torrents_list_fname}"; then
			printf "Purging %s\n" "${_torrent_path}";
			rm -fr "${_torrent_path}";
		fi;
	done < "${_purge_list_fname}";
};

get_torrents_list() {
	local	_rpc_auth="${1}"					\
		_torrent_done="" _torrent_id="" _torrent_info=""	\
		_torrent_location="" _torrent_name="" _torrent_path=""	\
		_torrents_list_fname="";
	if _torrents_list_fname="$(mktemp)"; then
		printf "" > "${_torrents_list_fname}";
		for _torrent_id in $(transmission-remote -n "${_rpc_auth}" -l | awk 'NR != 1 && $1 != "Sum:" {print $1}'); do
			_torrent_info="$(transmission-remote -n "${_rpc_auth}" -t "${_torrent_id}" -i)";
			_torrent_done="$(printf "%s" "${_torrent_info}" | awk '/Percent Done:/{print $3}')";
			_torrent_location="$(printf "%s" "${_torrent_info}" | sed -n '/^\s\+Location:/s/^\s\+Location: //p')";
			_torrent_name="$(printf "%s" "${_torrent_info}" | sed -n '/^\s\+Name:/s/^\s\+Name: //p')";
			if [ "${_torrent_done}" = "100%" ]\
			&& [ -n "${_torrent_location}" ]\
			&& [ -n "${_torrent_name}" ]; then
				_torrent_path="${_torrent_location}/${_torrent_name}";
				printf "%s\n" "${_torrent_path}" >> "${_torrents_list_fname}";
			fi;
		done;
		echo "${_torrents_list_fname}"; return 0;
	else
		return "${?}";
	fi;
};

main() {
	local _rc=1 _torrent_path="";
	if [ -e "${0%/*}/script.vars" ]; then
		. "${0%/*}/script.vars";
		if [ -n "${PURGE_LIST_FNAME}" ]\
		&& [ -n "${RPC_AUTH}" ]; then
			if [ ! -e "${PURGE_LIST_FNAME}" ]; then
				_rc=0;
			elif _torrents_list_fname="$(get_torrents_list "${RPC_AUTH}")"; then
				trap "rm -f \"${_torrents_list_fname}\"" EXIT HUP INT TERM USR1 USR2;
				cmp_torrents_list "${_torrents_list_fname}" "${PURGE_LIST_FNAME}"; _rc="${?}";
			fi;
		fi;
	fi;
	return "${_rc}";
};

set +o errexit -o noglob -o nounset; main "${@}";

# vim:tw=0
