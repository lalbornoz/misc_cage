#!/bin/sh
set -o errexit;
_window_opacity="10";
_window_opacity_hex="$(printf "0x%08x" $((4294967295 - 4294967295 * ${_window_opacity:-10} / 100)))";
"${@}" &
_window_pid="${!}";
sleep 0.5;
_window_ids="$(xdotool search --pid "${_window_pid}")";
for _window_id in ${_window_ids}; do
	xprop -id "${_window_id}"					\
		-f _NET_WM_WINDOW_OPACITY 32c				\
		-set _NET_WM_WINDOW_OPACITY "${_window_opacity_hex}";
done;
