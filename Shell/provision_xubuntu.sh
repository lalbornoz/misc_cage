#!/bin/sh
#
# roarie's Xubuntu 23.10 (mantic) provisioning script
#

# {{{ Global variables
LOG_FNAME="provision.log";
LOG_TMP_STDERR_FNAME="";
NFLAG=0;
YFLAG=0;
# }}}
# {{{ Defaults
DEBOOTSTRAP_MIRROR="http://de.archive.ubuntu.com/ubuntu/"
HOME_DEVICE="lucia-pc-home";
HOSTNAME="";
LOCALE_GEN="en_GB.UTF-8 de_DE.UTF-8 es_CL.UTF-8 ar_MA.UTF-8";
ROOT_DEVICE="/dev/sda";
SWAP_DEVICE="lucia-pc-hibernate";
TIMEZONE="/usr/share/zoneinfo/Europe/Berlin";
USER_NORMAL="lucia";
USER_TOOR="toor";
# }}}

# {{{ provision_000_debootstrap()
provision_000_debootstrap() {
	rc debootstrap		\
		--arch amd64	\
		mantic		\
		.		\
		"${DEBOOTSTRAP_MIRROR}" || return "${?}";
	return 0;
};
# }}}
# {{{ provision_010_chroot()
provision_010_chroot() {
	local _mountpoint="";

	for _mountpoint in $(mount | awk '{print $3}'); do
		if [ "${_mountpoint}" = "${PWD}/dev" ]\
		|| [ "${_mountpoint}" = "${PWD}/proc" ]\
		|| [ "${_mountpoint}" = "${PWD}/run" ]\
		|| [ "${_mountpoint}" = "${PWD}/sys" ];
		then
			rc umount -R "${_mountpoint}" || return "${?}";
		fi;
	done;

	rc mount --make-rslave --rbind /dev "${PWD}/dev" || return "${?}";
	rc mount --make-rslave --rbind /proc "${PWD}/proc" || return "${?}";
	rc mount --make-rslave --rbind /run "${PWD}/run" || return "${?}";
	rc mount --make-rslave --rbind /sys "${PWD}/sys" || return "${?}";

	rc chroot . "${0##*/}" ---after-chroot || return "${?}";
	provision_print "" "Execution will resume within chroot.";

	return 0;
};
# }}}

# {{{ provision_110_essential_etc()
provision_110_essential_etc() {
	local	_boot_device="" _boot_efi_device=""		\
		_choice="" _device="" _fdisk_line="" _fstype=""	\
		_root_device="";
		IFS="${IFS:- }" IFS0="${IFS:- }";

	IFS="
";	for _fdisk_line in $(rc -y		 		 \
			printf "p\n"				|\
			fdisk "${ROOT_DEVICE}" 2>/dev/null	|\
			grep '^/dev'				|\
			sed 's/  \+/ /g'			|\
			cut -d" " -f1,6-);
	do
		IFS=" "; set -- ${_fdisk_line}; IFS="
";		_device="${1}"; shift; _fstype="${*}";
		case "${_fstype}" in
		"EFI System")
			_boot_efi_device="${_device}";
			;;
		"BIOS boot")
			_boot_device="${_device}";
			;;
		"Linux filesystem")
			if [ "${_boot_device:+1}" != 1 ]; then
				_boot_device="${_device}";
			else
				_root_device="${_device}";
			fi;
		esac;
	done;
	IFS="${IFS0}";

	if [ "${_boot_device:+1}" != 1 ]\
	|| [ "${_boot_efi_device:+1}" != 1 ]\
	|| [ "${_root_device:+1}" != 1 ];
	then
		provision_print "" "Error: failed to detect boot (${_boot_device}), boot EFI (${_boot_efi_device}), and/or root device (${_root_device}).";
		if [ "${_boot_device:+1}" != 1 ]; then
			printf "Enter boot device: ";
			read _boot_device;
		fi;
		if [ "${_boot_efi_device:+1}" != 1 ]; then
			printf "Enter boot EFI device: ";
			read _boot_efi_device;
		fi;
		if [ "${_root_device:+1}" != 1 ]; then
			printf "Enter root device: ";
			read _root_device;
		fi;
	fi;

	printf "Detected boot, boot EFI, and root devices:\n";
	printf "	%s\n" "${_boot_device}";
	printf "	%s\n" "${_boot_efi_device}";
	printf "	%s\n" "${_root_device}";
	printf "Is this correct? (y|N) ";
	read _choice;
	case "${_choice}" in
	[yY])	;;
	*)	return 1;
	esac;

	rc -e cat <<EOF \> /etc/fstab
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system>					<mount point>	<type>		<options>		<dump>	<pass>

${_root_device}					/		ext4		errors=remount-ro	0	1
${SWAP_DEVICE}					none		swap		sw			0	0
${_boot_device}					/boot		ext4   		defaults	 	0	2
${_boot_efi_device}				/boot/efi	vfat		umask=0077		0	1
${HOME_DEVICE}					/home		ext4		defaults		0	2}

# vim:tw=0
EOF

	rc -e printf \"%s\\\\n\" \"\${HOSTNAME}\" \> /etc/hostname || return "${?}";

	rc locale-gen "${LOCALE_GEN}" || return "${?}";
	rc dpkg-reconfigure locales || return "${?}";

	rc ln -fs "${TIMEZONE}" /etc/localtime || return "${?}";
};
# }}}
# {{{ provision_120_conf_local()
provision_120_conf_local_install() {
	local _pname="${1}" _pname_target="${2}";

	if [ -e "${_pname_target}" ]; then
		rc mv "${_pname_target}" "${_pname}.dist" || return "${?}";
	fi;
	rc ln -fs "${_pname}" "${_pname_target}" || return "${?}";
};

provision_120_conf_local() {
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
			provision_120_conf_local_install "${_pname}" "${_pname_target}";
		elif [ -e "${_pname}/.LOCAL_DIRECTORY" ]; then
			provision_120_conf_local_install "${_pname}" "${_pname_target}";
		else
			_fnames="$(rc -y find		\
				"${_pname}"		\
				-not -name \*.dist	\
				-type f			\
				)" || return "${?}";
			for _fname in ${_fnames}; do
				_fname="${_fname%/}";
				_fname_target="${_fname#/conf.local}";
				provision_120_conf_local_install "${_fname}" "${_fname_target}";
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
		provision_120_conf_local_install "${_fname}" "${_fname_target}";
	done;

	return 0;
};
# }}}
# {{{ provision_140_hibernate()
# {{{ provision_140_hibernate() variables
PROVISION_HIBERNATE_ROOT_NAME="root";
PROVISION_HIBERNATE_SWAP_NAME="swap_1";
PROVISION_HIBERNATE_VG_NAME="vgkubuntu";
# }}}
provision_140_hibernate() {
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
# {{{ provision_170_disable_bluetooth_wlan()
provision_170_disable_bluetooth_wlan() {
	if [ "${HOSTNAME#*-pc}" != "${HOSTNAME}" ]; then
		rc apt autoremove --purge bluedevil bluez bluez-obexd || return "${?}";
		rc systemctl disable bluetooth.service || return "${?}";
		rc systemctl disable wpa_supplicant.service || return "${?}";
	fi;

	return 0;
};
# }}}
# {{{ provision_175_disable_snap()
provision_175_disable_snap() {
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
# {{{ provision_180_users()
provision_180_users() {
	rc passwd root || return "${?}";
	rc sed -i"" '1{p;s/^root:/'"${USER_TOOR}"':/}' /etc/passwd /etc/shadow || return "${?}";
	rc chsh -s /usr/bin/zsh "${USER_NORMAL}" || return "${?}";
	rc chsh -s /usr/bin/zsh "${USER_TOOR}" || return "${?}";

	return 0;
};
# }}}

# {{{ provision_210_software_install()
PROVISION_SOFTWARE_INSTALL_NVIDIA_VERSION="525";

provision_210_software_install() {
	rc apt update -y || return "${?}";
	rc apt dist-upgrade -y || return "${?}";

	rc apt install -y								\
		apt-file iotop keyutils lm-sensors					\
		bsd-mailx dovecot-imapd							\
		btop htop ifstat iptables-persistent open-iscsi openssh-server tor	\
		linux-image-lowlatency							\
											\
	       	build-essential clang-15 clangd-15					\
		texinfo texlive texlive-lang-german texlive-latex-extra			\
		dos2unix fd-find fzf gcp pandoc ripgrep					\
		ffmpeg									\
		git irssi mutt ncat net-tools ngrep python3-pip rsync wget yt-dlp	\
		gnupg2 neovim tmux sqlite3 zsh						\
											\
		firefox nicotine systray-x thunderbird					\
		haruna gimp kolourpaint yuki-iptv					\
		kdevelop								\
		keepassxc meteo-qt psensor redshift redshift-gtk xfce4-timer-plugin	\
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
# {{{ provision_230_software_remove()
provision_230_software_remove() {
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
# {{{ provision_250_software_torbrowser()
provision_250_software_torbrowser() {
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
# {{{ provision_255_software_wezterm()
PROVISION_SOFTWARE_WEZTERM_URL="https://github.com/wez/wezterm/releases/download/20221119-145034-49b9839f/wezterm-20221119-145034-49b9839f.Ubuntu22.04.deb";
provision_255_software_wezterm() {
	local _rc=0;

	rc wget	\
		-O "${PROVISION_SOFTWARE_WEZTERM_URL##*/}"	\
		"${PROVISION_SOFTWARE_WEZTERM_URL}"		\
		|| return "${?}";
	rc dpkg -i "${PROVISION_SOFTWARE_WEZTERM_URL##*/}" || return "${?}";

	return 0;
};
# }}}
# {{{ provision_270_software_configure()
provision_270_software_configure() {
	rc sudo -U "${USER_NORMAL}" balooctl config set contentIndexing no || return "${?}";
	rc sudo -U "${USER_NORMAL}" balooctl disable || return "${?}";
	rc sudo -U "${USER_NORMAL}" balooctl purge || return "${?}";
	rc sudo -U "${USER_NORMAL}" kwriteconfig5 --file kwalletrc --group "Wallet" --key "Enabled" "false" || return "${?}";
	rc sudo -U "${USER_NORMAL}" kwriteconfig5 --file kwalletrc --group "Wallet" --key "First Use" "false" || return "${?}";
	rc sudo -U "${USER_NORMAL}" winetricks wmp11 || return "${?}";

	return 0;
};
# }}}
# {{{ provision_290_software_finish()
provision_290_software_finish() {
	rc apt-file update || return "${?}";
	rc rm -f /var/cache/apt/archives/*.deb || return "${?}";
	rc ln -fs /usr/bin/clangd-15 /usr/local/bin/clangd || return "${?}";

	return 0;
};
# }}}

# {{{ provision_310_services()
provision_310_services() {
	rc systemctl mask apt-news.service || return "${?}";

	rc systemctl enable ssh || return "${?}";
	rc systemctl enable iscsid || return "${?}";

	rc systemctl disable tor || return "${?}";
	rc systemctl disable plocate-updatedb.service || return "${?}";
	rc systemctl disable plocate-updatedb.timer || return "${?}";

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
# {{{ provision_350_apt_src()
provision_350_apt_src() {
	rc sed -i.dist 's/^#\s*\(deb-src\)/\1/' /etc/apt/sources.list || return "${?}";
	rc apt update || return "${?}";

	return 0;
};
# }}}
# {{{ provision_38*_fonts_*() variables
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
# {{{ provision_381_fonts_core()
provision_381_fonts_core() {
	local _rc=0 _url="" _url_fname="";

	#
	# Based on <https://www.reddit.com/r/Kubuntu/comments/r2gmjo/microsoft_fonts_on_kubuntu/>
	#

	rc apt install cabextract fontforge kubuntu-restricted-extras || return "${?}";

	return 0;
};
# }}}
# {{{ provision_382_fonts_cleartype()
provision_382_fonts_cleartype() {
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
# {{{ provision_383_fonts_tahoma()
provision_383_fonts_tahoma() {
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
# {{{ provision_384_fonts_segoe()
provision_384_fonts_segoe() {
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

# {{{ provision_exec($_pe_title, $_pe_name, $_pe_name_pri)
provision_exec() {
	local	_pe_title="${1}" _pe_name="${2}" _pe_name_pe_pri="${3}"	\
		_pe_legend="" _pe_rc=0;

	provision_print "${_pe_name_pe_pri}" "${_pe_title}";
	"${_pe_name}"; _pe_rc="${?}";

	if [ "${_pe_rc}" -ne 0 ]; then
		provision_exec_fail			\
			"${_pe_title}" "${_pe_name}"	\
			"${_pe_name_pe_pri}" "${_pe_rc}";
	fi;

	return "${_pe_rc}";
};
# }}}
# {{{ provision_exec_fail($_pef_title, $_pef_name, $_pef_name_pri, $_pef_rc)
provision_exec_fail() {
	local	_pef_title="${1}" _pef_name="${2}"	\
		_pef_name_pef_pri="${3}" _pef_rc="${4}"	\
		_pef_legend="";

	_pef_legend="$(printf						\
		"[35m>>> [1m%s[22m [91mError in [4m%s[0m"	\
		"${_pef_name_pef_pri}" "${_pef_title}")";
	if [ "${LOG_FNAME:+1}" = 1 ]; then
		printf "%s\n" "${_pef_legend}" | tee -a "${LOG_FNAME}";
	else
		printf "%s\n" "${_pef_legend}";
	fi;

	if [ "${YFLAG}" -eq 0 ]; then
		printf "[35m>>> [97mContinue execution (y|N)? [0m";
		read _pef_choice;
	else
		_pef_choice="y";
	fi;

	case "${_pef_choice}" in
	[yY])	return 0; ;;
	*)	exit "${_pef_rc}"; ;;
	esac;
};
# }}}
# {{{ provision_exit()
provision_exit() {
	local _pe2_mountpoint="";

	for _pe2_mountpoint in $(mount | awk '{print $3}'); do
		if [ "${_pe2_mountpoint}" = "${PWD}/dev" ]\
		|| [ "${_pe2_mountpoint}" = "${PWD}/proc" ]\
		|| [ "${_pe2_mountpoint}" = "${PWD}/run" ]\
		|| [ "${_pe2_mountpoint}" = "${PWD}/sys" ];
		then
			rc umount -R "${_pe2_mountpoint}";
		fi;
	done;
};
# }}}
# {{{ provision_if($_pi_title, $_pi_name)
provision_if() {
	local	_pi_title="${1}" _pi_name="${2}"	\
		_pi_execfl=0 _pi_filter_cmdline=""	\
		_pi_name_base="" _pi_name_pri="";
	shift 2;

	_pi_name_base="${_pi_name#provision_*_}";
	_pi_name_pri="${_pi_name#provision_}";
	_pi_name_pri="${_pi_name_pri%%_*}";

	if [ "${#}" -eq 0 ]; then
		_pi_execfl=1;
	else
		for _pi_filter_cmdline in "${@}"; do
			if [ "${_pi_name_base#${_pi_filter_cmdline}}" != "${_pi_name_base}" ]; then
				_pi_execfl=1; break;
			fi;
		done;
	fi;

	if [ "${_pi_execfl}" = 1 ]; then
		provision_exec "${_pi_title}" "${_pi_name}" "${_pi_name_pri}";
		return "${?}";
	else
		return 0;
	fi;
};
# }}}
# {{{ provision_init($_pi2_rafter_chroot_flag)
provision_init() {
	local	_pi2_rafter_chroot_flag="${1#\$}"	\
		_pi2_rshift_count="${2#\$}"		\
		_pi2_hflag=0 _pi2_opt=""		\
		_pi2_shift_count=0;
		OPTARG="" OPTIND=0;
	shift 2;

	while [ "${#}" -gt 0 ]; do
		case "${1}" in
		---after-chroot)
			eval ${_pi2_rafter_chroot_flag}=1;
			: $((_pi2_shift_count+=1)); shift 1;
			;;

		*)	OPTIND=0;
			if getopts chl:Lny _pi2_opt; then
				case "${_pi2_opt}" in
				c)	NFLAG=2; ;;
				h)	_pi2_hflag=1; break; ;;
				l)	LOG_FNAME="${OPTARG}"; ;;
				L)	LOG_FNAME=""; ;;
				n)	NFLAG=1; ;;
				y)	YFLAG=1; ;;
				*)	_pi2_hflag=1; break; ;;
				esac;
			else
				break;
			fi;
			if [ "${OPTIND}" -gt 0 ]; then
				_pi2_shift_count=$((${_pi2_shift_count}+(${OPTIND}-1)));
				shift $((${OPTIND}-1));
			fi;
		esac;
	done;

	if [ "${_pi2_hflag}" -eq 1 ]\
	|| [ "${#}" -lt 1 ];
	then
		usage;
		return 1;
	else
		HOSTNAME="${1}";
		: $((_pi2_shift_count+=1)); shift 1;
		eval ${_pi2_rshift_count}=\${_pi2_shift_count};

		if [ "${LOG_FNAME:+1}" = 1 ]; then
			provision_init_log;
		fi;
		return 0;
	fi;
};
# }}}
# {{{ provision_init_log()
provision_init_log() {
	local _pil_revision=0;

	LOG_TMP_STDERR_FNAME="$(mktemp)" || return 1;
	trap 'rm -f "${LOG_TMP_STDERR_FNAME}"' EXIT HUP INT TERM USR1 USR2;

	if [ -e "${LOG_FNAME}" ]; then
		_pil_revision=0;
		while [ -e "${LOG_FNAME}.${_pil_revision}" ]; do
			: $((_pil_revision += 1));
		done;
		cp "${LOG_FNAME}" "${LOG_FNAME}.${_pil_revision}" || return 1;
		printf "" > "${LOG_FNAME}";
	fi;

	return 0;
};
# }}}
# {{{ provision_print($_pp_name, $_pp_title)
provision_print() {
	local	_pp_name="${1}" _pp_title="${2}"	\
		_pp_buf="";

	_pp_buf="$(printf					\
		"[35m>>> [1m%s[4m[36m%s[0m"	\
		"${_pp_name:+${_pp_name}[22m }" "${_pp_title}")";
	if [ "${LOG_FNAME:+1}" = 1 ]; then
		printf "%s\n" "${_pp_buf}" | tee -a "${LOG_FNAME}";
	else
		printf "%s\n" "${_pp_buf}";
	fi;
};
# }}}

# {{{ rc([-y], [-e], $_rc_cmd[, ...])
rc() {
	if [ "${1#-y}" != "${1}" ]; then local _rc_yflag=1; shift; else local _rc_yflag=0; fi;
	if [ "${1#-e}" != "${1}" ]; then local _rc_eflag=1; shift; else local _rc_eflag=0; fi;
	local	_rc_cmd="${1}"	\
		_rc_choice=0 _rc_nflag="${NFLAG}";
	shift 1;

	if [ "${_rc_yflag}" -eq 1 ]; then
		_rc_nflag=0;
	fi;

	case "${_rc_nflag}" in
	2)	if [ "${LOG_FNAME:+1}" = 1 ]; then
			eval	printf							 	 \
				\""[1m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\"	|\
				tee -a "${LOG_FNAME}";
		else
			eval	printf							 	 \
				\""[1m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\";
		fi;
		printf "Run the above command? (y|N) ";
		read _rc_choice;
		;;

	1)	if [ "${LOG_FNAME:+1}" = 1 ]; then
			eval	printf								 \
				\""[90m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\"	|\
				tee -a "${LOG_FNAME}";
		else
			eval	printf	\
				\""[90m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\";
		fi;
		_rc_choice="n";
		;;

	0)	if [ "${LOG_FNAME:+1}" = 1 ]\
		&& [ "${_rc_yflag}" -eq 0 ]; then
			eval	printf							 	 \
				\""[4m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\"	|\
				tee -a "${LOG_FNAME}";
		elif [ "${LOG_FNAME:+1}" = 1 ]\
		&&   [ "${_rc_yflag}" -eq 1 ]; then
			eval	printf							 	 \
				\""[4m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\" >> "${LOG_FNAME}";
		elif [ "${_rc_yflag}" -eq 0 ]; then
			eval	printf							 	 \
				\""[4m%s%s[0m\n"\" \"\${_rc_cmd}\" \""\${*:+ \${*}}"\";
		fi;
		_rc_choice="y";
		;;

	*)	return 1;
		;;
	esac;

	case "${_rc_choice}" in
	[yY])	rc_exec							\
			"${_rc_cmd}" "${_rc_eflag}"			\
			"${LOG_FNAME}" "${LOG_TMP_STDERR_FNAME}"	\
			"${@}";
		;;
	*)	;;
	esac;
};
# }}}
# {{{ rc_exec($_rce_cmd, $_rce_eflag, $_rce_log_fname, $_rce_log_tmp_stderr_fname)
rc_exec() {
	local	_rce_cmd="${1}" _rce_eflag="${2}"			\
		_rce_log_fname="${3}" _rce_log_tmp_stderr_fname="${4}"	\
		_rce_choice=0 _rce_cmd_output="" _rce_rc=0;
	shift 4;

	case "${_rce_eflag}" in
	0)	if [ "${_rce_log_fname:+1}" = 1 ]; then
			set +o errexit;
			exec 3>"${_rce_log_tmp_stderr_fname}";
			_rce_cmd_output="$("${_rce_cmd}" "${@}" 2>&3)";
			_rce_rc="${?}";
			exec 3>&-;
			cat "${_rce_log_tmp_stderr_fname}" >&2;
			cat "${_rce_log_tmp_stderr_fname}" >> "${_rce_log_fname}";
			printf "%s" "${_rce_cmd_output}" | tee -a "${_rce_log_fname}";
			set -o errexit;
		else
			"${_cmd}" "${@}"; _rce_rc="${?}";
		fi;
		;;

	1)	if [ "${_rce_log_fname:+1}" = 1 ]; then
			set +o errexit;
			exec 3>"${_rce_log_tmp_stderr_fname}";
			_rce_cmd_output="$(eval "${_rce_cmd}${*:+ ${*}}" 2>&1 | tee -a "${_rce_log_fname}" 2>&3)";
			_rce_rc="${?}";
			exec 3>&-;
			cat "${_rce_log_tmp_stderr_fname}" >&2;
			cat "${_rce_log_tmp_stderr_fname}" >> "${_rce_log_fname}";
			printf "%s" "${_rce_cmd_output}" | tee -a "${_rce_log_fname}";
			set -o errexit;
		fi;
		;;
	esac;

	if [ "${_rce_rc}" -ne 0 ]; then
		if [ "${YFLAG}" -eq 0 ]; then
			printf "Continue execution (y|N)? " >&2;
			read _rce_choice;
		else
			_rce_choice="y";
		fi;

		case "${_rce_choice}" in
		[yY])	return 0; ;;
		*)	return 1; ;;
		esac;
	else
		return 0;
	fi;
};
# }}}

# {{{ usage()
usage() {
	printf "usage: %s [-c] [-l fname] [-L] [-n] [-y] hostname [filter[..]]\n" "${0##*/}" >&2;
	printf "       -c........: confirm before running each command\n" >&2;
	printf "       -l fname..: set log filename\n" >&2;
	printf "       -L........: do not create log file\n" >&2;
	printf "       -n........: dry run\n" >&2;
	printf "       -y........: always continue execution on error\n" >&2;
	printf "       WARNING: Use with caution, may cause mayhem.\n" >&2;
};
# }}}


provision() {
	local _p_after_chroot_flag=0 _p_shift_count=0;
	provision_init \$_p_after_chroot_flag \$_p_shift_count "${@}" || return 1;
	shift "${_p_shift_count}";
	trap provision_exit ALRM HUP EXIT INT QUIT TERM USR1 USR2;

	if [ "${_p_after_chroot_flag}" -eq 0 ]; then
		provision_if "Debootstrap"		provision_000_debootstrap "${@}";
		provision_if "Mount and chroot"		provision_010_chroot "${@}";

		return 0;
	fi;

	provision_if "Essential /etc files"		provision_110_essential_etc "${@}";
	provision_if "Install /conf.local"		provision_120_conf_local "${@}";
	provision_if "Hibernation support"		provision_140_hibernate "${@}";
	provision_if "Disable Bluetooth & WLAN"		provision_170_disable_bluetooth_wlan "${@}";
	provision_if "Disable snap"			provision_175_disable_snap "${@}";
	provision_if "Users & passwords"		provision_180_users "${@}";

	provision_if "Install software"			provision_210_software_install "${@}";
	provision_if "Remove software"			provision_230_software_remove "${@}";
	provision_if "Install Tor Browser"		provision_250_software_torbrowser "${@}";
	provision_if "Install Wezterm"			provision_255_software_wezterm "${@}";
	provision_if "Configure software for user"	provision_270_software_configure "${@}";
	provision_if "Finish software"			provision_290_software_finish "${@}";

	provision_if "Services"				provision_310_services "${@}";
	provision_if "Add APT source links"		provision_350_apt_src "${@}";
	provision_if "Configure fonts: core"		provision_381_fonts_core "${@}";
	provision_if "Configure fonts: ClearType"	provision_382_fonts_cleartype "${@}";
	provision_if "Configure fonts: Tahoma"		provision_383_fonts_tahoma "${@}";
	provision_if "Configure fonts: Segoe"		provision_384_fonts_segoe "${@}";

	return 0;
};

set +o errexit -o noglob -o nounset;
LC_ALL=C provision "${@}";

# vim:tw=0
