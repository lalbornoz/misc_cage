#!/bin/sh
#

main() {
	local _tty="$(readlink "/proc/${PPID}/fd/0" | sed 's,/dev/,,')" _user="${USER}";
	echo "Active SSH sessions for user \`${_user}', ignoring TTY \`${_tty}':";
	ps -o cmd -U "${_user}"						|\
		awk 'NR > 1 && /sshd: '"${_user}"'@[p]ts/{print}'	|\
			grep -v "${_tty}";
};

set -o errexit -o noglob;
main "${@}";

# vim:foldmethod=marker sw=8 ts=8 tw=120
