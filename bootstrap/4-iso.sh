#!/bin/bash

set -e

get_help() { echo "==> usage: $(basename $0) <prepare|build> <root.fs>"; }
if [[ -z "$1" || "$1" == "-h" ]]; then get_help; exit 0; fi

errf() { printf "$@\n" >&2; exit 1; }
test_empty_dir() {
   local DIR="$1"
   if [[ -d "$DIR" ]]; then
      find $DIR -maxdepth 0 -empty
   else
      echo $DIR
   fi
}

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

SUB_CMD="$1"
ROOT_FS="$2"
[[ -n "$ROOT_FS" ]] || errf "==> root.fs undefined"
ROOT_FS=$(realpath $ROOT_FS)
[[ -d "$ROOT_FS" ]] || errf "==> root.fs not found"

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
PROJ_DIR=$(dirname $SELF_DIR)
ISO_SRC=${PROJ_DIR}/iso.d
WORK_DIR=$(dirname $ROOT_FS)
ISO_DIR=${WORK_DIR}/$(basename $ROOT_FS).iso.d
LIVE_IMG_DIR=${ISO_DIR}/LiveOS
LIVE_IMG=${LIVE_IMG_DIR}/squashfs.img

prepare_iso() {
   local EMPTY_DIR=$(test_empty_dir $ROOT_FS)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   local ISO_D=$(test_empty_dir $ISO_DIR)
   [[ -n "$ISO_D" ]] || errf "==> iso.d not empty: $ISO_DIR"

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

   # rm -rf ${ROOT_FS}/var/cache/*
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
