#!/bin/sh
cd "${HOME}/.dehydrated" && ./dehydrated -c -k "$(which dehydrated-hook.sh)" "${@}";
