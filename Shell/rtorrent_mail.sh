#!/bin/sh

RTORRENT_MAIL_TO="lucio";

rmp_humanise() {
	local _rn="${1#\$}";

	if eval [ \"\${${_rn}}\" -ge 1073741824 ]; then
		eval "${_rn}"=\"$(eval printf \"scale=2\\n%u / 1073741824.0\\n\" \"\${${_rn}}\" | bc) GB\";
	elif eval [ \"\${${_rn}}\" -ge 1048576 ]; then
		eval "${_rn}"=\"$(eval printf \"scale=2\\n%u / 1048576.0\\n\" \"\${${_rn}}\" | bc) MB\";
	elif eval [ \"\${${_rn}}\" -ge 1024 ]; then
		eval "${_rn}"=\"$(eval printf \"scale=2\\n%u / 1024.0\\n\" \"\${${_rn}}\" | bc) KB\";
	else
		eval "${_rn}"=\"\${${_rn}} bytes\";
	fi;
};

rtorrent_mail() {
	local _name="${1}" _num_files="${2}" _size_bytes="${3}" _subject=""

	rmp_humanise \$_size_bytes || _size_bytes="(error)";
	/usr/bin/mail				\
		-s "Finished Torrent ${_name}"	\
		"${RTORRENT_MAIL_TO}"		\
<<-EOF
This email is to inform you that rtorrent has finished downloading ${_name}, which
includes ${_num_files} files in ${_size_bytes} in total.
EOF
};

set +o errexit -o noglob -o nounset; rtorrent_mail "${@}";

# vim:ft=sh
