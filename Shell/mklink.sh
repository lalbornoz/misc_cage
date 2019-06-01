#!/bin/sh
# References:
# Sun, Jun 15, 2014  6:22:22 PM [1] ntfs - How can I create a junction using cygwin? - Stack Overflow <https://stackoverflow.com/questions/9432924/how-can-i-create-a-junction-using-cygwin>
#

[ $# -ne 2 ] && { printf "usage: $0 target name\n" ; exit 1; };
cmd.exe /c mklink /j "${1}" "$(cygpath -w "${2}")";

# vim:ts=8 sw=8 tw=150 noexpandtab foldmethod=marker
# vim:fileencoding=utf-8
