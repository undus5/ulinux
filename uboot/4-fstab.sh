#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/root)
EFI_UUID=$(blkid -s UUID -o value /dev/disk/by-partlabel/EFIPART)

cat << EOF
# man 5 fstab
UUID=${ROOT_UUID} /     btrfs compress=zstd,subvol=/@a/@  0 0
UUID=${ROOT_UUID} /b    btrfs compress=zstd,subvol=/@b    0 0
UUID=${ROOT_UUID} /home btrfs compress=zstd,subvol=/@home 0 0
UUID=${EFI_UUID} /efi vfat defaults 0 2
EOF
