#!/bin/sh
set -o errexit;
if [ ${#} -lt 2 ]	\
|| [ -z "${1}" ]	\
|| [ -z "${2}" ]; then
	echo "usage: ${0} user app [args...]";
	exit 1;
else
	RCUSER_XAUTH_MODE="0660";
	RCUSER_XAUTH_SRC_USER="$(id -nu)";
	RCUSER_XAUTH_TGT_USER="${1}"; shift;
	RCUSER_XAUTH_TGT_GROUP="${RCUSER_XAUTH_TGT_USER}";
	if ! getent group "${RCUSER_XAUTH_TGT_GROUP}" >/dev/null; then
		echo "error: target group \`${RCUSER_XAUTH_TGT_GROUP}' non-existent";
		exit 2;
	elif ! getent passwd "${RCUSER_XAUTH_TGT_USER}" >/dev/null; then
		echo "error: target user \`${RCUSER_XAUTH_TGT_USER}' non-existent";
		exit 3;
	elif ! RCUSER_XAUTH_TGT_USER_HOME=$(
			getent passwd "${RCUSER_XAUTH_TGT_USER}" 	|\
			awk -F: '{print $6}'); then
		echo "error: cannot obtain \$HOME directory for user \`${RCUSER_XAUTH_TGT_USER}'";
		exit 4;
	elif ! RCUSER_XAUTH_SRC_USER_HOME=$(
			getent passwd "${RCUSER_XAUTH_SRC_USER}" 	|\
			awk -F: '{print $6}'); then
		echo "error: cannot obtain \$HOME directory for user \`${RCUSER_XAUTH_SRC_USER}'";
		exit 5;
	fi;

fi;
sudo -u root /usr/bin/install						\
	-m "${RCUSER_XAUTH_MODE}"					\
	-g "${RCUSER_XAUTH_TGT_USER}"					\
	-o "${RCUSER_XAUTH_TGT_USER}"					\
	"${RCUSER_XAUTH_SRC_USER_HOME}/.Xauthority"			\
	"${RCUSER_XAUTH_TGT_USER_HOME}/.Xauthority";
set +o errexit;
sudo -Hiu "${RCUSER_XAUTH_TGT_USER}" env				\
	DISPLAY="${DISPLAY}"						\
	XAUTHORITY="${RCUSER_XAUTH_TGT_USER_HOME}/.Xauthority"		\
	"${@}";
sudo -u root /usr/bin/install						\
	-m "${RCUSER_XAUTH_MODE}"					\
	-g "${RCUSER_XAUTH_TGT_USER}"					\
	-o "${RCUSER_XAUTH_TGT_USER}"					\
	/dev/null							\
	"${RCUSER_XAUTH_TGT_USER_HOME}/.Xauthority";
