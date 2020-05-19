#!/bin/sh

for FNAME in "${@}"; do
	curl -F'file=@'"${FNAME}" "https://0x0.st";
done;
