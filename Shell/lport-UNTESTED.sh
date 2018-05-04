#!/bin/sh
# $Id: /scripts/lport-UNTESTED.sh 84 2009-03-19T17:31:32.600974Z arab  $
# (Not) Tested with the base sh(1) on /FreeBSD 7.1-RELEASE i386/.
# Commands required to be located in PATH:
#	id(1) pw(8) awk(1) mkdir(1) ln(1) make(1)
# Additionally requires the ports(7) tree plus the relevant set
# of system Makefiles to be present in the formally `standardized'
# places where FreeBSD's base system provisions them by default.
#
# Do note that shared objects (esp. during {building,install'ing}; see rtld(1),)
# manual pages (see manpath(1),) and installed binaries will solely be [conveniently]
# accessible given their or their topmost parent directory's inclusion in the
# corresponding environ(7)ment variables, ie.:
#	LD_LIBRARY_PATH="${LD_LIBRARY_PATH:+${LD_LIBRARY_PATH}:}<PREFIX>/lib"
#	MANPATH="${MANPATH:+`manpath 2>/dev/null`:}<PREFIX>/man"
#	PATH="${PATH:+${PATH}:}<PREFIX>/bin:<PREFIX>/sbin"
#
#	-- vxp/arab (irc.f1re.org #arab, <l.illanes@gmx.de>)
#
# {{{ Constants and default fallbacks
_HOME=`( pw user show \`id -u\` | awk -F: '{print $9}' ) 2>/dev/null`
_HOME="${HOME:-${_HOME}}"	# {{{ N.B.
				#	Collapsing both of these parameter expansions and
				# 	expressions into one demonstrates a shortcoming in
				#	Vim's syntaxis logic for sh(1), rendering colouring
				#	and highlighting et al for the lines below the
				#	then-collapsed statement in{valid,correct}.
				# }}}
_PORTS="/usr/ports"
_PREFIX="${_HOME}/local"
_BUILD_PATH="${TMPDIR:-/tmp}/lport-build.`id -un 2>/dev/null`"
_BUILDLOGS_PATH="`pwd`"
# }}}
# {{{ subr
#
# Creates and populates the local tree with the minimum
# set of convenient aswell as necessary directories and
# symlinks to end up with a sort-of replica reflecting
# hier(7) as contained beneath / (filesystem root) and
# the USR distribution{,s} et al.
populate_prefix()
{
	# Do make sure to position the future directory
	# to-be-created's parent behind the former if
	# you wish to add to this list.
	for _subdir in bin sbin etc include \
		      lib libexec libdata  \
		      share share/doc share/man
	do
		_dirname="${_PREFIX}"/"${_subdir}";
		echo -n "Attempting to mkdir(1) \`${_dirname}': "
		mkdir -p "${_dirname}" || {
			echo " failed, exiting."; exit 6; };
		echo "succeeded."
	done

	# symlink(7)s go here.
	ln -fs "${_PREFIX}/share/man" "${_PREFIX}/man" || {
		echo " failed, exiting."; exit 7; };
}

#
# Similar to the above subr, aids the ports(7) make(1)-implemented
# building process by providing the necessary subdirectories which
# the iterative process below in the command's primary logic
# refers to; see ports(7) and <PORTS>/Mk/bsd.port.mk for details.
populate_build_tree()
{
	for _subdir in distfiles db db/pkg db/ports work
	do
		_dirname="${_BUILD_PATH}"/"${_subdir}";
		mkdir -p "${_dirname}" || { echo " failed, exiting."; exit 10; };
	done
}
# }}}

[ $# -eq 0 ] && { echo "usage: $0 port-name [ ... ]"; exit 1; };
# {{{ Sanity checks
# HOME directory presence and access
[ -z "${HOME}" -a -z "${_HOME}" ] && { echo "error: can't infer unset \`HOME', exiting"; exit 2; };
[ -d "${_HOME}" -a -w "${_HOME}" -a -x "${_HOME}" ] || {
	echo "error: HOME directory isn't and/or lacks /-w-/ and/or /--x/ permission bits."; exit 3; };

# ports(7) tree path
[ -d "${_PORTS}" -a -x "${_PORTS}" ] || {
	echo "error: ports(7) tree pathname  \`${_PORTS}' points to an inaccessible {,non-} directory"; exit 4; };

# Local tree, see above /subr/
[ -d "${_PREFIX}" -a -w "${_PREFIX}" -a -x "${_PREFIX}" ] || {
	echo "error: local tree pathname PREFIX \`${_PREFIX}' isn't and/or lacks /-w-/ and/or /--x/ permission bits.";
	echo -n "	     Would you like this script to create and pre-populate the necessary directory structure now? [yN] ";
	set choice=""; read choice;
	case "${choice}" in
		[yY]*) populate_prefix(); echo; ;;
		    *) echo " exiting."; exit 5; ;;
	esac;
};

# Temporary build scratch space
[ ! -w "${_BUILD_PATH}" ] && {
	echo -n "error: temporary build scratch space directory \`${_BUILD_PATH}' doesn't exist, create? [Yn] ";
	set choice=""; read choice;
	case "${choice}" in
		[nN]*) echo " exiting."; exit 9; ;;
		    *) populate_build_tree(); echo; ;;
	esac;
};

# Directory in which to place build log files (cwd, per default)
[ -w "${_BUILDLOGS_PATH}" ] || {
	echo "error: build logs directory \`${_BUILDLOGS_PATH}' inaccessible or non-existent."
	exit 8;
};
# }}}

echo "Commencing build{,s} at `date`."

#
# Iterate over the arguments given to this here script, logging the
# corresponding port builds and installs individually.
while [ $# -ne 0 ]
do
	_port="$1"; _port_path="${_PORTS}"/"${_port}";
	_logfname="${_BUILDLOG_PATH}/`echo \"${_port}\" | sed 's,/,.g; s,\.$,,;'`-`date +%d%m%Y-%H%M%S`.log";
	[ $? -ne 0 -o ( ! -w "${_logfname}" ) ] && {
		echo " -- sed(1) failed for some reason or other, go fuck yourself."; exit 666; };

	[ -x "${_port_path}" ] || {
		echo " -- port \`${_port}' inaccessible or non-existent, ignored.";
		continue;
	};

	echo -n "Attempting to build and install \`${_port}' and its dependencies into \`${_PREFIX}', logging into \`${_logfname}': "
	echo -n >| "${_logfname}"
	( make -C "${_port_path}"	DISTDIR="${_BUILD_PATH}/distfiles"					\
					PKG_DBDIR="${_BUILD_PATH}/db/pkg" PORT_DBDIR="${_BUILD_PATH}/db/ports"	\
					WRKDIRPREFIX="${_BUILD_PATH}/work" PREFIX="${_PREFIX}"			\
					INSTALL_AS_USER=1	all install clean ) >> "${_logfname}"

	if [ $? -ne 0 ]; then	echo "failed (non-zero exit value \`$?')";
			 else	echo "succeeded";
	fi; shift;
done

echo; echo "Build{,s} finished at `date`."
# vim:ts=8 sw=8 noexpandtab foldmethod=marker
