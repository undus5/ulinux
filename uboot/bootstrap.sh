#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

[[ -n "$BASE_PKGS" ]] || errf "\$BASE_PKGS undefined"
[[ -n "$DESK_PKGS" ]] || errf "\$DESK_PKGS undefined"

get_help() {
   echo "==> usage: $(basename $0) <bootlive|bootdesk|chroot> <root.fs> [cmd]"
}

if [[ -z "$1" || "$1" == "-h" ]]; then get_help; exit 0; fi

[[ "$EUID" == 0 ]] || errf "==> need root priviledge"

SUB_CMD="$1"
ROOT_FS="$2"
[[ -n "$ROOT_FS" ]] || errf "==> root.fs undefined"
ROOT_FS=$(realpath $ROOT_FS)

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
PROJ_DIR=$(dirname $SELF_DIR)
PROJ_NAME=$(basename $PROJ_DIR)

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

# bootstrap_rootfs() {
#    return
# }

bootstrap_post() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   #############################################################################
   # fedora
   #############################################################################
   if [[ "$BASE_PKGS" =~ "dnf5" ]]; then
      vfs_mount
      # clean package cache
      vfs_chroot dnf clean packages
      vfs_umount
   fi
   #############################################################################
   # archlinux
   #############################################################################
   if [[ "$BASE_PKGS" =~ "pacman" ]]; then
      vfs_mount
      vfs_chroot locale-gen
      # clean package cache
      vfs_chroot paccache -rk0
      vfs_umount
      # /root/.bashrc
      cp -rP ${ROOT_FS}/etc/skel/.* ${ROOT_FS}/root/
      echo "==> copied 'root.fs/etc/skel/*' to 'root.fs/root/'"
   fi
   #############################################################################
   # ubuntu
   #############################################################################
   if [[ "$BASE_PKGS" =~ "debootstrap" ]]; then
      vfs_mount
      # restore to OG GNU coreutils
      # since uutils 'stat -c %m' return empty in chroot
      # causing dracut return error on btrfs (func freeze_ok_for_fstype())
      vfs_chroot apt-get -y purge coreutils-from-uutils --allow-remove-essential
      vfs_chroot apt-get -y install coreutils-from-gnu
      # replace chrony with systemd-timesyncd
      vfs_chroot apt-get -y purge chrony
      vfs_chroot apt-get -y install systemd-timesyncd
      # clean package cache
      vfs_chroot apt autoclean
      vfs_umount
   fi
   #############################################################################
   # common
   #############################################################################
   systemctl --root $ROOT_FS disable getty@.service
   systemctl --root $ROOT_FS enable kmsconvt@.service
   systemctl --root $ROOT_FS enable systemd-resolved.service
   systemctl --root $ROOT_FS enable systemd-networkd.service
   systemctl --root $ROOT_FS enable systemd-timesyncd.service
}

bootstrap_os() {
   EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -n "$EMPTY_DIR" ]] || errf "==> root.fs not empty: $ROOT_FS"

   [[ -n "$PASS" ]] || PASS="pass"

   [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_mount
   local PKGS="$1"
   bootstrap_rootfs $ROOT_FS $PKGS
   [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_umount

   cp -rP ${SELF_DIR}/root.d/* ${ROOT_FS}/
   echo "==> copied 'root.d/*' to 'root.fs'"

   bootstrap_post

   cp -rP ${PROJ_DIR} ${ROOT_FS}/root/
   echo "==> copied '${PROJ_NAME}' to 'root.fs/root/'"

   vfs_mount

   echo "root:${PASS}" | vfs_chroot /sbin/chpasswd
   echo "==> set password for 'root'"

   vfs_chroot useradd -m -U -G wheel,seat u
   echo "==> created regular user 'u'"
   echo "u:${PASS}" | vfs_chroot /sbin/chpasswd
   echo "==> set password for 'u'"

   vfs_chroot useradd -r -m -U -s /usr/bin/nologin i
   echo "==> created system user 'i'"

   vfs_chroot cp -rP /root/${PROJ_NAME} /home/u/
   vfs_chroot chown -R u:u /home/u/${PROJ_NAME}
   vfs_chroot runuser - u -c '~/${PROJ_NAME}/udot/udot.sh install nvim'

   mkdir -p /root/.config
   ln -sf /home/u/.config/nvim /root/.config/nvim
   echo "==> linked /root/.config/nvim"
   ln -sf /root/.config/nvim/vimrc /root/.vimrc
   echo "==> linked /root/.vimrc"

   echo "==> generating initramfs image ... "
   vfs_chroot /usr/local/bin/dracut-install.sh

   vfs_umount
}

case "$SUB_CMD" in
   bootbase)
      bootstrap_os $BASE_PKGS
      ;;
   bootdesk)
      bootstrap_os $DESK_PKGS
      ;;
   chroot)
      shift; shift;
      vfs_mount
      vfs_chroot $@
      vfs_umount
      ;;
   umount)
      vfs_umount
      ;;
   *)
      get_help
      ;;
esac
