#!/bin/sh

# Info
clear
echo "---------------------------"
echo "Welcome to my little alpineinstall script."
echo "This script will set the repositories to rolling release,"
echo "allow you to choose the kernel and microcode,"
echo "and set the memory allocator to mimalloc3"
echo "Additionally, it will enable secure boot by default"
echo "(if secure boot is in setup-mode) and"
echo "create a signed UKI image."
echo "Do you want to proceed?"
echo "1. Proceed (default)"
echo "2. Exit without any changes"
echo "---------------------------"

while true; do
    printf "Choice [1-2]:"
    
    if ! read -r begin; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
	begin=${begin:-1}
    case "$begin" in
        1)
            break
            ;;
        2)
            exit
            ;;
        *)
            echo "Error: Incorrect choice. Enter 1 or 2."
            ;;
    esac
done

# Add repos and basic tools
clear
rm /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/main\n' >> /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/community\n' >> /etc/apk/repositories
printf 'http://dl-cdn.alpinelinux.org/alpine/edge/testing\n' >> /etc/apk/repositories
apk add dosfstools e2fsprogs efibootmgr kernel-hooks lsblk mimalloc3 sbctl systemd-efistub ukify util-linux  

# Choose CPU
clear
echo "Select your CPU:"
echo "---------------------------"
echo "1. Intel (default)"
echo "2. AMD"
echo "---------------------------"

while true; do
    printf "Choice [1-2]:"
    
    if ! read -r microcode; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
	microcode=${microcode:-1}
    case "$microcode" in
        1)
            cpu=intel
            break
            ;;
        2)
            cpu=amd
            break
            ;;
        *)
            echo "Error: '$microcode' is incorrect. Enter 1 or 2."
            ;;
    esac
done

# Choose kernel
clear
echo "Select kernel:"
echo "---------------------------"
echo "1. Stable (default)"
echo "2. LTS"
echo "3. Virt"
echo "---------------------------"

while true; do
    printf "Choice [1-3]:"
    
    if ! read -r kernel_variant; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
	kernel_variant=${kernel_variant:-1}
    case "$kernel_variant" in
        1)
            kernel=stable
            break
            ;;
        2)
            kernel=lts
            break
            ;;
        3)
            kernel=virt
            break
            ;;
        *)
            echo "Error: '$kernel_variant' is incorrect. Enter 1, 2 or 3."
            ;;
    esac
done

# Choose boot partition size
clear
boot_size=""

echo "Set boot partition size (ex. 512M, 1G):"
echo "---------------------------"
echo "1. 256M (default)"
echo "2. Set custom size"
echo "---------------------------"

while true; do
    printf "Choice [1-2]: "
    
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

echo "Selected disk: $selected_disk"

clear
echo ""
echo "Specified variables:"
echo "> CPU = "$cpu
echo "> KERNEL = "$kernel
echo "> BOOT Partition size = "$boot_size
echo "> Selected disk = "$selected_disk
echo ""

# Apply
echo "---------------------------"
echo "Warning! If you confirm your selection now, the entire selected disk will be erased."
echo "Do you want to proceed?"
echo "1. Proceed (default)"
echo "2. Exit without any changes"
echo "---------------------------"

while true; do
    printf "Choice [1-2]:"
    
    if ! read -r apply; then
        echo ""
        echo "Exiting..."
        exit 1
    fi
	apply=${apply:-1}
    case "$apply" in
        1)
            break
            ;;
        2)
            exit
            ;;
        *)
            echo "Error: Incorrect choice. Enter 1 or 2."
            ;;
    esac
done


# Erase disk
wipefs -a "$selected_disk" >/dev/null 2>&1

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
mkfs.ext4 -F -L 'Alpine Linux' "$p2"

# Mount partitions
mount -t ext4 $p2 /mnt ; mkdir -p /mnt/boot ; mount -t vfat $p1 /mnt/boot

# Base system install
setup-disk -m sys -B none -k $kernel /mnt

# UKI setup
chroot /mnt apk add $cpu-ucode
mkdir -p /mnt/etc/kernel && mkdir -p /mnt/etc/kernel-hooks.d
printf 'root=UUID='$(blkid -s UUID -o value $p2)'\n' >> /mnt/etc/kernel/cmdline
printf 'modules=sd-mod,usb-storage,ext4\n' >> /mnt/etc/kernel/cmdline
printf 'rootfstype=ext4\n' >> /mnt/etc/kernel/cmdline
printf 'rw\n' >> /mnt/etc/kernel/cmdline
printf ''$cpu'_iommu=on\n' >> /mnt/etc/kernel/cmdline
printf 'preempt=full\n' >> /mnt/etc/kernel/cmdline
printf 'split_lock_detect=off\n' >> /mnt/etc/kernel/cmdline
printf 'mitigations=off\n' >> /mnt/etc/kernel/cmdline
printf 'sysrq_always_enabled=1\n' >> /mnt/etc/kernel/cmdline
printf 'audit=0\n' >> /mnt/etc/kernel/cmdline
printf 'quiet\n' >> /mnt/etc/kernel/cmdline
printf 'loglevel=3\n' >> /mnt/etc/kernel/cmdline
printf 'bgrt_disable\n' >> /mnt/etc/kernel/cmdline
printf '#!/bin/sh\n' >> /mnt/etc/kernel-hooks.d/uki_helper.sh
printf 'uki=/boot/alpine.efi\n' >> /mnt/etc/kernel-hooks.d/uki_helper.sh
printf 'ukify build --linux /boot/vmlinuz-'$kernel' --initrd /boot/'$cpu'-ucode.img --initrd /boot/initramfs-'$kernel' --cmdline @/etc/kernel/cmdline --os-release @/usr/lib/os-release --output $uki\n' >> /mnt/etc/kernel-hooks.d/uki_helper.sh
printf 'sbctl sign $uki\n' >> /mnt/etc/kernel-hooks.d/uki_helper.sh
chmod a+x /mnt/etc/kernel-hooks.d/uki_helper.sh

# Chroot stuff
chroot /mnt sbctl create-keys ; chroot /mnt sbctl enroll-keys -m ; chroot /mnt apk fix kernel-hooks
sed -i '3i\LD_PRELOAD=/usr/lib/libmimalloc.so.3' /mnt/etc/profile
sed -i '4i\\' /mnt/etc/profile
efibootmgr -c -d $selected_disk -L 'Alpine Linux' -l '\alpine.efi' -u
clear
echo ""
echo "Done! You can chroot now to /mnt or reboot your system."
echo "If you use a laptop you probably want to enter chroot and install some linux-firmware*."
