#!/bin/sh
#

URL_UPLOAD="https://pomf.is/upload.php";
if [ ${#} -eq 0 -o -z "${1#-h}" ]; then
	echo "usage: ${0} pathname [pathname...]"; exit 1;
else
	while [ ${#} -gt 0 ]; do
		OUTPUT_UPLOAD="$(curl -fsF "files[]=@${1}" "${URL_UPLOAD}")";
		if [ "${OUTPUT_UPLOAD#*\"success\":true*}" != "${OUTPUT_UPLOAD}" ]; then
			OUTPUT_URL="${OUTPUT_UPLOAD#*\"url\":\"}";
			OUTPUT_URL="${OUTPUT_URL%%\"*}";
			echo "${OUTPUT_URL}" | sed 's,\\/,/,g';
		else
			echo "failed to upload \`${1}', JSON output: \`${OUTPUT_URL}'";
		fi;
		shift;
	done;
fi;
