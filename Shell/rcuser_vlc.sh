#!/bin/sh
if [ "${1}" != "--unshared-exec" ]; then
	exec sudo unshare -m "${0}" --unshared-exec "${@}";
else
	shift;
fi;
IFS="
"; for SUBDIR1 in $(find /overlay -maxdepth 1 -mindepth 1 -type d); do
	for SUBDIR2 in $(find "${SUBDIR1}" -maxdepth 1 -mindepth 1 -type d); do
		mount --bind -o ro "/home/lucio/${SUBDIR1#/overlay/} - ${SUBDIR2#${SUBDIR1}/}" "${SUBDIR2}";
	done;
done;
mount --bind -o ro /home/lucio/Downloads /overlay/Downloads;
mount --bind -o ro /overlay/empty /home/lucio;
exec "${@}";
# vim:filetype=sh
