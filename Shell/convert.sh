#!/bin/sh
# $Id$
#

_DEFAULT_SUFFIX="small" ;
_DEFAULT_OFORMAT=png ;
_DEFAULT_RESIZE=640x480;

command which convert >/dev/null 2>&1 || {
	printf "convert (1) missing or not found, exiting.\n" ; exit 2; };

for _fname in `find . -iname \*.jpg -or -iname \*.png`
do	_fname="`basename \"${_fname}\"`" ;
	_fname_new="${_fname%.*}_${_DEFAULT_SUFFIX}.${_DEFAULT_OFORMAT}";

	printf "%s: " "${_fname}" ;
	convert	-resize	"${_DEFAULT_RESIZE}"				  \
			"${_fname}" "${_fname_new}"			&&\
	printf "%s\n" "${_fname_new}";
done

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
