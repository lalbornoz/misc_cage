#!/bin/sh
cd "${HOME}/.dehydrated" && ./dehydrated -c -k dehydrated-hook.sh "${@}";
