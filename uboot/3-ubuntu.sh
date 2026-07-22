#!/bin/bash

SELF_DIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
source ${SELF_DIR}/packages.sh

BASE_PKGS="$UBUNTU_BASE_PKGS"
DESK_PKGS="$UBUNTU_DESK_PKGS"

bootstrap_rootfs() {
   local ROOT_DIR="$1"
   shift
   local PKGS="$@"

   PKGS=$(echo $PKGS | xargs | tr ' ' ',')
   local URL="https://changelogs.ubuntu.com/meta-release-lts"
   local CODENAME=$(curl -sL $URL | grep Dist | awk '{print $2}' | tail -n 1)
   debootstrap --components=main,restricted,universe,multiverse \
      --include=$PKGS \
      $CODENAME $ROOT_DIR \
      https://mirrors.ustc.edu.cn/ubuntu/
      # https://mirrors.huaweicloud.com/ubuntu/
      # https://mirrors.aliyun.com/ubuntu/
}

source ${SELF_DIR}/bootstrap.sh
