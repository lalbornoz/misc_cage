#!/bin/sh
#
# roarie's [K]ubuntu >=22.10 provisioning script
#

#
# Global variables
#

HOSTNAME="";
LOG_FNAME="provision.log";
LOG_TMP_STDERR_FNAME="";
NFLAG=0;
SHIFT_COUNT=0;
YFLAG=0;

USER_NORMAL="lucia";
USER_TOOR="toor";


# {{{ provision_010_conf_local()
provision_010_conf_local_install() {
	local _pname="${1}" _pname_target="${2}";

	if [ -e "${_pname_target}" ]; then
		rc mv "${_pname_target}" "${_pname}.dist" || return "${?}";
	fi;
	rc ln -fs "${_pname}" "${_pname_target}" || return "${?}";
};

provision_010_conf_local() {
	local _fname="" _fname_target="" _fnames="" _pname="" _pname_target="";

	_pnames="$(rc -y find		\
		/conf.local/etc		\
		-maxdepth 1		\
		-mindepth 1		\
		-not -name \*.dist)" || return "${?}";
	for _pname in ${_pnames}; do
		_pname="${_pname%/}";
		_pname_target="/etc/${_pname##*/}";

		if [ ! -d "${_pname}" ]; then
			provision_010_conf_local_install "${_pname}" "${_pname_target}";
		elif [ -e "${_pname}/.LOCAL_DIRECTORY" ]; then
			provision_010_conf_local_install "${_pname}" "${_pname_target}";
		else
			_fnames="$(rc -y find		\
				"${_pname}"		\
				-not -name \*.dist	\
				-type f			\
				)" || return "${?}";
			for _fname in ${_fnames}; do
				_fname="${_fname%/}";
				_fname_target="${_fname#/conf.local}";
				provision_010_conf_local_install "${_fname}" "${_fname_target}";
			done;
		fi;
	done;

	_fnames="$(rc -y find			\
		/conf.local			\
		-not -path /conf.local/etc	\
		-not -path /conf.local/etc/\*	\
		-type f)" || return "${?}";
	for _fname in ${_fnames}; do
		_fname="${_fname%/}";
		_fname_target="${_fname#/conf.local}";
		provision_010_conf_local_install "${_fname}" "${_fname_target}";
	done;

	return 0;
};
# }}}
# {{{ provision_040_hibernate()
# {{{ provision_040_hibernate() variables
PROVISION_HIBERNATE_ROOT_NAME="root";
PROVISION_HIBERNATE_SWAP_NAME="swap_1";
PROVISION_HIBERNATE_VG_NAME="vgkubuntu";
# }}}
provision_040_hibernate() {
	local _swap_delta_mb="" _swap_size_cur_mb="" _swap_size_new_mb="";

	_swap_size_cur_mb="$(				\
		rc -y lvs --units m)" || return "${?}";

	_swap_size_cur_mb="$(				\
		printf "%s" "${_swap_size_cur_mb}"	|\
		awk '/'"${PROVISION_HIBERNATE_SWAP_NAME}"'/ {
			sub(/,/, ".", $NF);
		       	sub(/m$/, "", $NF);
			sub(/\..*$/, "", $NF);
			print $NF; }'			\
		)" || return "${?}";

	_swap_size_new_mb="$(				\
		rc -y awk '/^MemTotal/ {
			n = $2 / 1024 / 1024;
			if (n % 1) {
				n = (n - (n % 1)) + 1;
			};

			n++;

			print n * 1024}'		\
		/proc/meminfo				\
		)" || return "${?}";

	_swap_delta_mb="$((${_swap_size_new_mb:-0}-${_swap_size_cur_mb:-0}))";

	if [ "${_swap_delta_mb}" -gt 0 ]; then
		rc swapoff "/dev/${PROVISION_HIBERNATE_VG_NAME}/${PROVISION_HIBERNATE_SWAP_NAME}" || return "${?}";

		rc lvresize --units m -r -L "-${_swap_delta_mb}" "${PROVISION_HIBERNATE_ROOT_NAME}" || return "${?}";
		rc lvresize -r -l +100%FREE "${PROVISION_HIBERNATE_SWAP_NAME}" || return "${?}";

		rc mkswap -f "/dev/${PROVISION_HIBERNATE_VG_NAME}/${PROVISION_HIBERNATE_SWAP_NAME}" || return "${?}";

		rc mkinitramfs -u || return "${?}";
		rc update-grub || return "${?}";
	fi;

	rc systemctl enable disable_waking_devices || return "${?}";

	return 0;
};
# }}}
# {{{ provision_070_disable_bluetooth_wlan()
provision_070_disable_bluetooth_wlan() {
	if [ "${HOSTNAME#*-pc}" != "${HOSTNAME}" ]; then
		rc apt autoremove --purge bluedevil bluez bluez-obexd || return "${?}";
		rc systemctl disable bluetooth.service || return "${?}";
		rc systemctl disable wpa_supplicant.service || return "${?}";
	fi;

	return 0;
};
# }}}
# {{{ provision_075_disable_snap()
provision_075_disable_snap() {
	local _rc=0 _snap_name="" _snap_names="";

	#
	# Based on <https://onlinux.systems/guides/20220524_how-to-disable-and-remove-snap-on-ubuntu-2204>
	#

	_snap_names="$(snap list)" || return 1;
	_snap_names="$(printf "%s" "${_snap_names}" | awk 'NR != 1 {print $1}')";
	for _snap_name in ${_snap_names}; do
		rc snap remove "${_snap_name}" || return "${?}";
	done;

	rc systemctl disable snapd.service || return "${?}";
	rc systemctl disable snapd.socket || return "${?}";
	rc systemctl disable snapd.seeded.service || return "${?}";

	rc apt autoremove --purge snapd || return "${?}";
	set +o noglob;
	rc rm -fr /var/cache/snapd /home/*/snap "${HOME}/snap"; _rc="${?}";
	set -o noglob; [ "${_rc}" -ne 0 ] && return "${_rc}";

	return 0;
};
# }}}
# {{{ provision_080_users()
provision_080_users() {
	rc passwd root || return "${?}";
	rc sed -i"" '1{p;s/^root:/'"${USER_TOOR}"':/}' /etc/passwd /etc/shadow || return "${?}";
	rc chsh -s /usr/bin/zsh "${USER_NORMAL}" || return "${?}";
	rc chsh -s /usr/bin/zsh "${USER_TOOR}" || return "${?}";

	return 0;
};
# }}}

# {{{ provision_110_software_install()
PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION="525";

provision_110_software_install() {
	rc add-apt-repository -y ppa:mozillateam/ppa || return "${?}";
	rc add-apt-repository -y ppa:nicotine-team/stable || return "${?}";

	rc apt update -y || return "${?}";
	rc apt dist-upgrade -y || return "${?}";

	rc apt install -y								\
		apt-file iotop keyutils lm-sensors					\
		ifstat iptables-persistent open-iscsi openssh-server tor		\
		linux-image-lowlatency							\
											\
	       	build-essential clang-15 clangd-15					\
		dos2unix fd-find fzf gcp git python3-pip ripgrep tmux sqlite3 zsh	\
		ffmpeg yt-dlp								\
		gnupg2 irssi mutt ncat neovim net-tools ngrep rsync wget		\
											\
		codium									\
		firefox nicotine systray-x thunderbird					\
		gimp kolourpaint smplayer						\
		keepassxc meteo-qt psensor xfce4-timer-plugin				\
		libreoffice-calc libreoffice-writer neovim-qt				\
		wine winetricks								\
											\
		|| return "${?}";

	if [ "${HOSTNAME#*-pc}" != "${HOSTNAME}" ]; then
		rc apt install -y									\
			libnvidia-cfg1-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-common-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-compute-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-decode-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-extra-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-fbc1-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			libnvidia-gl-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			linux-modules-nvidia-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}-lowlatency	\
			nvidia-compute-utils-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}		\
			nvidia-kernel-common-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}		\
			nvidia-kernel-source-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}		\
			nvidia-utils-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}			\
			xserver-xorg-video-nvidia-${PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION}		\
			|| return "${?}";
	fi;

	return 0;
};
# }}}
# {{{ provision_130_software_remove()
provision_130_software_remove() {
	rc apt autoremove --purge -y					\
		evolution-data-server evolution-data-server-common	\
		gnome-bluetooth gnome-bluetooth-common			\
		modemmanager						\
		rsyslog							\
		speech-dispatcher					\
		vlc							\
		|| return "${?}";

	if [ "${HOSTNAME#*-pc}" != "${HOSTNAME}" ]; then
		rc apt autoremove --purge -y	\
			thermald		\
			|| return "${?}";
	fi;

	return 0;
};
# }}}
# {{{ provision_150_software_torbrowser()
provision_150_software_torbrowser() {
	local _rc=0;

	rc apt install -y							\
		dh-python python3-all python3-stdeb python3-pyqt5		\
		python3-gpg python3-requests python3-socks python3-packaging	\
		|| return "${?}";

	rc mkdir -p /usr/local/src || return "${?}";
	rc git clone "https://github.com/micahflee/torbrowser-launcher" /usr/local/src/torbrowser-launcher || return "${?}";

	rc cd /usr/local/src/torbrowser-launcher || return "${?}";
	rc ./build_deb.sh || return "${?}";
	set +o noglob;
	rc dpkg -i deb_dist/*.deb || return "${?}";
	set -o noglob; [ "${_rc}" -ne 0 ] && return "${_rc}";
	rc cd "${OLDPWD}" || return "${?}";

	return 0;
};
# }}}
# {{{ provision_155_software_wezterm()
PROVISION_SOFTWARE_WEZTERM_URL="https://github.com/wez/wezterm/releases/download/20221119-145034-49b9839f/wezterm-20221119-145034-49b9839f.Ubuntu22.04.deb";
provision_155_software_wezterm() {
	local _rc=0;

	rc wget	\
		-O "${PROVISION_SOFTWARE_WEZTERM_URL##*/}"	\
		"${PROVISION_SOFTWARE_WEZTERM_URL}"		\
		|| return "${?}";
	rc dpkg -i "${PROVISION_SOFTWARE_WEZTERM_URL##*/}" || return "${?}";

	return 0;
};
# }}}
# {{{ provision_170_software_configure()
provision_170_software_configure() {
	rc sudo -U "${USER_NORMAL}" balooctl config set contentIndexing no || return "${?}";
	rc sudo -U "${USER_NORMAL}" balooctl disable || return "${?}";
	rc sudo -U "${USER_NORMAL}" balooctl purge || return "${?}";
	rc sudo -U "${USER_NORMAL}" kwriteconfig5 --file kwalletrc --group "Wallet" --key "Enabled" "false" || return "${?}";
	rc sudo -U "${USER_NORMAL}" kwriteconfig5 --file kwalletrc --group "Wallet" --key "First Use" "false" || return "${?}";
	rc sudo -U "${USER_NORMAL}" winetricks wmp11 || return "${?}";
	# TODO xfce: 1) shortcuts 2) keyboard layouts 3) themes 4) autostart 5) panel 6) screensaver 7) wallpaper 8) clipboard 9) favourite apps 10) default apps for .mp4/...

	return 0;
};
# }}}
# {{{ provision_190_software_finish()
provision_190_software_finish() {
	rc apt-file update || return "${?}";
	rc rm -f /var/cache/apt/archives/*.deb || return "${?}";
	rc ln -fs /usr/bin/clangd-15 /usr/local/bin/clangd || return "${?}";

	return 0;
};
# }}}

# {{{ provision_210_services()
provision_210_services() {
	rc systemctl enable ssh || return "${?}";
	rc systemctl enable iscsid || return "${?}";

	rc systemctl disable tor || return "${?}";

	rc systemctl disable apport || return "${?}";
	rc systemctl mask apport || return "${?}";
	rc systemctl disable whoopsie || return "${?}";
	rc systemctl mask whoopsie || return "${?}";

	if [ "${HOSTNAME#*-pc}" = "${HOSTNAME}" ]; then
		rc systemctl disable wpa_supplicant || return "${?}";
		rc systemctl mask wpa_supplicant || return "${?}";
	fi;

	return 0;
};
# }}}
# {{{ provision_250_apt_src()
provision_250_apt_src() {
	rc sed -i.dist 's/^#\s*\(deb-src\)/\1/' /etc/apt/sources.list || return "${?}";
	rc apt update || return "${?}";

	return 0;
};
# }}}
# {{{ provision_28*_fonts_*() variables
PROVISION_FONTS_URL1="https://web.archive.org/web/20171225132744/http://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe";
PROVISION_FONTS_FNAME1="PowerPointViewer.exe"
PROVISION_FONTS_TARGET_DNAME1="/usr/share/fonts/truetype/vista";
PROVISION_FONTS_TMP_DNAME1="/tmp/fonts-vista";

PROVISION_FONTS_URL2="https://master.dl.sourceforge.net/project/corefonts/OldFiles/IELPKTH.CAB?viasf=1";
PROVISION_FONTS_FNAME2="IELPKTH.CAB"
PROVISION_FONTS_TARGET_DNAME2="/usr/share/fonts/truetype/msttcorefonts";
PROVISION_FONTS_TMP_DNAME2="/tmp/fonts-tahoma";

PROVISION_FONTS_URLS3="
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeui.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeuib.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeuib.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeuiz.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeuil.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/seguili.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/segoeuisl.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/seguisli.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/seguisb.ttf?raw=true
       https://github.com/martinring/clide/blob/master/doc/fonts/seguisbi.ttf?raw=true";
PROVISION_FONTS_TARGET_DNAME3="/usr/share/fonts/truetype/msttcorefonts";

PROVISION_FONTS_SCRIPT_STRING='Open("cambria.ttc(Cambria)"); Generate("cambria.ttf"); Close(); Open("cambria.ttc(Cambria Math)"); Generate("cambriamath.ttf"); Close();';
# }}}
# {{{ provision_281_fonts_core()
provision_281_fonts_core() {
	local _rc=0 _url="" _url_fname="";

	#
	# Based on <https://www.reddit.com/r/Kubuntu/comments/r2gmjo/microsoft_fonts_on_kubuntu/>
	#

	rc apt install cabextract fontforge kubuntu-restricted-extras || return "${?}";

	return 0;
};
# }}}
# {{{ provision_282_fonts_cleartype()
provision_282_fonts_cleartype() {
	local _rc=0 _url="" _url_fname="";

	#
	# Based on <https://www.reddit.com/r/Kubuntu/comments/r2gmjo/microsoft_fonts_on_kubuntu/>
	#

	rc rm -fr "${PROVISION_FONTS_TMP_DNAME1}" || return "${?}";
	rc mkdir -p "${PROVISION_FONTS_TMP_DNAME1}" || return "${?}";
	rc cd "${PROVISION_FONTS_TMP_DNAME1}" || return "${?}";

	rc wget -O "${PROVISION_FONTS_FNAME1}" "${PROVISION_FONTS_URL1}" || return "${?}";
	rc cabextract -t "${PROVISION_FONTS_FNAME1}" || return "${?}";
	rc cabextract -F "ppviewer.cab" "${PROVISION_FONTS_FNAME2}" || return "${?}";
	rc cabextract -L -F '*.tt?' ppviewer.cab || return "${?}";

	#
	# From script from above URL:
	#
	# If you need the Cambria and Cambria Math (regular) font, you'll need to convert it to TTF because the font is available
	# as a TrueType Collection (TTC) and unless you convert it, you won't be able to use it in LibreOffice for instance.
	#
    	rc fontforge					\
		-lang=ff				\
		-c "${PROVISION_FONTS_SCRIPT_STRING}"	\
		|| return "${?}";

	rc mkdir -p "${PROVISION_FONTS_TARGET_DNAME1}" || return "${?}";
	set +o noglob;
	rc cp -f *.ttf "${PROVISION_FONTS_TARGET_DNAME1}";
	set -o noglob; [ "${_rc}" -ne 0 ] && return "${_rc}";
	rc fc-cache -f "${PROVISION_FONTS_TARGET_DNAME1}" || return "${?}";

	rc cd "${OLDPWD}" || return "${?}";
	rc rm -fr "${PROVISION_FONTS_TMP_DNAME1}" || return "${?}";

	return 0;
};
# }}}
# {{{ provision_283_fonts_tahoma()
provision_283_fonts_tahoma() {
	local _rc=0 _url="" _url_fname="";

	#
	# Based on <https://www.reddit.com/r/Kubuntu/comments/r2gmjo/microsoft_fonts_on_kubuntu/>
	#

	rc rm -fr "${PROVISION_FONTS_TMP_DNAME2}" || return "${?}";
	rc mkdir -p "${PROVISION_FONTS_TMP_DNAME2}" || return "${?}";
	rc cd "${PROVISION_FONTS_TMP_DNAME2}" || return "${?}";

	rc wget -O "${PROVISION_FONTS_FNAME2}" "${PROVISION_FONTS_URL2}" || return "${?}";
	rc cabextract -t "${PROVISION_FONTS_FNAME2}" || return "${?}";
	rc cabextract -F 'tahoma*ttf' "${PROVISION_FONTS_FNAME2}" || return "${?}";

	rc mkdir -p "${PROVISION_FONTS_TARGET_DNAME2}" || return "${?}";
	set +o noglob;
	rc cp -f *.ttf "${PROVISION_FONTS_TARGET_DNAME2}";
	set -o noglob; [ "${_rc}" -ne 0 ] && return "${_rc}";
	rc fc-cache -f "${PROVISION_FONTS_TARGET_DNAME2}" || return "${?}";

	rc cd "${OLDPWD}" || return "${?}";
	rc rm -fr "${PROVISION_FONTS_TMP_DNAME2}" || return "${?}";

	return 0;
};
# }}}
# {{{ provision_284_fonts_segoe()
provision_284_fonts_segoe() {
	local _rc=0 _url="" _url_fname="";

	#
	# Based on <https://www.reddit.com/r/Kubuntu/comments/r2gmjo/microsoft_fonts_on_kubuntu/>
	#

	rc mkdir -p "${PROVISION_FONTS_TARGET_DNAME3}" || return "${?}";
	rc cd "${PROVISION_FONTS_TARGET_DNAME3}" || return "${?}";

	for _url in ${PROVISION_FONTS_URLS3}; do
		_url_fname="${_url##*/}";
		_url_fname="${_url_fname%%\?*}";
		rc wget -O "${_url_fname}" "${_url}" || return "${?}";
	done;

	rc fc-cache -f "${PROVISION_FONTS_TARGET_DNAME3}" || return "${?}";
	rc cd "${OLDPWD}" || return "${?}";

	return 0;
};
# }}}


# {{{ provision_exec()
provision_exec() {
	local	_title="${1}" _name="${2}" _name_pri="${3}"	\
		_legend="" _rc=0;

	_legend="$(printf					\
		"[35m>>> [1m%s[22m [4m[36m%s[0m"	\
		"${_name_pri}" "${_title}")";
	if [ "${LOG_FNAME:+1}" = 1 ]; then
		printf "%s\n" "${_legend}" | tee -a "${LOG_FNAME}";
	else
		printf "%s\n" "${_legend}";
	fi;

	"${_name}"; _rc="${?}";

	if [ "${_rc}" -ne 0 ]; then
		provision_exec_fail		\
			"${_title}" "${_name}"	\
			"${_name_pri}" "${_rc}";
	fi;

	return "${_rc}";
};
# }}}
# {{{ provision_exec_fail()
provision_exec_fail() {
	local	_title="${1}" _name="${2}" _name_pri="${3}" _rc="${4}"	\
		_legend="";

	_legend="$(printf						\
		"[35m>>> [1m%s[22m [91mError in [4m%s[0m"	\
		"${_name_pri}" "${_title}")";
	if [ "${LOG_FNAME:+1}" = 1 ]; then
		printf "%s\n" "${_legend}" | tee -a "${LOG_FNAME}";
	else
		printf "%s\n" "${_legend}";
	fi;

	printf "[35m>>> [97mContinue execution (y|N)? [0m";
	read _choice;
	case "${_choice}" in
	[yY])	return 0; ;;
	*)	exit "${_rc}"; ;;
	esac;
};
# }}}
# {{{ provision_if()
provision_if() {
	local	_title="${1}" _name="${2}"			\
		_execfl=0 _filter_cmdline="" _name_base=""	\
		_name_pri="";
	shift 2;

	_name_base="${_name#provision_*_}";
	_name_pri="${_name#provision_}"; _name_pri="${_name_pri%%_*}";

	if [ "${#}" -eq 0 ]; then
		_execfl=1;
	else
		for _filter_cmdline in "${@}"; do
			if [ "${_name_base#${_filter_cmdline}}" != "${_name_base}" ]; then
				_execfl=1; break;
			fi;
		done;
	fi;

	if [ "${_execfl}" = 1 ]; then
		provision_exec "${_title}" "${_name}" "${_name_pri}";
		return "${?}";
	else
		return 0;
	fi;
};
# }}}
# {{{ provision_init()
provision_init() {
	local	_hflag=0 _opt=""	\
		OPTARG="" OPTIND=0;
	SHIFT_COUNT=0;

	while getopts hl:Lny _opt; do
	case "${_opt}" in
	l)	LOG_FNAME="${OPTARG}"; ;;
	L)	LOG_FNAME=""; ;;
	n)	NFLAG=1; ;;
	y)	YFLAG=1; ;;
	h|*)	_hflag=1; break; ;;
	esac; done;
	SHIFT_COUNT=$((${OPTIND}-1)); shift $((${OPTIND}-1));

	if [ "${_hflag}" -eq 1 ]\
	|| [ "${#}" -lt 1 ];
	then
		echo "usage: ${0} [-l fname] [-L] [-n] [-y] hostname [filter[..]]" >&2;
		return 1;
	else
		HOSTNAME="${1}";
		: $((SHIFT_COUNT+=1)); shift 1;

		if [ "${LOG_FNAME:+1}" = 1 ]; then
			provision_init_log;
		fi;
		return 0;
	fi;
};
# }}}
# {{{ provision_init_log()
provision_init_log() {
	local _revision=0;

	LOG_TMP_STDERR_FNAME="$(mktemp)" || return 1;
	trap 'rm -f "${LOG_TMP_STDERR_FNAME}"' EXIT HUP INT TERM USR1 USR2;

	if [ -e "${LOG_FNAME}" ]; then
		_revision=0;
		while [ -e "${LOG_FNAME}.${_revision}" ]; do
			: $((_revision += 1));
		done;
		cp "${LOG_FNAME}" "${LOG_FNAME}.${_revision}" || return 1;
		printf "" > "${LOG_FNAME}";
	fi;

	return 0;
};
# }}}
# {{{ rc()
rc() {
	[ "${1}" = "-y" ] && { local _nflag=0 _yflag=1; shift 1; };
	local	_cmd="${1}"							\
		_nflag="${_nflag:-${NFLAG}}" _yflag="${_yflag:-${YFLAG}}"	\
		_choice="" _rc=0;
	shift 1;

	if [ "${_nflag}" -eq 1 ]; then
		if [ "${LOG_FNAME:+1}" = 1 ]; then
			printf "%s %s\n" "${_cmd}" "${*}" | tee -a "${LOG_FNAME}";
		else
			printf "%s %s\n" "${_cmd}" "${*}";
		fi;
		return 0;
	fi;

	if [ "${_yflag}" -eq 0 ]; then
		printf "Run command: %s %s? (y|N) " "${_cmd}" "${*}" >&2;
		read _choice;
	else
		_choice="y";
	fi;

	case "${_choice}" in
	[yY])	rc_exec "${_cmd}" "${@}";
		return "${?}";
		;;

	*)	return 0;
		;;
	esac;
};
# }}}
# {{{ rc_exec()
rc_exec() {
	local	_cmd="${1}"	\
		_choice="" _cmd_output="" _rc=0;
	shift 1;

	set +o errexit;
	if [ "${LOG_FNAME:+1}" = 1 ]; then
		exec 3>"${LOG_TMP_STDERR_FNAME}";
		_cmd_output="$("${_cmd}" "${@}" 2>&3)"; _rc="${?}";
		exec 3>&-;
		cat "${LOG_TMP_STDERR_FNAME}" >&2;
		cat "${LOG_TMP_STDERR_FNAME}" >> "${LOG_FNAME}";
		printf "%s" "${_cmd_output}" | tee -a "${LOG_FNAME}";
	else
		"${_cmd}" "${@}"; _rc="${?}";
	fi;
	set -o errexit;

	if [ "${_rc}" -ne 0 ]; then
		printf "Continue execution (y|N)? " >&2;
		read _choice;
		case "${_choice}" in
		[yY])	return 0; ;;
		*)	return 1; ;;
		esac;
	else
		return 0;
	fi;
};
# }}}

provision() {
	provision_init "${@}" || return 1;
	shift "${SHIFT_COUNT}";

	provision_if "/conf.local"			provision_010_conf_local "${@}";
	provision_if "Hibernation support"		provision_040_hibernate "${@}";
	provision_if "Disable Bluetooth & WLAN"		provision_070_disable_bluetooth_wlan "${@}";
	provision_if "Disable snap"			provision_075_disable_snap "${@}";
	provision_if "Users & passwords"		provision_080_users "${@}";

	provision_if "Install software"			provision_110_software_install "${@}";
	provision_if "Remove software"			provision_130_software_remove "${@}";
	provision_if "Install Tor Browser"		provision_150_software_torbrowser "${@}";
	provision_if "Install Wezterm"			provision_155_software_wezterm "${@}";
	provision_if "Configure software for user"	provision_170_software_configure "${@}";
	provision_if "Finish software"			provision_190_software_finish "${@}";

	provision_if "Services"				provision_210_services "${@}";
	provision_if "Add APT source links"		provision_250_apt_src "${@}";
	provision_if "Configure fonts: core"		provision_281_fonts_core "${@}";
	provision_if "Configure fonts: ClearType"	provision_282_fonts_cleartype "${@}";
	provision_if "Configure fonts: Tahoma"		provision_283_fonts_tahoma "${@}";
	provision_if "Configure fonts: Segoe"		provision_284_fonts_segoe "${@}";

	return 0;
};

set +o errexit -o noglob -o nounset; provision "${@}";

# vim:tw=0
