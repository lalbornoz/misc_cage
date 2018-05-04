#!/bin/sh
PATH_MSPAINT="/home/lucio/Backups - Windows software and games/Multimedia/Microsoft Windows 7 Paint (amd64)/mspaint.exe";
if [ -n "${1}" ]; then
	if [ "${1#/}" != "${1}" ]; then
		PATH_FILE="z:\\\\$(echo "${1}" | sed 's,/,\\,g')";
	else
		PATH_FILE="z:\\\\$(echo "$(pwd)/${1}" | sed 's,/,\\,g')";
	fi;
fi;
export WINEPREFIX=/home/lucio/.wine;
if [ -n "${PATH_FILE}" ]; then
	wine 'c:\\windows\\command\\start.exe' /Unix "${PATH_MSPAINT}" "${PATH_FILE}";
else
	wine 'c:\\windows\\command\\start.exe' /Unix "${PATH_MSPAINT}";
fi;
