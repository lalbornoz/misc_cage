#!/usr/local/bin/zsh
#
MYADDR="${1}"
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"
for sa sp da dp in									\
	`netstat -nfinet | perl -lne 'print "$1 $2 $3 $4" if				\
				m,('"${MYADDR}"')\.([0-9]+)\s+([0-9.]+)\.([0-9]+),'`;
	tcpdrop ${sa} ${sp} ${da} ${dp};

# vim:ts=8 sw=8 noexpandtab
