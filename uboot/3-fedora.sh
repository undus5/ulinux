#!/bin/bash

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
source ${SELF_DIR}/packages.in

BASE_PKGS="$FEDORA_BASE_PKGS"
DESK_PKGS="$FEDORA_DESK_PKGS"

bootstrap_rootfs() {
   local ROOT_DIR="$1"
   shift
   local PKGS="$@"

   dnf --use-host-config --releasever=$(rpm -E %fedora) \
      --installroot=${ROOT_FS} install -y $PKGS
}

source ${SELF_DIR}/bootstrap.sh
