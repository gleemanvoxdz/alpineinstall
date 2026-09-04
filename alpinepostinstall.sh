#!/bin/sh
setup-user -a
rm /etc/profile.d/20locale.sh
rm /etc/environment
rm /etc/motd
rm /etc/issue ; touch /etc/issue
printf 'export CHARSET=${CHARSET:-pl_PL.UTF-8}\n' >> /etc/profile.d/20locale.sh
printf 'export LANG=${LANG:-pl_PL.UTF-8}\n' >> /etc/profile.d/20locale.sh
printf 'export LC_ALL=${LC_ALL:-pl_PL.UTF-8}\n' >> /etc/profile.d/20locale.sh
printf 'export LC_TIME=${LC_TIME:-pl_PL.UTF-8}\n' >> /etc/profile.d/20locale.sh
printf 'export LC_COLLATE=${LC_COLLATE:-C}\n' >> /etc/profile.d/20locale.sh
printf 'CHARSET=pl_PL.UTF-8\n' >> /etc/environment
printf 'LANG=pl_PL.UTF-8\n' >> /etc/environment
printf 'LC_ALL=pl_PL.UTF-8\n' >> /etc/environment
printf 'LC_TIME=pl_PL.UTF-8\n' >> /etc/environment
printf 'LC_COLLATE=C\n' >> /etc/environment
setup-devd udev
apk add dbus elogind polkit-elogind musl-locales networkmanager networkmanager-tui networkmanager-wifi \
iwd wpa_supplicant zsh zsh-autosuggestions zsh-syntax-highlighting fzf starship shadow
chsh -s /bin/zsh $(ls /home/)
rc-update add dbus
rc-update add elogind
rc-update add polkit
rc-update add networkmanager
rc-update add iwd
rc-update del networking boot
rc-update del wpa_supplicant boot
rm /etc/NetworkManager/NetworkManager.conf
printf '[main]\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'dhcp=internal\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'plugins=ifupdown,keyfile\n' >> /etc/NetworkManager/NetworkManager.conf
printf '\n' >> /etc/NetworkManager/NetworkManager.conf
printf '[ifupdown]\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'managed=true\n' >> /etc/NetworkManager/NetworkManager.conf
printf '\n' >> /etc/NetworkManager/NetworkManager.conf
printf '[device]\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'wifi.backend=iwd\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'wifi.iwd.autoconnect=yes\n' >> /etc/NetworkManager/NetworkManager.conf
printf 'Run apk add lang to switch to PL language.\n' >> /etc/motd
printf 'Also system is ready to install desktop environment.\n' >> /etc/motd
sed -i '10s/^/#/' /etc/inittab
sed -i '11s/^/#/' /etc/inittab
sed -i '12s/^/#/' /etc/inittab
sed -i '13s/^/#/' /etc/inittab
rm -rf /etc/doas.d
rm /etc/doas.conf
printf 'permit nopass :wheel\n' >> /etc/doas.conf
ln -sf /usr/bin/doas /usr/bin/sudo
clear
echo ""
echo "Done! Reboot your system."
