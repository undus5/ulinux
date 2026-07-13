#!/bin/bash

FEDORA_VER=$(rpm -E %fedora)
FREE_PATH=free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm
NONFREE_PATH=nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm

BASE_URL=https://mirrors.ustc.edu.cn/rpmfusion
# BASE_URL=https://mirrors.aliyun.com/rpmfusion
# BASE_URL=https://download1.rpmfusion.org

FREE_URL=${BASE_URL}/${FREE_PATH}
NONFREE_URL=${BASE_URL}/${NONFREE_PATH}

dnf install -y $FREE_URL
dnf install -y $NONFREE_URL

dnf swap -y ffmpeg-free ffmpeg --allowerasing
dnf swap -y mesa-vulkan-drivers mesa-vulkan-drivers-freeworld --allowerasing
dnf install -y mesa-va-drivers-freeworld intel-media-driver
