#!/bin/sh
# $Id$
#

#
# Subroutines
#

_exit_exec() { [ -n "${_TMPF1_PATH}" -a -r "${_TMPF1_PATH}" ] && rm -f "${_TMPF1_PATH}";
	[ -n "${_TMPF2_PATH}" -a -r "${_TMPF2_PATH}" ] && rm -f "${_TMPF2_PATH}"; };
_abort_exec() { printf "\nReceived signal, aborting.\n"; exit 1; };

_pop_ifs() { IFS="${_IFS}"; };
_push_ifs() { _IFS="${IFS}"; IFS="${1}"; };

#
# Global variables and tunables
#

_DFLAG=0;
#_CMDS_REQUIRED="rm printf uname mktemp basename find wc awk sort cut cygpath unix2dos";
_CMDS_REQUIRED="rm printf uname mktemp basename find wc cygpath unix2dos";
_FIND_INAME_SPEC="-iname \*.cue -or -iname \*.m4a -or -iname \*.mp3 -or -iname \*.mp4";
_TMPF1_PATH="";
_TMPF2_PATH="";

#
# Script entry point
#

[ "x${1}" = "x-d" ] && { _DFLAG=1 ; shift; } || DFLAG=0;
[ $# -eq 1 ] && _FNAME_TARGET="${1%.m3u*}.m3u8" ||\
{ printf "usage: %s fname[.m3u8]\n" "${0}" ; exit 2; };

printf "Testing for prerequisite commands: ";
for _cmd in ${_CMDS_REQUIRED}; do
	[ -x "$(which "${_cmd}")" ] && printf "${_cmd} " || exit 3;
done; printf "done.\n";

printf "Testing for Cygwin: ";
{ _sname="$(uname -s)" && printf "%s.\n" "${_sname}" && [ -z "${_sname%CYGWIN_*}" ]; } || exit 4; 

printf "Creating temporary files: "
[ ${DFLAG} -eq 0 ] && trap _exit_exec EXIT; trap _abort_exec HUP INT QUIT PIPE TERM USR1 USR2;
_TMPF1_PATH="$(mktemp -t "$(basename "${0%.sh}_XXXX")")" && printf "${_TMPF1_PATH} " || exit 5;
_TMPF2_PATH="$(mktemp -t "$(basename "${0%.sh}_XXXX")")" && printf "${_TMPF2_PATH} " || exit 6;
printf "done.\n";

printf "Enumerating files with find (1): ";
{ eval find \"$(pwd)\" ${_FIND_INAME_SPEC} -type f >| "${_TMPF1_PATH}" &&\
  printf "%u files.\n" "$(wc -l "${_TMPF1_PATH}" | awk '{print $1}')"; } || exit 7;

#printf "Sorting files numerically: ";
#{ awk -F/ '{printf "%s%c%s\n", $NF, "\x00", $0}' "${_TMPF1_PATH}" |\
#  sort -n | cut -d $'\x00' -f2- >| "${_TMPF2_PATH}"; } || exit 8;
#printf "done\n";

printf "Converting path names: ";
{ _push_ifs $'\n'; for _path in `cat "${_TMPF1_PATH}"`; do
	cygpath -w "${_path}";
done >| "${_TMPF2_PATH}" ; _pop_ifs; } && printf "done.\n" || exit 9;

printf "Applying DOS file format conversion: ";
unix2dos "${_TMPF2_PATH}" || exit 10;

printf "Prepending UTF-8 BOM signature: ";
{ printf "\xef\xbb\xbf" >| "${_TMPF1_PATH}" &&\
  cat "${_TMPF2_PATH}" >> "${_TMPF1_PATH}"; } && printf "done.\n" || exit 11;

printf "Renaming file: ";
mv "${_TMPF1_PATH}" "${_FNAME_TARGET}" && printf "${_FNAME_TARGET}.\n" || exit 12;

exit 0;

# vim:ts=8 sw=8 tw=150 noexpandtab foldmethod=marker
# vim:fileencoding=utf-8
