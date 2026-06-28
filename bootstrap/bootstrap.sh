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
   [[ -n "$ROOT_FS" ]] || errf "==> \$ROOT_FS undefined"
   for DIR in dev proc run sys; do
      findmnt $ROOT_FS/$DIR &>/dev/null || \
         mount --mkdir --rbind --make-rslave /$DIR $ROOT_FS/$DIR
   done
}

vfs_umount() {
   [[ -n "$ROOT_FS" ]] || errf "==> \$ROOT_FS undefined"
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

bootstrap_post_archlinux() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   # archlinux locales
   if [[ -e ${ROOT_FS}/usr/bin/locale-gen ]]; then
      vfs_mount
      vfs_chroot locale-gen
      vfs_umount
   fi
   # archlinux /root/.bashrc
   if [[ ! -e ${ROOT_FS}/root/.bashrc ]]; then
      cp -rfP ${ROOT_FS}/etc/skel/.* ${ROOT_FS}/root/
      echo "==> copied 'root.fs/etc/skel/*' to 'root.fs/root/'"
   fi
}

bootstrap_post_ubuntu() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
   # ubuntu is such a mess
   if [[ "$BASE_PKGS" =~ "linux-generic" ]]; then
      vfs_mount
      # restore to OG GNU coreutils
      # since uutils 'stat -c %m' return empty in chroot
      # causing dracut return error on btrfs (func freeze_ok_for_fstype())
      vfs_chroot apt-get -y purge coreutils-from-uutils --allow-remove-essential
      vfs_chroot apt-get -y install coreutils-from-gnu
      # replace chrony with systemd-timesyncd
      vfs_chroot apt-get -y purge chrony
      vfs_chroot apt-get -y install systemd-timesyncd
      vfs_umount
   fi
}

bootstrap_post() {
   local EMPTY_DIR=$(test_empty_dir ${ROOT_FS}/usr)
   [[ -z "$EMPTY_DIR" ]] || errf "==> root.fs is empty: $ROOT_FS"
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

      bootstrap_post_archlinux
      bootstrap_post_ubuntu
      bootstrap_post

      vfs_mount
      vfs_chroot bash -c 'echo "root:live" | /sbin/chpasswd'
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

      bootstrap_post_archlinux
      bootstrap_post_ubuntu
      bootstrap_post

      vfs_mount
      vfs_chroot bash -c 'echo "root:${ROOTPASS}" | /sbin/chpasswd'
      echo "==> set root password"
      vfs_chroot useradd -m -U -G wheel,seat $USERNAME
      echo "==> created user '$USERNAME'"
      vfs_chroot bash -c 'echo "${USERNAME}:${USERPASS}" | /sbin/chpasswd'
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
   *)
      get_help
      ;;
esac
