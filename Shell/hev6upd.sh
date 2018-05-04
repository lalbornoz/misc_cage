#!/bin/sh
# $Id: /scripts/hev6upd.sh 169 2009-04-15T14:18:22.382670Z arab  $
#
#  Performs the out-of-band update of the automatically inferred IPv4 endpoint
# for the tunnel and with the necessary parameters either specified on the
# command line or otherwise by falling back to the hard-wired defaults
# below.
#
# {{{ This script currently does support the mechanisms employed by:
#	1) /Hurricane Electric Free IPv6 Tunnel Broker/ [1], and
#		-- Requiring the tunnel ID and corresponding {user_id,pass}
#		   authentication information.
#		   Refer to [2] and [3] for the formalized procedure involved here.
#	2) /Malaysia IPv6 Tunnel Broker by MyBSD/ [4].
#		-- Solely requiring the {user name,password} pair.
# }}}
# {{{ Relevant WWW site links
#	[1] http;//www.tunnelbroker.net/
#	[2] http://www.tunnelbroker.net/forums/index.php?topic=150.msg663#msg663
#	[3] https://ipv4.tunnelbroker.net/ipv4_end.php
#	[4] http://tbroker.mybsd.org.my/
# }}}
# {{{ N.B. Security implications
# 	While the actual exchange of sensitive information, in case of HE,
#	occurs over a {TLS,SSL} secured link, this script should really only
#	be used on a single-user box with either no or explicitely controlled
#	access from the public Internet (due to in part at least for either
#	this script containing ie. the MD5 hash of the password or the
#	latter being part of the command line for this script once called.
# }}}
# {{{ Prerequisites and supported platforms
#  Tested on:   sh(1) on FreeBSD 7.1-RELEASE-p4
#  Requires:	SuS conforming sh(1), printf(1) and {g,n,one-true-}awk,
#		{{Free,Open,Net} BSD,GNU}-`style' ifconfig(1),
#		stock Perl (no particular modules,) and
#		wget(1).
# }}}
#  Last update: Wed Apr 15 2009
#   -- by vxp/arab  (EFnet & irc.f1re.org #arab)
#

# From which netif to infer the IPv4 endpoint address for this host
# from; _do_ make sure to adjust this.
_netif="tun0"

# {{{ Hard-wired defaults (do specify, arguments passed as part of command line take precedence.)
# {{{ Hurricane Electric
_he_pass=""			# The MD5 Hash of your password
_he_user_id=""			# The User_id from the main page of the tunnelbroker
_he_tunnel_id=""		# The Global Tunnel ID from the tunnel_details page
# }}}
# {{{ MyBSD
_mybsd_pass=""			# Your account password in plain text.
_mybsd_username=""		# Your user name to log on with.
# }}}
# }}}
# {{{ Environmental preparation
# trap(1) the relevant set of signals to ensure clean script termination.
trap abort_exec SIGHUP SIGINT SIGQUIT SIGPIPE SIGTERM SIGUSR1 SIGUSR2;

# Sanitize PATH.
PATH=/bin:/sbin:/usr/bin:/usr/local/bin ; export PATH
# }}}

# {{{ subr
abort_exec() {
	[ -n "${cj_path}" ] && { rm -f "${cj_path}" 2>/dev/null; };
	printf "\n--- ABORTED ---\n";
	exit 1;
}

help_and_exit() {
	echo "error: invalid or invalid argument count";
	echo "usage: $0 he     <pass> <user> <tunnel_id>";
	echo "       $0 mybsd  <pass> <user>";
	echo "   Refer to the block comments in this here script for"
	echo "  more information.";
	echo "   Not passing one or more parameters for a given tunnel"
	echo "  type implies falling back to the hard-wired values"
	echo "  configured within the script."
	exit 2;
}

say() {
	[ $# -eq 0 ] && { echo "error: say() called with 0 arguments"; exit 50; };
	local n; [ -z "${1##-n}" ] && { n="-n"; shift; };
 	echo ${n} "[`date '+%d/%m/%Y %H:%M.%S' 2>/dev/null`] $*";
}

# }}}
# {{{ per-tunnel type subr
mybsd() {
	[ -n "$1" -a -f "$1" -a -r "$1" -o -z "$2" ] || {
		say "error: mybsd($*) called with non-accessible HTML document file, aborting execution.";
		exit 10;
	};

	[ "${2##http://tbroker.mybsd.org.my/index.php?op=update}" = "$2" ] && { return; };

	local ipv4;
	ipv4=` perl -le 'local $/;	\
			 my ($html) = (<>);
			 print $1 if ($html =~ m#MyBSD IPv4 tunnel endpoint.+?<b>.+?([0-9.]+).+?</b>#s)' < "$1"`;

	[ $? -ne 0 ] && {
		say "error: perl(1) invoked in mybsd($*) returned non-zero exit value, aborting execution.";
		say "error: std{err,out}: \`${ipv4}'";
		exit 11;
	};

	say "Remote IPv4 endpoint: \`${ipv4}'";
}
# }}}
# {{{ {help,usage} information
[ $# -gt 0 ] || { help_and_exit; };
# }}}
# {{{ argument parsing and tunnel type arbitration
tunnel_type="${1}" ; shift
say "Running $0 for tunnel type \`${tunnel_type}'."
ipv4b=`ifconfig ${_netif} inet 2>/dev/null | awk '/inet / { print $2 }'`;
say "Inferred IPv4 endpoint address /${ipv4b}/ from netif \`${_netif}'."

if [ -z "${tunnel_type##he}" ]; then
	# {{{ Hurricane Electric
	pass=${1:-${_he_pass}}			# The MD5 Hash of your password
	user=${2:-${_he_user_id}}		# The User_id from the main page of the tunnelbroker
	tunnel_id=${3:-${_he_tunnel_id}}	# The Global Tunnel ID from the tunnel_details page

	#
	# Enforce the validity of the supplied parameters, constraining the tunnel
	# ID to a numeric value and not permitting either the user name aswell as its
	# corresponding password values to be empty.
	[ -z "${pass}" -o -z "${user}" -o	\
	  -n "${tunnel_id##[0-9]*}" ] && {
		say "error: invalid arguments and/or count for tunnel type \`he'";
		help_and_exit;
	};

	urls="http://ipv4.tunnelbroker.net/ipv4_end.php?ipv4b=${ipv4b}&pass=${pass}&user_id=${user}&tunnel_id=${tunnel_id}"
	# }}}
elif [ -z "${tunnel_type##mybsd}" ]; then
	# {{{ MyBSD
	pass=${1:-${_mybsd_pass}}
	user=${2:-${_mybsd_username}}

	#
	# Enforce the validity of the supplied parameters by not
	# permitting either of the user name aswell as its corresponding
	# password to be empty values.
	[ -z "${pass}" -o -z "${user}" ] && {
		say "error: invalid arguments and/or count for tunnel type \`he'";
		help_and_exit;
	};

	#
	# /MyBSD/ requires seperates operations on the actual account from identification
	# and authentication to and for the latter, plus does intrinsically, at least,
	# suggest a subsequent /log out/; therefore, a total of /3/ HTTP requests are
	# required.
	urls="http://tbroker.mybsd.org.my/index.php?op=logout"
	urls="http://tbroker.mybsd.org.my/index.php?op=update&v4=${ipv4b}${urls}"
	urls="http://tbroker.mybsd.org.my/index.php?op=login&username=${user}&password=${pass}${urls}"
	# }}}
else
	say "error: unknown tunnel type \`${tunnel_type}', aborting execution."
	exit 2;
fi
# }}}
# {{{ init
say -n "Creating cookie jar: "
cj_path="`mktemp -t cjar`" || {
	say "mktemp(1) returned non-zero exit value, aborting execution.";
	exit 3;
};
say "\`${cj_path}'."
# }}}

say "Dispatching HTTP requests for ${user}@\`${tunnel_type}'."
_IFS="${IFS}" ; IFS=''
for url in ${urls}
do
	#
	#  Produce and create a file into which wget(1) shall place the
	# raw HTML documented pointed to by the URL currently being processed.
	#  This is done preliminarily to aid per-tunnel type parameters
	# gathering from the corresponding documents where ie. notably /MyBSD/
	# does place them.
	html_path="`mktemp -t ${tunnel_type}.html`" || {
		say "mktemp(1) returned non-zero exit value, aborting exection.";
		exit 4;
	};

	# Sanity check the cookie jar file.
	[ -f "${cj_path}" -a -r "${cj_path}" -a -w "${cj_path}" ] || {
		say "Unable to access the cookie jar file \`${cj_path}', aborting execution.";
		exit 5;
	};

	#
	# Dispatch the actual wget(1) with /safe/ timeouts and retries, given
	# a link layer that is either still negotiating or a network layer that
	# may or may not be routed next-hop, etc.
	say -n "{GET,POST}ing \`${url}': "
	wget	--read-timeout=5 --waitretry=2 --tries=128		\
		--load-cookies "${cj_path}" --save-cookies "${cj_path}"	\
		--keep-session-cookies -qO "${html_path}"		\
		"${url}"

	echo "wget(1) returned /$?/.";

	[ "${tunnel_type}" = "mybsd" ] && { mybsd "${html_path}" "${url}"; };
	rm -f "${html_path}" 2>/dev/null;
done
IFS="${_IFS}"

# vim:sw=8 ts=8 noexpandtab foldmethod=marker
