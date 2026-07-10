#!/usr/bin/bash

chkcmd() { command -v "${@}" &>/dev/null; }
chksrv() { pidof "${@}" &>/dev/null; }
bgr() { nohup "${@}" &>/dev/null & }

chkcmd kanshi && ! chksrv kanshi && bgr kanshi
chkcmd fcitx5 && ! chksrv fcitx5 && bgr fcitx5 -d -r

POLKIT_NAME=polkit-mate-authentication-agent-1
POLKIT_FEDORA=/usr/libexec/${POLKIT_NAME}
POLKIT_ARCHLINUX=/usr/lib/mate-polkit/${POLKIT_NAME}
[[ -f $POLKIT_ARCHLINUX ]] && POLKIT_EXEC=$POLKIT_ARCHLINUX
[[ -f $POLKIT_FEDORA ]] && POLKIT_EXEC=$POLKIT_FEDORA
chkcmd $POLKIT_EXEC && ! chksrv $POLKIT_NAME && bgr $POLKIT_EXEC

gsettings set org.gnome.desktop.privacy remember-recent-files false

gsettings set org.gnome.desktop.interface color-scheme prefer-dark

if [[ -d /usr/share/icons/Papirus-Dark ]]; then
    gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark
fi

if [[ -n "$SWAYSOCK" && -d /usr/share/icons/breeze_cursors ]]; then
    swaymsg seat seat0 xcursor_theme breeze_cursors 32
fi

# https://www.toptal.com/designers/subtlepatterns/
BG_FILE=$(find ~/Pictures/ -maxdepth 1 -type f -name 'wallpaper-*.png')
BG_FILE=$(echo $BG_FILE | head -n 1)
if [[ ! -f $BG_FILE ]]; then
   BG_FILE=$(find ~/.config/sway/ -maxdepth 1 -type f -name 'wallpaper-*.png')
   BG_FILE=$(echo $BG_FILE | head -n 1)
fi
if [[ -f $BG_FILE ]]; then
   BG_NAME=$(basename $BG_FILE)
   BG_NAME=${BG_NAME%.*}
   BG_MODE=${BG_NAME#wallpaper-}
   MODES=( stretch fill fit center tile )
   MODE=
   for M in ${MODES[@]}; do
      [[ "$BG_MODE" == "$M" ]] && MODE=$M
   done
   if [[ -n "$MODE" ]]; then
      chksrv swaybg && pidof swaybg | xargs kill -9
      bgr swaybg --mode $MODE --image "$BG_FILE"
   fi
fi

### ~/.bashrc
# https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland
# export QT_IM_MODULE=fcitx
# export XMODIFIERS=@im=fcitx
# [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]] && exec sway
# [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$XDG_VTNR" -eq 1 ]] && kmscon-launch-gui sway
