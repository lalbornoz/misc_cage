#!/bin/sh

logf() {
	local _attr="${1}" _fmt="${2}" _ts="%Y-%^b-%d %H:%M:%S"; shift 2;
	printf "%s[%s] ${_fmt}%s\n" "${_attr}" "$(date "+${_ts}")" "${@}" "[0m";
};
errorf() { local _fmt="${1}"; shift; logf "[91m" "Error: ${_fmt}" "${@}"; };
warningf() { local _fmt="${1}"; shift; logf "[31m" "Warning: ${_fmt}" "${@}"; };
noticef() { local _fmt="${1}"; shift; logf "[93m" "${_fmt}" "${@}"; };
verbosef() { local _fmt="${1}"; shift; logf "[96m" "${_fmt}" "${@}"; };

checksum() {
	local _checksum_fname="checksum.md5" _checksum_size="" _count=0 _count_empty=0		\
		_fname="" _rc=0 _subdir="" _ts0="" _ts="" IFS;
	if ! _ts0="$(date +%s)"; then
		_rc=1;
	else	IFS="
	";	for _subdir in $(find . -maxdepth 1 -mindepth 1 -type d | sort -V); do
			noticef "Processing subdirectory \`%s'..." "${_subdir}";
			if ! cd "${_subdir}"; then
				errorf "failed to change directory to \`%s', ignoring..." "${_subdir}"; _rc=2;
			else
				trap "	RC=\"\${?}\";
					rm -f \"${_subdir}/${_checksum_fname}\" 2>/dev/null;
					warningf \"Received signal, aborting.\";
					exit \"\${RC}\"" HUP INT QUIT USR1 USR2;
				printf "" >"${_checksum_fname}";
				for _fname in $(find .						\
						\( -type f -or -type l \)			\
						-not -name "${_checksum_fname}" -printf "%P\\n" | sort -V); do
					md5sum "${_fname}" >>"${_checksum_fname}";
				done;
				if _checksum_size="$(stat -c %s "${_checksum_fname}")"\
				&& [ "${_checksum_size}" -eq 0 ]; then
					verbosef "Deleting empty checksums file for subdirectory \`%s'..." "${_subdir}";
					rm -f "${_checksum_fname}";
					: $((_count_empty+=1));
				fi;
				trap - HUP INT QUIT USR1 USR2;
				if ! cd "${OLDPWD}"; then
					errorf "failed to change directory to parent directory of \`%s', aborting." "${_subdir}";
					_rc=3; break;
				else
					: $((_count+=1));
				fi;
			fi;
		done;
	fi;
	if _ts="$(date +%s 2>/dev/null)"; then
		noticef "Processed %d subdirectories (%d empty subdirectories) in %d seconds."	\
			"${_count}" "${_count_empty}" "$((${_ts}-${_ts0}))";
	else
		noticef "Processed %d subdirectories (%d empty subdirectories.)" "${_count}" "${_count_empty}";
	fi;
	return "${_rc}";
};

set +o errexit -o noglob -o nounset; checksum "${@}";
