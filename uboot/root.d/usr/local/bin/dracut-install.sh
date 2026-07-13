#!/bin/bash

set -e

KVER="$1"
DEST=/boot

KDIR=/usr/lib/modules
[[ -n "$KVER" ]] || KVER=$(ls -1 $KDIR | tail -n 1)
KIMG=${KDIR}/${KVER}/vmlinuz # fedora, archlinux
[[ -f $KIMG ]] || KIMG=/boot/vmlinuz-${KVER} # ubuntu
[[ -f $KIMG ]] || exit 1

install -Dm0644 $KIMG ${DEST}/vmlinuz
echo "==> installed '${DEST}/vmlinuz' (${KVER})"
echo "==> generating initramfs.img ..."
if [[ -f /etc/dracut.conf.d/10-dmsquash-live.conf ]]; then
 # for live ISO
 dracut --force --no-hostonly \
    --kver "$KVER" "${DEST}/initramfs.img"
else
 dracut --force --hostonly --no-hostonly-cmdline \
    --kver "$KVER" "${DEST}/initramfs.img"
fi
echo "==> installed '${DEST}/initramfs.img' (${KVER})"

if ! findmnt /a &>/dev/null; then
   install -Dm0644 ${DEST}/vmlinuz /efi/a/vmlinuz
   echo "==> installed '/efi/a/vmlinuz' (${KVER})"
   install -Dm0644 ${DEST}/initramfs.img /efi/a/initramfs.img
   echo "==> installed '/efi/a/initramfs.img' (${KVER})"
fi

if ! findmnt /b &>/dev/null; then
   install -Dm0644 ${DEST}/vmlinuz /efi/b/vmlinuz
   echo "==> installed '/efi/b/vmlinuz' (${KVER})"
   install -Dm0644 ${DEST}/initramfs.img /efi/b/initramfs.img
   echo "==> installed '/efi/b/initramfs.img' (${KVER})"
fi
