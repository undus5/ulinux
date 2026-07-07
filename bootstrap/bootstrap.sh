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
      cp -rfP ${ROOT_FS}/etc/skel/.* ${ROOT_FS}/root/
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

case "$SUB_CMD" in
   bootlive)
      EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
      [[ -n "$EMPTY_DIR" ]] || errf "==> root.fs not empty: $ROOT_FS"

      [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_mount
      bootstrap_rootfs $ROOT_FS $BASE_PKGS
      [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_umount

      cp -rfP ${PROJ_DIR}/root.comm/* ${ROOT_FS}/
      echo "==> copied 'root.comm/*' to 'root.fs'"

      cp -rfP ${PROJ_DIR}/root.live/* ${ROOT_FS}/
      echo "==> copied 'root.live/*' to 'root.fs'"

      bootstrap_post

      vfs_mount
      echo "root:live" | vfs_chroot /sbin/chpasswd
      echo "==> root password is set to 'live'"
      echo "==> running dracut installation ... "
      vfs_chroot /usr/local/bin/dracut-live-install.sh
      vfs_umount

      cp -rfP ${PROJ_DIR} ${ROOT_FS}/root/
      echo "==> copied '$(basename $PROJ_DIR)' to 'root.fs/root/'"

      mkdir -p ${ROOT_FS}/root/.config
      cp -rfP ${PROJ_DIR}/udot/nvim ${ROOT_FS}/root/.config/
      echo "==> copied 'udot/nvim' to 'root.fs/root/.config/nvim'"

      ln -sf .config/nvim/vimrc ${ROOT_FS}/root/.vimrc
      echo "==> linked 'root.fs/.config/nvim/vimrc' to 'root.fs/root/.vimrc'"
      ;;
   bootdesk)
      EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
      [[ -n "$EMPTY_DIR" ]] || errf "==> root.fs not empty: $ROOT_FS"

      [[ -n "$ROOTPASS" ]] || errf "==> require 'export ROOTPASS='"
      [[ -n "$USERNAME" ]] || errf "==> require 'export USERNAME='"
      [[ -n "$USERPASS" ]] || errf "==> require 'export USERPASS='"

      [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_mount
      bootstrap_rootfs $ROOT_FS $DESK_PKGS
      [[ "$BASE_PKGS" =~ "dnf5" ]] && vfs_umount

      cp -rfP ${PROJ_DIR}/root.comm/* ${ROOT_FS}/
      echo "==> copied 'root.comm/*' to 'root.fs'"

      cp -rfP ${PROJ_DIR}/root.desk/* ${ROOT_FS}/
      echo "==> copied 'root.desk/*' to 'root.fs'"

      bootstrap_post

      vfs_mount
      echo "root:${ROOTPASS}" | vfs_chroot /sbin/chpasswd
      echo "==> set root password"
      vfs_chroot useradd -m -U -G wheel,seat $USERNAME
      echo "==> created user '$USERNAME'"
      echo "${USERNAME}:${USERPASS}" | vfs_chroot /sbin/chpasswd
      echo "==> set user password"
      echo "==> running dracut installation ... "
      vfs_chroot /usr/local/bin/dracut-install.sh
      vfs_umount

      cp -rfP ${PROJ_DIR} ${ROOT_FS}/root/
      echo "==> copied '$(basename $PROJ_DIR)' to 'root.fs/root/'"
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
