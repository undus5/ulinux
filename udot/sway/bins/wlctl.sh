#!/usr/bin/bash

set -e

errf() { printf "${@}" >&2 && exit 1; }

command-check() {
   local name=${1}
   command -v ${name} &>/dev/null || errf "command not found: ${name}\n"
}

#################################################################################
# reload wayland compositor
#################################################################################

reload() {
   [[ -n "${SWAYSOCK}" ]] && swaymsg reload
   [[ -n "${LABWC_PID}" ]] && labwc -r
   if [[ -n "${SWAYSOCK}" || -n "${LABWC_PID}" ]]; then
      wlinit.sh
      pidof kanshi &>/dev/null && sleep 0.1 && kanshictl reload
   fi
}

#################################################################################
# volume control
# https://wiki.archlinux.org/title/WirePlumber
#################################################################################

vol-get() {
   command-check wpctl
   local id=${1}
   local info=$(wpctl get-volume ${id})
   local integer=$(echo "${info}" | awk -F'[. ]' '{ print $2 }')
   local fraction=$(echo "${info}" | awk -F'[. ]' '{ print $3 }')
   local muted=$(echo "${info}" | awk -F'[. ]' '{ print $4 }')
   local label=""

   if [[ "${muted}" == "[MUTED]" ]]; then
      label=${muted}
   else
      [[ "${integer}" == "1" ]] && label="100%" || label="${fraction}%"
   fi
   echo "${label}"
}

vol-num() {
   command-check wpctl
   [[ "${1}" == "[MUTED]" ]] && echo "0" || echo "${1:0:-1}"
}

# https://wiki.archlinux.org/title/Desktop_notifications#Replace_previous_notification
vol-notify() {
   local vol="$1"
   local msg="${2:-Volume}"
   notify-send -a $(basename $0) -t 1000 \
      -h int:value:$vol \
      -h string:x-canonical-private-synchronous:volume \
      "$msg"
}

vol-down() {
   command-check wpctl
   per=${1:-5}
   wpctl set-volume @DEFAULT_AUDIO_SINK@ ${per}%-
   local vol=$(vol-num $(vol-get @DEFAULT_AUDIO_SINK@))
   wobctl.sh $vol
   # vol-notify $vol
}

vol-up() {
   command-check wpctl
   per=${1:-5}
   wpctl set-volume @DEFAULT_AUDIO_SINK@ ${per}%+
   local vol=$(vol-num $(vol-get @DEFAULT_AUDIO_SINK@))
   wobctl.sh $vol
   # vol-notify $vol
}

mute-toggle-speaker() {
   command-check wpctl
   wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
   local vol=$(vol-num $(vol-get @DEFAULT_AUDIO_SINK@))
   wobctl.sh $vol
   # local msg=
   # [[ "$vol" == "0" ]] && msg="Speaker Muted"
   # vol-notify "$vol" "$msg"
}

mute-toggle-mic() {
   command-check wpctl
   wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
}

sink-toggle() {
   command-check wpctl
   command-check jq
   local sinkids=( $(pw-dump | jq '.[]|select(.info.props."media.class"=="Audio/Sink")|.id' | xargs) )
   local currentid=$(wpctl inspect @DEFAULT_SINK@ | head -n 1 | cut -d, -f1 | cut -d' ' -f2)
   local size=${#sinkids[@]}
      local index=-1
      local targetid
      local desc

      for i in "${!sinkids[@]}"; do
         if [[ "${sinkids[$i]}" == "${currentid}" ]]; then
            index=${i}
            break
         fi
      done

      index=$(( ${index} + 1 ))
      (( index >= size )) && index=0
      targetid=${sinkids[$index]}
      desc=$(pw-dump | jq -r --argjson id ${targetid} '.[]|select(.id==$id)|.info.props."node.description"')

      wpctl set-default ${targetid}
      notify-send -a $(basename $0) -t 1000 "Audio Sink" "${desc}"
}

#################################################################################
# status bar content
#################################################################################

scratchpad-count() {
   local count=$(swaymsg -t get_tree | grep -c '"scratchpad_state": "fresh"')
   [[ "${count}" =~ ^[1-9]+[0-9]*$ ]] && echo "[ScratchPad: ${count}] " || echo ""
}

muted-label() {
   command-check wpctl
   local label
   local vol

   vol="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
   [[ "${vol}" =~ MUTED ]] && label="Speaker"

   vol="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)"
   if [[ "${vol}" =~ MUTED ]]; then
      [[ -n "${label}" ]] && label+=",Mic" || label="Mic"
   fi

   [[ -n "${label}" ]] && echo "[Muted:${label}] " || echo ""
}

bar-status() {
   local str
   while true; do
      str=""
      str+="$(scratchpad-count)"
      str+="$(muted-label)"
      str+="$(date '+%a %b.%d %H:%M')"
      printf "%s \n" "${str}"
      sleep 0.1
   done
}

#################################################################################
# lock screen, suspend
#################################################################################

lock-screen() {
   command -v swaylock &>/dev/null || errf "command not found: swaylock\n"
   pidof swaylock || swaylock \
      --daemonize \
      --ignore-empty-password \
      --indicator-idle-visible \
      --indicator-radius 50 \
      --indicator-thickness 13 \
      --indicator-x-position 80 \
      --indicator-y-position 80 \
      --color 000000 \
      --scaling solid_color
}

# lock-suspend() {
#    lock-screen
#    sleep 0.2
#    systemctl suspend
# }

#################################################################################
# screenshot
# https://github.com/OctopusET/sway-contrib
#################################################################################

grim-check() {
   command -v grim &>/dev/null || errf "command not found: grim\n"
}

grimshot-check() {
   command -v grimshot.sh &>/dev/null || errf "command not found: grimshot\n"
}

save_path=~/Pictures/Screenshot.$(date +%y%m%d.%H%M%S).$(date +%N|cut -c1).png

screenshot-fullscreen() {
   grim-check
   grim ${save_path}
}

screenshot-area() {
   grim-check && grimshot-check
   grimshot.sh savecopy area ${save_path}
}

screenshot-window() {
   grim-check && grimshot-check
   grimshot.sh savecopy window ${save_path}
}

#################################################################################
# gsettings
#################################################################################

theme() {
   echo "gsettings set org.gnome.desktop.interface icon-theme <name>"
   echo "gsettings set org.gnome.desktop.interface gtk-theme <name>"
}

#################################################################################
# apps
#################################################################################

terminal() {
   if command -v foot &>/dev/null; then
      foot
   elif command -v alacritty &>/dev/null; then
      alacritty
   fi
}

dynamic-menu() { wmenu-run -b -f 'monospace bold 18' "${@}"; }

app-launcher() { fuzzel; }

#################################################################################
# dispatcher
#################################################################################

case "${1}" in
   "")
      printf "Usage: $(basename $0) <function_name>\n"
      printf "function_name:\n"
      declare -F | awk '{print "  " $3}'
      ;;
   *)
      command="${1}"
      shift
      ${command} "${@}"
      ;;
esac

