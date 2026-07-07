#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

if [[ "$1" == "-h" ]]; then
   echo "==> require 'export DISK=; export LUKSPASS='"; exit 0
fi

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

[[ -n "$DISK" ]] || errf "==> require 'export DISK='"
[[ -b $DISK ]] || errf "==> not a block device: $DISK"
[[ -n "$LUKSPASS" ]] || errf "==> require 'export LUKSPASS='"

EFI_LABEL="EFIPART"
EFI_BLOCK=/dev/disk/by-partlabel/${EFI_LABEL}
ROOT_LABEL="ROOTPART"
ROOT_BLOCK=/dev/disk/by-partlabel/${ROOT_LABEL}

ROOT_TYPE_UUID="4f68bce3-e8cd-4db1-96e7-fbcaf984b709"
parted -s $DISK \
    mklabel gpt \
    mkpart $EFI_LABEL fat32 1MiB 1025MiB \
    set 1 esp on \
    mkpart $ROOT_LABEL btrfs 1025MiB 100% \
    type 2 $ROOT_TYPE_UUID

mkfs.fat -F 32 -n "EFIFAT" $EFI_BLOCK

MAP_NAME=root
LUKS_BLOCK=/dev/mapper/${MAP_NAME}

printf "$LUKSPASS" | cryptsetup luksFormat $ROOT_BLOCK -d -
printf "$LUKSPASS" | cryptsetup open $ROOT_BLOCK $MAP_NAME -d -

mkfs.btrfs $LUKS_BLOCK
mount $LUKS_BLOCK /mnt

btrfs subvolume create /mnt/@a
btrfs subvolume create /mnt/@a/@
btrfs subvolume create /mnt/@b
btrfs subvolume create /mnt/@b/@
btrfs subvolume create /mnt/@home
umount /mnt
