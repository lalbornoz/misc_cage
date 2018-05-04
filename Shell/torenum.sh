#!/bin/sh
# $Id: amal.arabs.ps [NetBSD/i386 v5.1-RELEASE] $
# $Author: Lucio `vxp' Albornoz <l.illanes@gmx.de> <irc://irc.arabs.ps/arab> $
#

_POST_DATA='SR=Name&SO=Asc&FAuthority=OFF&FBadDirectory=OFF&FBadExit=OFF&FExit=1&FFast=OFF&FGuard=OFF&FHibernating=OFF&FNamed=OFF&FStable=OFF&FRunning=OFF&FValid=OFF&FV2Dir=OFF&FHSDir=OFF&CSField=Fingerprint&CSMod=Equals&CSInput=' ; 

wget	--post-data="${_POST_DATA}"					 \
	--no-check-certificate -qO- -T 5 --waitretry=4 --random-wait	 \
	--tries=14							 \
	https://torstat.xenobite.eu/index.php				|\
perl	-lne '
	while(m,<a href='\''router_detail[^'\'']+?'\''>(.+?)</a>,g) {
		print $1 unless (lc($1) eq lc("Unnamed"));
	}' ;

# vim:ts=8 sw=8 tw=80 noexpandtab foldmethod=marker
