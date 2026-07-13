#!/bin/bash

set -e

get_help() { echo "==> usage: $(basename $0) <prepare|build> <root.fs>"; }
if [[ -z "$1" || "$1" == "-h" ]]; then get_help; exit 0; fi

errf() { printf "$@\n" >&2; exit 1; }

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

SUB_CMD="$1"
ROOT_FS="$2"
[[ -n "$ROOT_FS" ]] || errf "==> root.fs undefined"
ROOT_FS=$(realpath $ROOT_FS)
[[ -d "$ROOT_FS" ]] || errf "==> root.fs not found"

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
ISO_SRC=${SELF_DIR}/iso.d
ROOT_SRC=${SELF_DIR}/root.live
WORK_DIR=$(dirname $ROOT_FS)
ISO_DIR=${WORK_DIR}/$(basename $ROOT_FS).iso.d
LIVE_IMG_DIR=${ISO_DIR}/LiveOS
LIVE_IMG=${LIVE_IMG_DIR}/squashfs.img

test_empty_dir() {
   local DIR="$1"
   if [[ -d "$DIR" ]]; then
      find $DIR -maxdepth 0 -empty
   else
      echo $DIR
   fi
}

vfs_mount() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   findmnt $ROOT_FS/proc &>/dev/null || \
      mount --mkdir --types proc /proc $ROOT_FS/proc
   for DIR in dev run sys; do
      findmnt $ROOT_FS/$DIR &>/dev/null || \
         mount --mkdir --rbind --make-rslave /$DIR $ROOT_FS/$DIR
   done
}

vfs_umount() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   for DIR in dev proc run sys; do
      findmnt $ROOT_FS/$DIR &>/dev/null && umount -R $ROOT_FS/$DIR
   done
}

vfs_chroot() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   if findmnt $ROOT_FS/dev &>/dev/null; then
      chroot $ROOT_FS $@ || true
   else
      errf "==> VFS not mounted"
   fi
}

prepare_iso() {
   local EMPTY_DIR=$(test_empty_dir $ROOT_FS)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   local ISO_D=$(test_empty_dir $ISO_DIR)
   [[ -n "$ISO_D" ]] || errf "==> iso.d not empty: $ISO_DIR"

   cp -rfP ${ROOT_SRC}/* ${ROOT_FS}/
   echo "==> copied '$(basename $ROOT_SRC)/*' to 'root.fs'"
   vfs_mount
   vfs_chroot dracut-install.sh
   vfs_chroot bash -c 'command -v dnf &>/dev/null && dnf clean packages'
   vfs_chroot bash -c 'command -v paccache &>/dev/null && paccache -rk0'
   vfs_chroot bash -c 'command -v apt &>/dev/null && apt clean'
   vfs_umount

   local K="boot/vmlinuz"
   local RD="boot/initrd"
   [[ -f "${ROOT_FS}/${RD}" ]] || errf "==> initrd not found: root.fs/${RD}"
   install -Dm0755 ${ROOT_FS}/${K} ${ISO_DIR}/${K}
   echo "==> copied '$(basename $ROOT_FS)/${K}' to '$(basename $ISO_DIR)/${K}'"
   install -Dm0755 ${ROOT_FS}/${RD} ${ISO_DIR}/${RD}
   printf "==> copied '$(basename $ROOT_FS)/${RD}'"
   printf " to '$(basename $ISO_DIR)/${RD}'\n"
   install -Dm0644 ${ROOT_FS}/etc/os-release ${ISO_DIR}/boot/os-release
   printf "==> copied '$(basename $ROOT_FS)/etc/os-release'"
   printf "to '$(basename $ISO_DIR)/boot/os-release'\n"

   [[ -d $LIVE_IMG_DIR ]] || mkdir -p $LIVE_IMG_DIR
   [[ -f $LIVE_IMG ]] && rm -f $LIVE_IMG
   echo "==> packing '${LIVE_IMG#$WORK_DIR/}'"
   mksquashfs $ROOT_FS $LIVE_IMG -comp zstd -no-xattrs -quiet

   cp -rfP ${ISO_SRC}/* ${ISO_DIR}/
   echo "==> copied '$(basename $ISO_SRC)/*' to '$(basename $ISO_DIR)/'"
}

build_iso() {
   local ISO_D=$(test_empty_dir $ISO_DIR)
   [[ -z "$ISO_D" ]] || prepare_iso

   source ${ISO_DIR}/boot/os-release
   local NAME=$ID; [[ -n "$VERSION_ID" ]] && NAME+="-${VERSION_ID}"
   [[ "$NAME" == "arch" ]] && NAME="archlinux-$(date +%Y.%m.%d)"
   local LABEL=${NAME^^}; LABEL=${LABEL/-/_}
   sed "s/_LABEL_/${LABEL}/g" \
      ${ISO_SRC}/limine/limine.conf >\
      ${ISO_DIR}/limine/limine.conf
   echo "==> updated 'iso.d/limine/limine.conf'"

   local ISO_FILE=${WORK_DIR}/${NAME}.iso
   echo "==> packing '${ISO_FILE#$WORK_DIR/}'"
   xorriso -as mkisofs -R -r -J -V $LABEL \
      -b limine/limine-bios-cd.bin \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      --efi-boot limine/limine-uefi-cd.bin \
      -efi-boot-part --efi-boot-image \
      -o $ISO_FILE $ISO_DIR -quiet &>/dev/null

   ${ISO_SRC}/limine/limine bios-install $ISO_FILE &>/dev/null
   echo "==> limine-bios installed to '${ISO_FILE#$WORK_DIR/}'"
}

case "$SUB_CMD" in
   prepare)
      prepare_iso
      ;;
   build)
      build_iso
      ;;
   *)
      get_help
      ;;
esac
