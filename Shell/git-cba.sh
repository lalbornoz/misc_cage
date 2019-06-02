#!/bin/sh

main() {
	if [ "${#}" -eq 0 ]; then
		set -- "-a";
	fi;
	git commit --amend --reset-author -v "${@}";
};

set -o errexit -o noglob -o nounset; main "${@}";
