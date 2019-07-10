#!/bin/sh
#

ALL_MEDIA_PNAMES="											\
	Movies and TV shows - Archive									\
	Movies and TV shows - Documentaries and programmes						\
	Movies and TV shows - Video clips								\
	Music - Flamenco Andaluzí and Middle-eastern arabic music					\
	Music - Iranian and Kurdish music								\
	Music - Soul, Jazz, and Latin American Music							\
	Music - The Maghrib										\
	Music - Unsorted Music";
MUSIC_MEDIA_PNAMES="											\
	Music - Flamenco Andaluzí and Middle-eastern arabic music					\
	Music - Iranian and Kurdish music								\
	Music - Soul, Jazz, and Latin American Music							\
	Music - The Maghrib										\
	Music - Unsorted Music";

rc() {
	local _nflag="${1}" _cmd="${2}"; shift 2;
	printf "%s %s\n" "${_cmd}" "${*}";
	if [ "${_nflag:-0}" -eq 0 ]; then
		"${_cmd}" "${@}";
	fi;
};

do_chmod() {
	local _nflag="${1}" IFS="	" _old_IFS="${IFS}";
	for _subdir in ${ALL_MEDIA_PNAMES}; do
		IFS="${_old_IFS}";
		rc "${_nflag}" find "${HOME}/${_subdir}" -type d -not -iname \*.m3u8			\
			-not -perm 0755 -print -exec chmod 0755 {} \;;
		rc "${_nflag}" find "${HOME}/${_subdir}" -type f -not -iname \*.m3u8			\
			-not -perm 0644 -print -exec chmod 0644 {} \;;
		IFS="	";
	done;
};

do_rsync() {
	local _nflag="${1}" _subdir="" IFS="	" _old_IFS="${IFS}";
	for _subdir in ${ALL_MEDIA_PNAMES}; do
		IFS="${_old_IFS}";
		if [ "${_nflag:-0}" -eq 1 ]; then
			rc 0 rsync -aiPve ssh --delete --exclude=\*.m3u8				\
				-n "${HOME}/${_subdir}" lucio@abbad_vpn00.:../lucio_shared;
		else
			rc "${_nflag}" rsync -aiPve ssh --delete --exclude=\*.m3u8			\
				"${HOME}/${_subdir}" lucio@abbad_vpn00.:../lucio_shared;
		fi;
		IFS="	";
	done;
};

playlists() {
	local _nflag="${1}" _prefix="$(cygpath -m /)" _subdir="" _tmpf_pname="" IFS="	" _old_IFS="${IFS}";
	for _subdir in ${MUSIC_MEDIA_PNAMES}; do
		IFS="${_old_IFS}";
		_tmpf_pname="$(mktemp -t "$(basename "${0%.sh}_XXXXXX")")";
		echo find "${HOME}/${_subdir}" -type f							\
			\( -iname \*.ape -or -iname \*.cue -or -iname \*.mp3 -or			\
			   -iname \*.mp4 -or -iname \*.mkv -or -iname \*.mpc -or			\
			   -iname \*.webm -or -iname \*.wma \)						\
			-printf '\\\\?\\E:\\'"${_subdir}"'\\%P\n' \| sort -g				\
				\> "${_tmpf_pname}";
		if [ "${_nflag:-0}" -eq 0 ]; then
			find "${HOME}/${_subdir}" -type f						\
				\( -iname \*.ape -or -iname \*.cue -or -iname \*.mp3 -or		\
				   -iname \*.mp4 -or -iname \*.mkv -or -iname \*.mpc -or		\
				   -iname \*.webm -or -iname \*.wma \)					\
				-printf "${HOME}/${_subdir}"'\\%P\n' | sort -g				\
					> "${_tmpf_pname}";
		fi;
		rc "${_nflag}" unix2dos "${_tmpf_pname}";
		rc "${_nflag}" sed -i'' -e 's,^,//?/'"${_prefix}"',' -e 's,/,\\,g' "${_tmpf_pname}";
		rc "${_nflag}" sed -i'' '1s/^/\xef\xbb\xbf/' "${_tmpf_pname}";
		rc "${_nflag}" mv "${_tmpf_pname}" "${HOME}/${_subdir}/${_subdir#* - }.$(hostname).m3u8";
		if [ "${_nflag:-0}" -eq 1 ]; then
			rm -f "${_tmpf_pname}";
		fi;
		IFS="	";
	done;
};

usage() {
	echo "usage: ${0} [-c] [-h] [-n] [-p] [-r]" >&2;
	echo "       -c.......: fix permissions to 0755 for dirs and 0644 for files" >&2;
	echo "       -h.......: show this screen" >&2;
	echo "       -n.......: dry run" >&2;
	echo "       -p.......: generate UTF-8 encoded foobar2000 playlists" >&2;
	echo "       -r.......: rsync(1) files to remote host" >&2;
};

main() {
	local _cflag=0 _nflag=0 _opt="" _pflag=0 _rflag=0 _subdir="";
	while getopts chnpr _opt; do
	case "${_opt}" in
	c)	_cflag=1; ;;
	h)	usage; exit 0; ;;
	n)	_nflag=1; ;;
	p)	_pflag=1; ;;
	r)	_rflag=1; ;;
	*)	usage; exit 1; ;;
	esac;
	done; shift $((${OPTIND}-1));
	if [ "${_cflag:-0}" -eq 0 ]\
	&& [ "${_pflag:-0}" -eq 0 ]\
	&& [ "${_rflag:-0}" -eq 0 ]; then
		usage; exit 1;
	fi;
	if [ "${_cflag:-0}" -eq 1 ]; then
		do_chmod "${_nflag}" "${@}";
	fi;
	if [ "${_pflag:-0}" -eq 1 ]; then
		playlists "${_nflag}" "${@}";
	fi;
	if [ "${_rflag:-0}" -eq 1 ]; then
		do_rsync "${_nflag}" "${@}";
	fi;
};

set -o noglob; main "${@}";

# vim:tw=0
