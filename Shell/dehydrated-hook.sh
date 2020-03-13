#!/bin/sh

# {{{ clean_challenge()
#
# This hook is called after attempting to validate each domain,
# whether or not validation was successful. Here you can delete
# files or DNS records that are no longer needed.
#
# The parameters are the same as for deploy_challenge.
#
clean_challenge() {
	local DOMAIN="${1}" TOKEN_FNAME="${2}" TOKEN_VALUE="${3}" SSH_HNAME="" SSH_USER="root";
	if SSH_HNAME="$(get_ssh_hname "${DOMAIN}")"; then
		ssh -l"${SSH_USER}" "${SSH_HNAME}" "
			TOKEN_DNAME=\"/var/www/${DOMAIN}/.well-known\";
			rm -f \"\${TOKEN_DNAME}/${TOKEN_FNAME}\";
			if [ \"\$(find \"\${TOKEN_DNAME}\" -maxdepth 1 -mindepth 1 | wc -l)\" -eq 0 ]; then
				rm -fr \"\${TOKEN_DNAME}\";
			fi";
	fi;
};
# }}}
# {{{ deploy_cert
#
# This hook is called once for each certificate that has been
# produced. Here you might, for instance, copy your new certificates
# to service-specific locations and reload the service.
#
# {{{ Parameters:
# - DOMAIN
#   The primary domain name, i.e. the certificate common
#   name (CN).
# - KEYFILE
#   The path of the file containing the private key.
# - CERTFILE
#   The path of the file containing the signed certificate.
# - FULLCHAINFILE
#   The path of the file containing the full certificate chain.
# - CHAINFILE
#   The path of the file containing the intermediate certificate(s).
# - TIMESTAMP
#   Timestamp when the specified certificate was created.
# }}}
#
deploy_cert() {
	local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}" TIMESTAMP="${6}"	\
		CERT_DEST_DNAME="" CERT_DEST_FNAME="" DAEMON_NAME="" KEY_DEST_FNAME=""					\
		CERT_FULL_FNAME="$(mktemp)" SSH_HNAME="$(get_ssh_hname "${1}")" SSH_USER="toor"				\
		CERT_DEST_DNAMES="" CERT_DEST_FNAMES="" DAEMON_NAMES="" KEY_DEST_FNAMES="";
	if ! get_domain_env "${DOMAIN}"; then
		echo "error: failed to obtain environment for \`${DOMAIN}'." >&2; return 1;
	elif ! cat "${CERTFILE}" "${FULLCHAINFILE}" > "${CERT_FULL_FNAME}"; then
		echo "error: failed to merge \`${CERTFILE}' and \`${FULLCHAINFILE}' into \`${CERT_FULL_FNAME}'." >&2; return 1;
	else	trap "rm -f \"${CERT_FULL_FNAME}\"" EXIT;
		while [ -n "${CERT_DEST_DNAMES}" ]\
		&&    [ -n "${CERT_DEST_FNAMES}" ]\
		&&    [ -n "${DAEMON_NAMES}" ]\
		&&    [ -n "${KEY_DEST_FNAMES}" ]; do
			CERT_DEST_DNAME="${CERT_DEST_DNAMES%% *}"; CERT_DEST_FNAME="${CERT_DEST_FNAMES%% *}";
			DAEMON_NAME="${DAEMON_NAMES%% *}"; KEY_DEST_FNAME="${KEY_DEST_FNAMES%% *}";
			scp -q "${CERT_FULL_FNAME}" "${SSH_USER}@${SSH_HNAME}:${CERT_DEST_DNAME}/${CERT_DEST_FNAME}";
			scp -q "${KEYFILE}" "${SSH_USER}@${SSH_HNAME}:${CERT_DEST_DNAME}/${KEY_DEST_FNAME}";
			ssh -l"${SSH_USER}" "${SSH_HNAME}" "
				chmod 0640 \"${CERT_DEST_DNAME}/${CERT_DEST_FNAME}\" \"${CERT_DEST_DNAME}/${KEY_DEST_FNAME}\";
				chown \"\$(stat -c \"%u:%g\" ${CERT_DEST_DNAME})\" \"${CERT_DEST_DNAME}/${CERT_DEST_FNAME}\" \"${CERT_DEST_DNAME}/${KEY_DEST_FNAME}\";
				case \"${DAEMON_NAME}\" in
				\"\")	;;
				=*)	pkill -HUP -f \"${DAEMON_NAME#=}\"; ;;
				*)	systemctl restart \"${DAEMON_NAME}\"; ;;
				esac;";
			if [ "${CERT_DEST_DNAMES#* *}" = "${CERT_DEST_DNAMES}" ]; then
				break;
			else
				CERT_DEST_DNAMES="${CERT_DEST_DNAMES#* }"; CERT_DEST_FNAMES="${CERT_DEST_FNAMES#* }";
				DAEMON_NAMES="${DAEMON_NAMES#* }"; KEY_DEST_FNAMES="${KEY_DEST_FNAMES#* }";
			fi;
		done; rm -f "${CERT_FULL_FNAME}" EXIT; trap - EXIT; return 0;
	fi;
};
# }}}
# {{{ deploy_challenge()
#
# This hook is called once for every domain that needs to be
# validated, including any alternative names you may have listed.
#
# {{{ Parameters:
# - DOMAIN
#   The domain name (CN or subject alternative name) being
#   validated.
# - TOKEN_FILENAME
#   The name of the file containing the token to be served for HTTP
#   validation. Should be served by your web server as
#   /.well-known/acme-challenge/${TOKEN_FILENAME}.
# - TOKEN_VALUE
#   The token value that needs to be served for validation. For DNS
#   validation, this is what you want to put in the _acme-challenge
#   TXT record. For HTTP validation it is the value that is expected
#   be found in the $TOKEN_FILENAME file.
# }}}
#
deploy_challenge() {
	local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" SSH_HNAME="" SSH_USER="root";
	if SSH_HNAME="$(get_ssh_hname "${1}")"; then
		ssh -l"${SSH_USER}" "${SSH_HNAME}" "set -o errexit;
			TOKEN_DNAME=\"/var/www/${DOMAIN}/.well-known/acme-challenge\";
			mkdir -p \"\${TOKEN_DNAME}\";
			install -g www-data -m 0640 -o www-data /dev/null \"\${TOKEN_DNAME}/${TOKEN_FILENAME}\";
			printf \"%s\n\" \"${TOKEN_VALUE}\" > \"\${TOKEN_DNAME}/${TOKEN_FILENAME}\"";
	fi;
};
# }}}

dehydrated_hook() {
	local _handler="${1}" _rc=0; shift;
	if ! source "${HOME}/.dehydrated.rc"; then
		_rc=1; echo "error: failed to source \`${HOME}/.dehydrated.rc'." >&2;
	elif ! type get_ssh_hname >/dev/null 2>&1\
	||   ! type get_domain_env >/dev/null 2>&1; then
		_rc=1; echo "error: missing get_ssh_hname() and/or get_domain_env() functions." >&2;
	else	case "${_handler}" in
		clean_challenge|exit_hook|generate_csr|deploy_cert|deploy_challenge|deploy_ocsp|invalid_challenge|request_failure|startup_hook|sync_cert|unchanged_cert)
			if type "${_handler}" >/dev/null 2>&1; then
				"${_handler}" "${@}"; _rc="${?}";
			fi; ;;
		esac;
	fi; return "${_rc}";
};

set +o errexit -o noglob; dehydrated_hook "${@}";

# vim:tw=0
