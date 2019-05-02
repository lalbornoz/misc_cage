# Must be invoked w/ -ExecutionPolicy Bypass. Requires Powershell 5.0+.

# {{{ Script entry point & global variables
param([int]$debug=0, [int]$log=0)
if ($debug -eq 1) {Set-PSDebug -Trace 2}
if ($log -eq 1) {Start-Transcript "provision.log"}
New-PSDrive HKU Registry HKEY_USERS

$AdministratorPassword = (Read-Host -AsSecureString "Enter new password for Administrator")
$CygwinPath = "C:\tools\cygwin"
$PackagesChocolatey = "7zip.install audacity audacity-lame bleachbit classic-shell Cygwin dejavufonts electrum firefox f.lux foobar2000 foxitreader hashcheck keepass.install mpc-hc mumble processhacker putty.install rufus speedfan sysinternals thunderbird tor-browser vim vscode wireshark"
$PackagesCygwin = "bind-utils,curl,diffutils,dos2unix,gcc,git,gnupg2,less,lftp,make,man-db,mingw64-x86_64-gcc-core,mingw64-x86_64-gcc-g++,nc,openssh,openssl,PDFCreator,perl-URI,procps-ng,python2,python3,rsync,ssh-pageant,tmux,zsh,vim,wget,whois"
$StepLimit = 14;
$UserName = "lucio"
$UserSID = (Get-WmiObject win32_useraccount | Where-Object -EQ -Property "name" -Value $UserName).SID
$UserProfile = "C:\Users\$UserName"
# }}}
# {{{ Private functions
function bytesToLong {
	([long]$args[0][3] -shl 24) -bor ([long]$args[0][2] -shl 16) -bor ([long]$args[0][1] -shl 8) -bor [long]$args[0][0]
}

$StepCur = 0;
function progress {
	Write-Progress -Activity "Provisioning" -Id 0 -PercentComplete ($global:StepCur / $StepLimit * 100) -Status ("Step " + ($global:StepCur + 1) + " of $StepLimit | " + $args[0])
	$args[1].Invoke(); $global:StepCur++;
}
# }}}

# {{{ Install PolicyFileEditor module and dependency
progress "Install PolicyFileEditor module and dependency" {
	Install-PackageProvider -Force -Name NuGet -MinimumVersion 2.8.5.201
	Install-Module -Force -Name PolicyFileEditor -RequiredVersion 3.0.0
	Import-Module PolicyFileEditor
}
# }}}

# {{{ Add {Arabic (Jordan),German (Germany),English (UK),Spanish (Chile)} keyboard layouts & hot keys
progress "Add {Arabic (Jordan),German (Germany),English (UK),Spanish (Chile)} keyboard layouts & hot keys" {
	$LanguageList = Get-WinUserLanguageList
	"ar-JO", "de-DE", "en-GB", "es-CL" | ForEach {$LanguageList.Add($_)}
	Set-WinUserLanguageList -Force $LanguageList
	Get-ItemProperty -Path "HKU:$UserSID\Control Panel\Input Method\Hot Keys\*" | ForEach {
		switch (bytesToLong $_."Target IME") {
		0x04520809 {
			Set-ItemProperty -Name "Key Modifiers" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x0000c005
			Set-ItemProperty -Name "Virtual Key" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x00000030
		}
		0x0a340a08 {
			Set-ItemProperty -Name "Key Modifiers" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x0000c005
			Set-ItemProperty -Name "Virtual Key" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x00000031
		}
		0x012c0104 {
			Set-ItemProperty -Name "Key Modifiers" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x0000c005
			Set-ItemProperty -Name "Virtual Key" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x00000032
		}
		0x07040704 {
			Set-ItemProperty -Name "Key Modifiers" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x0000c005
			Set-ItemProperty -Name "Virtual Key" -Path ("HKU:$UserSID\Control Panel\Input Method\Hot Keys\" + $_.PSChildName) -Value 0x00000033
		}}
	}
	Set-ItemProperty -Name "Hotkey" -Path "HKU:$UserSID\Keyboard Layout\Toggle" -Value 3
	Set-ItemProperty -Name "Language Hotkey" -Path "HKU:$UserSID\Keyboard Layout\Toggle" -Value 3
	Set-ItemProperty -Name "Layout Hotkey" -Path "HKU:$UserSID\Keyboard Layout\Toggle" -Value 3
}
# }}}
# {{{ Allow creation of symbolic links
progress "Allow creation of symbolic links" {
	Add-LocalGroupMember -Group "Users" -Member "lucio"
	Remove-LocalGroupMember -Group "Administrators" -Member "lucio"
	Remove-LocalGroupMember -Group "HomeUsers" -Member "lucio"
	Enable-LocalUser -Name "Administrator"
	Set-LocalUser -Name "Administrator" -Password $AdministratorPassword
	Rename-LocalUser "Administrator" "root"
	secedit /export /cfg "secpol.cfg"
	 (gc secpol.cfg).replace('SeCreateSymbolicLinkPrivilege = ', 'SeCreateSymbolicLinkPrivilege = lucio, ') | Out-File "secpol.cfg"
	 secedit /configure /db "$env:windir\security\local.sdb" /cfg "secpol.cfg"
	Remove-Item "secpol.cfg"
	#New-ItemProperty -Name "CYGWIN" -Path "HKU:$UserSID\Environment" -Type String -Value "winsymlinks:native"
}
# }}}
# {{{ Configure accessibility, case sensitivity, Explorer, taskbar & VSS registry settings
progress "Configure accessibility, Explorer, taskbar & VSS registry settings" {
	$settings = (Get-ItemProperty -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2").Settings
	$settings[8] = 0x03
	New-ItemProperty -Force -Name "Hidden" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Type DWord -Value 1
	New-ItemProperty -Force -Name "HideFileExt" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Type DWord -Value 0
	Set-ItemProperty -Name "obcaseinsensitive" -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel" -Value 0
	New-ItemProperty -Force -Name "On" -Path "HKU:$UserSID\Control Panel\Accessibility\Keyboard Preference" -Type String -Value "1"
	Set-ItemProperty -Name "Settings" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects2" -Value $settings
	New-ItemProperty -Force -Name "ShowSuperHidden" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Type DWord -Value 1
	Set-ItemProperty -Name "TaskbarSmallIcons" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Value 1
	Set-ItemProperty -Name "TaskbarGlomLevel" -Path "HKU:$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Value 2
	New-ItemProperty -Force -Name "SystemRestorePointCreationFrequency" -Path "HKLM:Software\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Type DWord -Value 0
	Stop-Process -Force -ProcessName explorer
}
# }}}
# {{{ Configure Autoplay, BitLocker, recycle bin, Remote Assistance, screensaver & taskbar local group policies
progress "Configure Autoplay, BitLocker, recycle bin, Remote Assistance, screensaver & taskbar local group policies" {
	Set-PolicyFileEntry -Data 255 -Key "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "NoDriveTypeAutoRun"
	Set-PolicyFileEntry -Data "" -Key "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type String -ValueName "**del.LockTaskbar"
	Set-PolicyFileEntry -Data 1 -Key "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type DWord -ValueName "ConfirmFileDelete"
	Set-PolicyFileEntry -Data 1 -Key "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type DWord -ValueName "HideSCAHealth"
	Set-PolicyFileEntry -Data 1 -Key "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type DWord -ValueName "NoRecycleFiles"
	Set-PolicyFileEntry -Data "" -Key "Software\Microsoft\Windows NT\Terminal Services" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type String -ValueName "**del.fAllowUnsolicitedFullControl"
	Set-PolicyFileEntry -Data 0 -Key "Software\Microsoft\Windows NT\Terminal Services" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "fAllowUnsolicited"
	Set-PolicyFileEntry -Data "" -Key "Software\Microsoft\Windows NT\Terminal Services\RAUnsolicit" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type String -ValueName "**delvals."
	Set-PolicyFileEntry -Data 1 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "EnableBDEWithNoTPM"
	Set-PolicyFileEntry -Data 1 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "UseAdvancedStartup"
	Set-PolicyFileEntry -Data 2 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "UseTPM"
	Set-PolicyFileEntry -Data 2 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "UseTPMKey"
	Set-PolicyFileEntry -Data 2 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "UseTPMKeyPIN"
	Set-PolicyFileEntry -Data 2 -Key "Software\Policies\Microsoft\FVE" -Path "$env:windir\System32\GroupPolicy\Machine\Registry.pol" -Type DWord -ValueName "UseTPMPIN"
	Set-PolicyFileEntry -Data "1" -Key "Software\Policies\Microsoft\Windows\Control Panel\Desktop" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type String -ValueName "ScreenSaveActive"
	Set-PolicyFileEntry -Data "600" -Key "Software\Policies\Microsoft\Windows\Control Panel\Desktop" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type String -ValueName "ScreenSaveTimeOut"
	Set-PolicyFileEntry -Data "1" -Key "Software\Policies\Microsoft\Windows\Control Panel\Desktop" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type String -ValueName "ScreenSaverIsSecure"
	Set-PolicyFileEntry -Data "scrnsave.scr" -Key "Software\Policies\Microsoft\Windows\Control Panel\Desktop" -Path "$env:windir\System32\GroupPolicy\User\Registry.pol" -Type String -ValueName "SCRNSAVE.EXE"
	Stop-Process -Force -ProcessName explorer
}
# }}}
# {{{ Configure Windows Update
progress "Configure Windows Update" {
	$AUSettings = (New-Object -com "Microsoft.Update.AutoUpdate").Settings
	$AUSettings.NotificationLevel = 1
	$AUSettings.Save
}
# }}}
# {{{ Disable AUSessionConnect task, C:\Users share, {Device Association Service,Windows {Media Player Network Sharing,Search}} services & Windows Defender real-time protection
progress "Disable AUSessionConnect task, C:\Users share, {Device Association Service,Windows {Media Player Network Sharing,Search}} services & Windows Defender real-time protection" {
	Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\AUSessionConnect"
	Remove-SmbShare -Force -Name "Users"
	"DeviceAssociationService", "HomeGroupListener", "HomeGroupProvider", "WMPNetworkSvc", "WSearch" | ForEach {
		Set-Service $_ -StartupType Disabled; Stop-Service $_;
	}
	Set-MpPreference -DisableRealtimeMonitoring $true
}
# }}}
# {{{ Force 8.8.{4.4,8.8} DNS servers
progress "Force 8.8.{4.4,8.8} DNS servers" {
	Get-NetAdapter | Where-Object -EQ -Property Status -Value "Up" | ForEach {Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses 8.8.8.8,8.8.4.4}
}
# }}}
# {{{ Prevent installed devices from waking up PC
progress "Prevent installed devices from waking up PC" {
	powercfg /DEVICEQUERY "wake_armed" | Where-Object {$_ -ne "NONE"} | ForEach {powercfg /DEVICEDISABLEWAKE "$_"}
}
# }}}
# {{{ Register scheduled task to automatically create daily restore point & set unbounded maximum shadow copy storage space limit on all local volumes
progress "Register scheduled task to automatically create daily restore point & set unbounded maximum shadow copy storage space limit on all local volumes" {
	$action = New-ScheduledTaskAction -Argument "-ExecutionPolicy Bypass -Command `"Checkpoint-Computer -Description \`"Daily restore point\`" -RestorePointType \`"MODIFY_SETTINGS\`"`"" -Execute "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
	$principal = New-ScheduledTaskPrincipal -LogonType ServiceAccount -RunLevel Highest -UserID "NT AUTHORITY\SYSTEM"
	$trigger = New-ScheduledTaskTrigger -At 8pm -Daily
	Register-ScheduledTask -Action $action -Description "Create daily restore point" -Principal $principal -TaskName "Create daily restore point" -Trigger $trigger
	Get-Volume | Where-Object -NE -Property "DriveLetter" -Value (0x00 -as [char]) |
		ForEach {$dl = ($_.DriveLetter + ":"); vssadmin Resize ShadowStorage /For=$dl /On=$dl /MaxSize=UNBOUNDED}
}
# }}}
# {{{ Install Chocolatey and Windows packages w/ Chocolatey
progress "Install Chocolatey and Windows packages w/ Chocolatey" {
	Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://chocolatey.org/install.ps1"))
	do {
		& "$env:ALLUSERSPROFILE\chocolatey\bin\choco" install -y $PackagesChocolatey
	} while ($LastExitCode -ne 0)
}
# }}}
# {{{ Install Cygwin packages, disable SSH non-pubkey authentication OOTB, enforce posix=1 for /cygdrive in Cygwin and correct {$PATH,%Path%} & hide Cygwin SSH user in UAC prompt
progress "Install Cygwin packages, disable SSH non-pubkey authentication OOTB, enforce posix=1 for /cygdrive in Cygwin and correct %Path% & hide Cygwin SSH user in UAC prompt" {
	& "$CygwinPath\cygwinsetup" -nqWP $PackagesCygwin
	& "$CygwinPath\bin\sed" '-i.dist' -e 's/^#\?\(Hostbased\|Password\|ChallengeResponse\|Kerberos\|GSSAPI\)Authentication\s\+\(yes\|no\)\s*$/\1Authentication no/' -e 's/^#\?PubkeyAuthentication\s\+\(yes\|no\)\s*$/PubkeyAuthentication yes/' /etc/defaults/etc/sshd_config
	& "$CygwinPath\bin\sed" '-i.dist' -e 's/posix=0/posix=1/' /etc/fstab
	& "$CygwinPath\bin\sed" '-i.dist' -e 's,^\(\s*PATH="\)\(.\+\),\1/bin:\2,p' /etc/profile /etc/zprofile
	$Path = (Get-ItemProperty -Name "Path" -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path
	$Path.Replace("\Windows\system32", "\Windows\System32")
	Set-ItemProperty -Name "Path" -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Value $Path
	New-ItemProperty -Force -Name "cyg_server" -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" -Type DWord -Value 0
}
# }}}
# {{{ Place {foobar2000,Pageant,Thunderbird} into Startup group & setup SpeedFan autostart scheduled task
progress "Place {foobar2000,Pageant,Thunderbird} into Startup group & setup SpeedFan autostart scheduled task" {
	Copy-Item -Destination "$UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\foobar2000.lnk"
	Copy-Item -Destination "$UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\PuTTY (64-bit)\Pageant.lnk"
	Copy-Item -Destination "$UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Mozilla Thunderbird.lnk"

	$action = New-ScheduledTaskAction -Argument "-NoProfile -Command `"Start-Process 'C:\Program Files (x86)\SpeedFan\speedfan.exe' -Credential (New-Object System.Management.Automation.PSCredential root, " + (ConvertFrom-SecureString $AdministratorPassword) + ")`"" -Execute "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
	$principal = New-ScheduledTaskPrincipal -RunLevel Highest -UserID $UserName
	$trigger = New-ScheduledTaskTrigger -AtLogOn
	Register-ScheduledTask -Action $action -Description "SpeedFan" -Principal $principal -TaskName "SpeedFan" -Trigger $trigger
}
# }}}
# {{{ Set Documents folder location to $CygwinPath\home\$UserName
progress "Set Documents folder location to $CygwinPath\home\$UserName" {
	if (!(Test-Path -Path "$CygwinPath\home\$UserName")) {
		New-Item -ItemType Directory -Path "$CygwinPath\home\$UserName"
		$Acl = Get-Acl -Path "$CygwinPath\home\$UserName"
		$Acl.SetOwner((New-Object -ArgumentList "$UserName" -TypeName System.Security.Principal.NTAccount))
		Set-Acl -AclObject $Acl -Path "$CygwinPath\home\$UserName"
	}
	Set-ItemProperty -Name "Personal" -Path "HKU:$UserSID\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Value "$CygwinPath\home\$UserName"
	Stop-Process -Force -ProcessName explorer
}
# }}}

# {{{ Restart computer
switch -Regex (Read-Host "Reboot (Y|n)") {
'^y?$' {Restart-Computer}
}
# }}}

# vim:ff=dos ft=sh tw=0
