# $Id$
#

HOSTNAME="${COLLECTD_HOSTNAME:-localhost}";
INTERVAL="${COLLECTD_INTERVAL:-60}";

logger -t collectd "$0 executed (command line: $*), writing env (1) output to /tmp/env.$$.";
env >| /tmp/env.$$;

# vim:ts=8 sw=8 tw=120 noexpandtab foldmethod=marker
