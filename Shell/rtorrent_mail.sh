#!/bin/sh

RTORRENT_BASE_URL="https://[username:password]@hostname[:port]/";
RTORRENT_MAIL_TO="username";

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
	local	_name="${1}" _base_filename="${2}" _base_path="${3}"		\
		_is_multi_file="${4}" _size_bytes="${5}" _size_files="${6}"	\
		_base_dname="" _subject="" _url="";

	[ "${_is_multi_file}" = 1 ] || _is_multi_file="";
	_base_dname="${_base_path%/*}"; _base_dname="${_base_dname##*/}";
	_url="${RTORRENT_BASE_URL%/}/${_base_dname%/}/${_base_filename}${_is_multi_file:+/}";
	_url="$(printf "%s" "${_url}" | sed 's, ,%20,g')";
	rmp_humanise \$_size_bytes || _size_bytes="(error)";
	/usr/bin/mail				\
		-s "Finished Torrent ${_name}"	\
		"${RTORRENT_MAIL_TO}"		\
<<-EOF
This email is to inform you that rtorrent has finished downloading ${_name}, which
includes ${_size_files} files in ${_size_bytes} in total. This torrent's files are
available at:

${_url}
${_is_multi_file:+(this torrent has multiple files)}
EOF
};

set +o errexit -o noglob -o nounset; rtorrent_mail "${@}";

# vim:ft=sh
