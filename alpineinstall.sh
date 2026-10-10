#!/bin/sh

# Info
clear
echo "About:"
echo "---------------------------"
echo "Welcome to my little alpineinstall script."
echo "This script will set the repositories to rolling release,"
echo "allow you to choose the kernel, microcode, filesystem,"
echo "set the memory allocator to mimalloc3 and enable ZRAM."
echo "Additionally, it will enable secure boot by default"
echo "(if secure boot is in setup-mode) and"
echo "create a signed UKI image."
echo ""
echo "Do you want to proceed?"
echo ""
echo "1. Proceed (default)"
echo ""
echo "2. Exit without any changes"
echo "---------------------------"

while true; do
    printf "Choice [1-2]: "
    if ! read -r begin; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
    begin=${begin:-1}
    case "$begin" in
        1) break ;;
        2) exit ;;
        *) echo "Error: Incorrect choice. Enter 1 or 2." ;;
    esac
done

# Add repos and basic tools
clear
rm -f /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/main\n' >> /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/community\n' >> /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/testing\n' >> /etc/apk/repositories
apk add dosfstools efibootmgr kernel-hooks lsblk mimalloc3 sbctl systemd-efistub ukify util-linux zram-init

# Choose CPU
clear
echo "Select your CPU:"
echo "---------------------------"
echo "1. Intel (default)"
echo ""
echo "2. AMD"
echo "---------------------------"

while true; do
    printf "Choice [1-2]: "
    if ! read -r microcode; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
    microcode=${microcode:-1}
    case "$microcode" in
        1) cpu=intel; break ;;
        2) cpu=amd; break ;;
        *) echo "Error: '$microcode' is incorrect. Enter 1 or 2." ;;
    esac
done

# Choose kernel
clear
echo "Select kernel:"
echo "---------------------------"
echo "1. Stable $(apk list -v | grep -E '^linux-stable-[0-9]' | awk -F'-' '{print $3}') (default)"
echo ""
echo "2. LTS $(apk list -v | grep -E '^linux-lts-[0-9]' | awk -F'-' '{print $3}')"
echo ""
echo "3. Virt $(apk list -v | grep -E '^linux-virt-[0-9]' | awk -F'-' '{print $3}')"
echo "---------------------------"

while true; do
    printf "Choice [1-3]: "
    if ! read -r kernel_variant; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
    kernel_variant=${kernel_variant:-1}
    case "$kernel_variant" in
        1) kernel=stable; break ;;
        2) kernel=lts; break ;;
        3) kernel=virt; break ;;
        *) echo "Error: '$kernel_variant' is incorrect. Enter 1, 2 or 3." ;;
    esac
done

# Choose filesystem
clear
echo "Select filesystem:"
echo "---------------------------"
echo "1. EXT4 (default)"
echo ""
echo "2. BTRFS (desktop)"
echo ""
echo "3. XFS (overkill)"
echo ""
echo "4. F2FS (experimental)"
echo ""
echo "5. Info"
echo "---------------------------"

while true; do
    printf "Choice [1-5]: "
    if ! read -r fs_choice; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
    fs_choice=${fs_choice:-1}
    case "$fs_choice" in
        1) filesystem=ext4; break ;;
        2) filesystem=btrfs; break ;;
        3) filesystem=xfs; break ;;
        4) filesystem=f2fs; break ;;
        5) clear 
        echo "Select filesystem:"
        echo "---------------------------"
        echo "1. EXT4  -> Good ol' EXT4. It might lack modern features like compression or snapshots,"
        echo "            but trust me - that bulletproof MF has saved my server ass more than once."
        echo ""
        echo "2. BTRFS -> Nice pick for a laptop/desktop. It supports compression, snapshots, etc."
        echo "            It can also be easily mounted in Windows (WinBtrfs)."
        echo ""
        echo "3. XFS   -> Mostly enterprise FS. Overkill for home usage IMO."
        echo "            Heck, may even be underperformant with many small files."
        echo ""
        echo "4. F2FS  -> Designed with flash memory in mind. I used it back when I was running Arch,"
        echo "            but for some reason, it’s unstable for me on Alpine."
        echo ""
        echo "5. Info"
        echo "---------------------------"; ;;
        *) echo "Error: Incorrect choice. Enter 1, 2, 3, 4 or 5." ;;
    esac
done

# Select the disk on which you want to install the system
clear
echo "Available disks:"
echo "---------------------------"

i=1
for disk in $(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print $1}'); do
    size=$(lsblk -d -n -o SIZE "/dev/$disk" 2>/dev/null)
    echo "$i. /dev/$disk ($size)"
    eval "install_disk_$i=/dev/$disk"
    i=$((i + 1))
done

disk_number=$((i - 1))

if [ "$disk_number" -eq 0 ]; then
    echo "No disks found."
    exit 1
fi

echo "---------------------------"
selected_disk=""

while true; do
    printf "Select install disk [1-%d]: " "$disk_number"
    if ! read -r disk_choice; then
        echo "\nExiting..."
        exit 1
    fi

    if [ "$disk_choice" -ge 1 ] 2>/dev/null && [ "$disk_choice" -le "$disk_number" ] 2>/dev/null; then
        eval "selected_disk=\$install_disk_$disk_choice"
        break
    else
        echo "Incorrect choice. Select from 1 to $disk_number."
    fi
done

# Choose boot partition size
clear
boot_size=""

echo "Set boot partition size:"
echo "---------------------------"
echo "1. 256M (default)"
echo ""
echo "2. 512M (Isn't that a bit too much?)"
echo ""
echo "3. 1024M (Are you storing porn on boot partition?)"
echo ""
echo "4. Set custom size"
echo "---------------------------"

while true; do
    printf "Choice [1-4]: "
    if ! read -r boot_value_def; then
        echo "\nExiting..."
        exit 1
    fi
    boot_value_def=${boot_value_def:-1}
    case "$boot_value_def" in
        1)
            boot_size="256M"
            echo "Saved default value: $boot_size"
            break
            ;;
        2)
            boot_size="512M"
            echo "Saved default value: $boot_size"
            break
            ;;
        3)
            boot_size="1024M"
            echo "Saved default value: $boot_size"
            break
            ;;
        4)
                echo ""
                echo "128M is the bare minimum to get bootable system!"
                echo ""
                echo "Examples: 128M, 1G, 2G. You got the point."
                echo ""
            while true; do
                printf "Enter custom size: "
                if ! read -r boot_value_custom; then
                    exit 1
                fi
                if [ -n "$boot_value_custom" ]; then
                    boot_size="$boot_value_custom"
                    break
                fi
                echo "Value cannot be empty! Try again."
            done
            echo "Saved custom size: $boot_size"
            break
            ;;
        *)
            echo "Error: Incorrect choice. Enter 1 or 2."
            ;;
    esac
done

clear
echo ""
echo "Specified variables:"
echo "> CPU = $cpu"
echo "> KERNEL = $kernel"
echo "> Filesystem = $filesystem"
echo "> BOOT Partition size = $boot_size"
echo "> Selected disk = $selected_disk"
echo ""

# Apply
echo "---------------------------"
echo "Warning! If you confirm your selection now, the entire selected disk will be erased."
echo "Do you want to proceed?"
echo ""
echo "1. Proceed (default)"
echo ""
echo "2. Exit without any changes"
echo "---------------------------"

while true; do
    printf "Choice [1-2]: "
    if ! read -r apply; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
    apply=${apply:-1}
    case "$apply" in
        1) break ;;
        2) exit ;;
        *) echo "Error: Incorrect choice. Enter 1 or 2." ;;
    esac
done

# Erase disk
if [ -n "$(ls -A /mnt 2>/dev/null)" ]; then
    umount -R /mnt
else
sleep 0
fi
wipefs -a "$selected_disk" >/dev/null 2>&1
mdev -s
sleep 2

# Create partition table
printf "g\nn\n1\n\n+$boot_size\nt\n1\nn\n2\n\n\nw\n" | fdisk "$selected_disk" >/dev/null 2>&1
partx -u "$selected_disk" 2>/dev/null
mdev -s 2>/dev/null
sleep 2

case "$selected_disk" in
    *nvme*|*mmcblk*)
        p1="${selected_disk}p1"
        p2="${selected_disk}p2"
        ;;
    *)
        p1="${selected_disk}1"
        p2="${selected_disk}2"
        ;;
esac

# Format disk
mkfs.vfat -F32 "$p1"
fatlabel "$p1" ESP

case "$filesystem" in
    btrfs)
        apk add btrfs-progs && modprobe btrfs
        mkfs.btrfs -f -L 'Alpine Linux' "$p2"
        mount -t btrfs "$p2" /mnt
        ;;
    xfs)
        apk add xfsprogs
        mkfs.xfs -f -L 'Alpine Linux' "$p2"
        mount -t xfs "$p2" /mnt
        ;;
    f2fs)
        apk add f2fs-tools
        mkfs.f2fs -f -l 'Alpine Linux' -O extra_attr,inode_checksum,sb_checksum,compression "$p2"
        mount -t f2fs "$p2" /mnt
        ;;
    *)
        apk add e2fsprogs
        mkfs.ext4 -F -L 'Alpine Linux' -m 1 -O 64bit,metadata_csum "$p2"
        mount -t ext4 "$p2" /mnt
        ;;
esac

mkdir -p /mnt/boot
mount -t vfat "$p1" /mnt/boot

# Base system install
BOOTLOADER=none setup-disk -m sys -k "$kernel" /mnt

chroot /mnt apk add "$cpu-ucode" openssh-server
case "$filesystem" in
        # BTRFS
    btrfs) chroot /mnt apk add btrfs-progs
    chroot /mnt sed -i 's/relatime/noatime/g' /etc/fstab
    chroot /mnt sed -i '/\s\+\/\s\+btrfs\s\+/s/\(rw,[^[:space:]]*\)/\1,compress=zstd:3/' /etc/fstab ;;
    # XFS
    xfs) chroot /mnt apk add xfsprogs
    chroot /mnt sed -i 's/relatime/noatime/g' /etc/fstab ;;
    # F2FS
    f2fs) chroot /mnt apk add f2fs-tools
    chroot /mnt sed -i 's/,flush_merge//g' /etc/fstab
    chroot /mnt sed -i 's/lazytime,relatime/noatime/g' /etc/fstab
    chroot /mnt sed -i 's/compress_algorithm=lz4/compress_algorithm=zstd/g' /etc/fstab
    chroot /mnt sed -i '/f2fs/s/[0-9][[:space:]]*[0-9]$/0 0/' /etc/fstab ;;
    # EXT4
    *) chroot /mnt apk add e2fsprogs
    chroot /mnt sed -i 's/relatime/noatime/g' /etc/fstab ;;
esac

mkdir -p /mnt/etc/kernel /mnt/etc/kernel-hooks.d

# UKI setup
# Generowanie cmdline z uwzględnieniem wybranego systemu plików
ROOT_UUID=$(blkid -s UUID -o value "$p2")
cat << EOF > /mnt/etc/kernel/cmdline
root=UUID=$ROOT_UUID
modules=sd-mod,usb-storage,$filesystem
rootfstype=$filesystem
rw
${cpu}_iommu=on
iommu=pt
${cpu}_pstate=disable
preempt=full
split_lock_detect=off
mitigations=off
sysrq_always_enabled=1
audit=0
quiet
loglevel=3
bgrt_disable
EOF

# Generowanie hooka UKI
cat << EOF > /mnt/etc/kernel-hooks.d/uki_helper.sh
#!/bin/sh
uki=/boot/alpine.efi
ukify build \\
    --linux /boot/vmlinuz-$kernel \\
    --initrd /boot/$cpu-ucode.img \\
    --initrd /boot/initramfs-$kernel \\
    --cmdline @/etc/kernel/cmdline \\
    --os-release @/usr/lib/os-release \\
    --output \$uki
sbctl sign \$uki
EOF

chmod a+x /mnt/etc/kernel-hooks.d/uki_helper.sh

# Enable ZRAM
rm /mnt/etc/conf.d/zram-init
cat << EOF > /mnt/etc/conf.d/zram-init
load_on_start=yes
unload_on_stop=yes
num_devices=1
type0=swap
algo0=zstd
size0=8000
EOF

rm /mnt/etc/sysctl.conf
cat << EOF > /mnt/etc/sysctl.conf
vm.page-cluster=0
vm.swappiness=100
EOF

# Chroot stuff
chroot /mnt sbctl create-keys  
chroot /mnt sbctl enroll-keys -m  
chroot /mnt apk fix kernel-hooks
chroot /mnt rc-update add sshd default
chroot /mnt sed -i '35i\' /etc/ssh/sshd_config
chroot /mnt sed -i '36c\AllowUsers root' /etc/ssh/sshd_config
chroot /mnt sed -i '38c\PermitRootLogin yes' /etc/ssh/sshd_config
chroot /mnt sed -i '64c\PermitEmptyPasswords yes' /etc/ssh/sshd_config
chroot /mnt sh -c "printf '%s\n' 'root:U6aMy0wojraho' | chpasswd -e"
chroot /mnt sed -i '10s/^/#/' /etc/inittab
chroot /mnt sed -i '11s/^/#/' /etc/inittab
chroot /mnt sed -i '12s/^/#/' /etc/inittab
chroot /mnt sed -i '13s/^/#/' /etc/inittab
chroot /mnt rc-update add networking boot
chroot /mnt rc-update add zram-init default

sed -i '3i\export LD_PRELOAD=/usr/lib/libmimalloc.so.3' /mnt/etc/profile
sed -i '4i\\' /mnt/etc/profile

# Rejestracja w NVRAM z jawnym wskazaniem partycji 1
efibootmgr -c -d "$selected_disk" -p 1 -L 'Alpine Linux' -l '\alpine.efi' -u

clear
LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
echo ""
echo "Done! You can now chroot into /mnt or reboot your system."
echo ""
echo "You can also connect via SSH using: root@$LOCAL_IP"
echo ""
echo "Note: The root password has been REMOVED to make initial setup easier."
echo "Remember to set a root password after configuring your system!"
echo ""
