#!/bin/sh

main() {
	local _pname="";
	for _pname in "${@}"; do
		git filter-branch --force --index-filter			\
			"git rm -r --cached --ignore-unmatch '${_pname}'"	\
			--prune-empty --tag-name-filter cat -- --all
	done;
};

set -o errexit -o noglob -o nounset; main "${@}";
