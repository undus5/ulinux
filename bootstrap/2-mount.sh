#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

MAP_NAME=root
LUKS_BLOCK=/dev/mapper/${MAP_NAME}
EFI_LABEL="EFIPART"
EFI_BLOCK=/dev/disk/by-partlabel/${EFI_LABEL}
ROOT_LABEL="ROOTPART"
ROOT_BLOCK=/dev/disk/by-partlabel/${ROOT_LABEL}

if [[ ! -b $LUKS_BLOCK ]]; then
   LUKS_PASS=$PASS
   [[ -n "$LUKS_PASS" ]] || errf "==> require 'export PASS='"
   printf "$LUKS_PASS" | cryptsetup open $ROOT_BLOCK $MAP_NAME -d -
fi

mount -o subvol=@a/@ $LUKS_BLOCK /mnt
mount -o subvol=@home --mkdir $LUKS_BLOCK /mnt/home

mount --mkdir $EFI_BLOCK /mnt/efi
