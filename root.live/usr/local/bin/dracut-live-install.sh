#!/bin/bash

KDIR=/usr/lib/modules
KVER=$(ls -1 $KDIR | head -n 1)

KIMG=${KDIR}/${KVER}/vmlinuz # fedora, archlinux
[[ -e $KIMG ]] || KIMG=/boot/vmlinuz-${KVER} # ubuntu
if [[ -e $KIMG ]]; then
   cp -f $KIMG /boot/vmlinuz
   echo "==> installed '/boot/vmlinuz' (${KVER})"
fi

dracut --force --no-hostonly --kver $KVER /boot/initrd
echo "==> installed '/boot/initrd' (${KVER})"
