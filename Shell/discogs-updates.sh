#!/bin/sh
# Discogs Marketplace change notification script (for pagga)
# {{{ Sample crontab entry polling for releases {122322,505628} every 5 minutes
# MAILTO=some@where.tld
# [ ... ]
# */5 * * * *	discogs-updates.sh 122322 505628
# }}}
#

# {{{ Default variables
DEFAULT_DATABASE_FNAME="${HOME}/.${0##*/}.db";
# }}}
# {{{ Private subroutines
getkey() {
	local _json="${1}" _key="${2}" _val="";
	_val="${_json#*\"${_key}\": }"; _val="${_val%%[,\}]*}";
	echo "${_val}";
};

logf() {
	local _fmt="${1}" _ts_fmt="%d-%^b-%Y %H:%M:%S"; shift;
	if [ "x${_fmt}" = "x-e" ]; then
		_fmt="${1}"; shift;
		if [ -t 1 ]; then
			printf "[33m%s[0m ${_fmt}\n" "$(date +"${_ts_fmt}")" "${@}" >&2;
		else
			printf "${_fmt}\n" "${@}" >&2;
		fi;
	else
		if [ -t 1 ]; then
			printf "[33m%s[0m ${_fmt}\n" "$(date +"${_ts_fmt}")" "${@}";
		else
			printf "${_fmt}\n" "${@}";
		fi;
	fi;
};
# }}}

usage() {
	echo "${0##*/} [-c] [-h] [-v] [--] release[..]" >&2;
	echo "  -c....: compare w/ and store to database" >&2;
	echo "  -h....: show this screen" >&2;
	echo "  -v....: blog a lot more" >&2;
};

main() {
	local _cflag=0 _json="" _db_last="" _db_new="" _lowest_price=""	\
		_num_for_sale="" _opt="" _release="" _vflag=0;

	while getopts chv _opt; do
	case "${_opt}" in
	c)	_cflag=1; ;;
	h)	usage; exit 0; ;;
	v)	_vflag=1; ;;
	*)	usage; exit 1; ;;
	esac; done; shift $((${OPTIND}-1));
	if [ "${#}" -eq 0 ]; then
		echo "error: no releases specified" >&2;
		usage; exit 1;
	fi;
	if [ "${_cflag:-0}" -eq 1 ]; then
		touch "${DEFAULT_DATABASE_FNAME}";
	fi;

	for _release in "${@}"; do
		if [ "${_vflag:-0}" -eq 1 ]; then
			logf -e "Fetching https://api.discogs.com/releases/${_release}";
		fi;
		_json="$(wget -qO- "https://api.discogs.com/releases/${_release}")";
		_lowest_price="$(getkey "${_json}" lowest_price)";
		_num_for_sale="$(getkey "${_json}" num_for_sale)";
		if [ "${_cflag:-0}" -eq 0 ]; then
			logf "#%d %s %s" "${_release}" "${_num_for_sale}" "${_lowest_price}";
		else
			_db_last="$(sed -n "/^${_release} /p" "${DEFAULT_DATABASE_FNAME}")";
			_db_new="$(printf "%s %s %s" "${_release}" "${_num_for_sale}" "${_lowest_price}")";
			if [ -z "${_db_last}" ]; then
				logf "New release #%d change notification, new num. for sale: %s, new lowest price: %s" "${_release}" "${_num_for_sale}" "${_lowest_price}";
				printf "%s\n" "${_db_new}" >> "${DEFAULT_DATABASE_FNAME}";
			elif [ "${_db_last}" != "${_db_new}" ]; then
				logf "Release #%d change notification, new num. for sale: %s, new lowest price: %s" "${_release}" "${_num_for_sale}" "${_lowest_price}";
				sed -i"" "/^${_release} /c ${_db_new}" "${DEFAULT_DATABASE_FNAME}";
			fi;
		fi;
	done;
};

set -o errexit -o noglob -o nounset; main "${@}";

# vim:tw=0
