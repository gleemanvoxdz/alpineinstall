# alpineinstall.sh
My scripts to setup Alpine Linux with some nice features.

**Features:**
- Enables rolling release repos,
- Allows you to choose the kernel, microcode, file system,
- Sets the memory allocator to mimalloc3,
- Enables secure boot by default (if secure boot is in setup-mode in UEFI),
- Creates a signed UKI image (no bootloader needed).
- Only for x86_64 UEFI platform!

**Usage:**
- As always, go through setup-alpine and select "none" in the disks section
- Run the command below:
```sh
apk add curl && curl -L -O https://raw.githubusercontent.com/gleemanvoxdz/alpineinstall/refs/heads/main/alpineinstall.sh && sh alpineinstall.sh
```
- Shorter URL:
```sh
apk add curl && curl -L -O https://adisz.net/linux/alpineinstall.sh && sh alpineinstall.sh
```

# alpinedsektop.sh
**This script is used to quickly configure the base system to suit my needs. You can check it out yourself if you'd like.**
