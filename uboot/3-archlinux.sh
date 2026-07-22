#!/bin/bash

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
source ${SELF_DIR}/packages.sh

BASE_PKGS="$ARCHLINUX_BASE_PKGS"
DESK_PKGS="$ARCHLINUX_DESK_PKGS"

bootstrap_rootfs() {
   local ROOT_DIR="$1"
   shift
   local PKGS="$@"

   pacstrap -K $ROOT_DIR $PKGS
}

source ${SELF_DIR}/bootstrap.sh
