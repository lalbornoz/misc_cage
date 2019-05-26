#!/bin/sh
# {{{ Environment variables as per <https://github.com/transmission/transmission/wiki/Scripts>
# TR_APP_VERSION
# TR_TIME_LOCALTIME
# TR_TORRENT_DIR
# TR_TORRENT_HASH
# TR_TORRENT_ID
# TR_TORRENT_NAME
# }}}
# {{{ settings.json configuration example
# "script-torrent-done-enabled": true, 
# "script-torrent-done-filename": "/etc/transmission-daemon/script-torrent-done.sh", 
# }}}
#

main() {
	local _rar_fname="" _rc=1 _torrent_path="";
	if [ -e "${0%/*}/script.vars" ]; then
		. "${0%/*}/script.vars";
		if [ -n "${PURGE_LIST_FNAME}" ]; then
			touch "${PURGE_LIST_FNAME}";
			if [ -n "${_torrent_path:="${TR_TORRENT_DIR}/${TR_TORRENT_NAME}"}" ]; then
				for _rar_fname in $(find "${_torrent_path}" -iname \*.rar); do
					cd "$(dirname "${_rar_fname}")"; unrar e -o- "$(basename "${_rar_fname}")"; cd "${OLDPWD}";
					printf "%s\n" "${_torrent_path}" >> "${PURGE_LIST_FNAME}";
				done;
				_rc=0;
			fi;
		fi;
	fi;
	return "${_rc}";
};

set +o errexit -o noglob -o nounset; main "${@}";
