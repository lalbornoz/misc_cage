#!/usr/bin/env zsh
IFS=$'\n';
_ds="${1}";
for _mtpoint in $(zfs list -Ht filesystem -r lucio-vm-home | cut -f5- ); do
	printf "%s\n%s\n\n" "${_mtpoint}" "$(echo "${_mtpoint}" |\
		sed 's,.,-,g')";
	(cd "${_mtpoint}/.zfs/snapshot/${_ds}" &&\
		rsync -aAHinPrvx --delete --numeric-ids "${_mtpoint}/" .);
done 2>&1 | tee rsync_${_ds}.log;
