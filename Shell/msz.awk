#!/usr/bin/awk -f
# $Id: /scripts/msz.awk 84 2009-03-19T17:31:32.600974Z arab  $
# ps(1) filter extending and provisioning:
#	1) Process selection according to a regular expression applied to
#	   both the full aswell as the mere executable name (ie. /argv[0]/,)
#	2) per-keyword totals, expressed in MB (Megabytes.)
#
# Usage: ps [-[ ... ]] | [./]msz.awk [cmd=/regex/] [f=<space seperated keywords>]
#  alt.: [./]msz.awk [ ... ]<(ps [-[ ... ]])
# The latter alternative form is valid for Zsh (see zshexpn(1)) and Ksh (see ksh(1).)
#
# The script defaults to counting RSS and VSZ for each qualifying process
# (ie. line in ps(1)' output.)
#
#  -- vxp (<l.illanes@gmx.de>, irc.f1re.org #arab)
#

# {{{ Header line
NR == 1 {
	#
	# Prepare the list of desired column names to chase, either
	# passed to the script on the command-line or set from the
	# default fallback string specification below.
	if(!f)		f="rss vsz";
	if(cmd)		{ f="command " f; }
	split(f, _f);

	#
	# Infer the record number of the requested fields from
	# their relative, fixed position within ps(1)' output
	# format, populating two book-keeping arrays indexing
	# field position and value count totals, resp.
	for(nf = 1; nf <= NF; nf++)
		for(fw in _f)
			if(tolower(_f[fw]) == tolower($nf))
			{
				if(tolower($nf) == "command")
				{
					ns=nf;
					delete _f[fw]; continue;
				}

				recp[_f[fw]]=nf; recn[_f[fw]]=0;
				delete _f[fw];
			}

	if(!cmd || (cmd && !ns)) { ns=0; cmd=".*"; }

	#
	# Print column names not encountered in ps(1)' header line.
	if(length(_f))
		for(fw in _f)
			print "warning: column name `" _f[fw] \
			      "' not encountered, ignoring";

	print ">" $0;
}
# }}}
# {{{ Formatted per-process output lines
NR != 1 {
	# Collate the command specification into one single string, if
	# present at all.
	ccmd="";
	for(rn = ns; rn <= NF; rn++)
		ccmd=ccmd $rn " ";
}
# }}}
# {{{ Match the command regex against the line's resp. captured record number
NR != 1 && (ccmd ~ cmd) {
	print ">" $0;

	#
	# Accumulate field values which we were ordered to care about,
	# as per the corresponding array tracking record numbers.
	for(n in recp)
		recn[n] += $recp[n];
}
# }}}
# {{{ END
END {
	# Do fail if there weren't any field values left for the logic
	# above to count at all.
	if(!length(recn))
	{
		print "error: left with no values to count, go fuck yourself asshole";
		exit(2);
	}

	# Print the totals in MB.
	print "";
	for(n in recn)	printf("%10s", toupper(n)); printf("\n");			# Header line
	for(n in recn)	printf("%10s", (recn[n] / 1024.0) "M"); printf("\n");		# Counted totals
}
# }}}

# vim:ts=8 sw=8 noexpandtab
