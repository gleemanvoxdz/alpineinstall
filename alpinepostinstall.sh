#!/bin/sh

clear

# 0. Ustalenie nazwy użytkownika i nadawanie mu uprawnień (jeśli użytkownik non-root nie istnieje, tworzy nowego)
USERNAME=$(ls /home | head -n 1)
if [ -z "$USERNAME" ]; then
        echo ""
        echo "Non-root user not found. You need one for desktop usage."
        echo ""
    setup-user
fi

for u in $(ls /home); do for g in wheel disk lp input audio cdrom dialout video netdev games users; do addgroup $u $g; done;done

# 1. Konfiguracja Locale
cat << 'EOF' > /etc/profile.d/20locale.sh
export CHARSET=${CHARSET:-pl_PL.UTF-8}
export LANG=${LANG:-pl_PL.UTF-8}
export LC_ALL=${LC_ALL:-pl_PL.UTF-8}
export LC_TIME=${LC_TIME:-pl_PL.UTF-8}
export LC_COLLATE=${LC_COLLATE:-C}
EOF

cat << 'EOF' > /etc/environment
CHARSET=pl_PL.UTF-8
LANG=pl_PL.UTF-8
LC_ALL=pl_PL.UTF-8
LC_TIME=pl_PL.UTF-8
LC_COLLATE=C
EOF

# 2. Wiadomość powitalna MOTD
cat << 'EOF' > /etc/motd
Run apk add lang to switch to PL language.
Also system is ready to install desktop environment.
EOF

# 3. Instalacja pakietów
setup-devd udev
apk add cpupower dbus doas elogind polkit-elogind musl-locales networkmanager networkmanager-tui networkmanager-wifi \
iwd wpa_supplicant zsh zsh-autosuggestions zsh-syntax-highlighting fzf starship shadow

# 4. Zmiana domyślnego shella na zsh
chsh -s /bin/zsh $(ls /home/)

# 5. Konfiguracja usług OpenRC
rc-update add cpupower default
rc-update add dbus default
rc-update add elogind default
rc-update add polkit default
rc-update add networkmanager default
rc-update add iwd boot

rc-update del networking boot 2>/dev/null || true
rc-update del wpa_supplicant boot 2>/dev/null || true

# 6. Konfiguracja procesora (Governor)
rm -f /etc/cpupower-service.conf
printf "GOVERNOR='schedutil'\n" >> /etc/cpupower-service.conf

# 7. Konfiguracja NetworkManager (z backendem iwd)
cat << 'EOF' > /etc/NetworkManager/NetworkManager.conf
[main]
dhcp=internal
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# 8. Edycja inittab
sed -i '10s/^/#/' /etc/inittab
sed -i '11s/^/#/' /etc/inittab
sed -i '12s/^/#/' /etc/inittab
sed -i '13s/^/#/' /etc/inittab

# 9. Konfiguracja doas oraz sudo
rm -rf /etc/doas.d
rm -f /etc/doas.conf
printf 'permit nopass :wheel\n' >> /etc/doas.conf
ln -sf /usr/bin/doas /usr/bin/sudo

clear
echo ""
echo "Done! Reboot your system."
