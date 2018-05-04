#!/usr/bin/env sh
_ss="${1:?usage: ${0} snapshot [dataset]}";
_ds_src="${2:-lucio-vm-home}";
_log_fname="rsync_zsh.$(date +%d%m%Y_%H%M%S).log";
IFS="
"; for _mt_point in $(zfs list -Hrt filesystem "${_ds_src}" | cut -f5); do
	printf "%s\n%s\n\n" "${_mt_point}" "$(printf "%*s" ${#_mt_point} " " | sed "s/ /-/g")";
	rsync -aHiPrvx --delete -n "${_mt_point%/}/" "${_mt_point%/}/.zfs/snapshot/${_ss}/";
	printf "\n";
done | tee "${_log_fname}";
