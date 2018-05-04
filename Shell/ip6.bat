ipv6 install
ipv6 rtu ::/0 2 life 0
ipv6 rtu ::/0 2/::192.88.99.1 pub
ipv6 adu 2/2002:%1::1

netsh int portp add v4tov6 listenport=52119 listenaddress=127.0.0.1 connectport=119 connectaddress=news.ipv6.eweka.nl
netsh int portp add v4tov6 listenport=52120 listenaddress=127.0.0.1 connectport=119 connectaddress=newszilla6.xs4all.nl
netsh int portp add v4tov6 listenport=52121 listenaddress=127.0.0.1 connectport=119 connectaddress=reader.ipv6.xsnews.nl
