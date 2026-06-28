#!/bin/bash

errf() { printf "$@\n" >&2; exit 1; }
# replace '/home/*' with '~' in path for display
tilde_path() { echo "$1" | sed "s#$(realpath ~)#~#"; }

[[ "$EUID" != "0" ]] || errf "==> abort for super user"

self_dir=$(dirname $(realpath ${BASH_SOURCE[0]}))
src_dir=$self_dir
conf_dir=~/.config
mkdir -p $conf_dir

test_names() {
   local names=()
   if [[ "$1" == "all" ]]; then
      mapfile -t names < <(find $src_dir -mindepth 1 -maxdepth 1 -type d \
         ! -name ".git" \
         ! -name "kanshi" \
         -exec basename '{}' \;)
   else
      for n in "$@"; do
         n=${n%/}
         [[ "$n" == "rime" || -d ${src_dir}/${n} ]] || errf "name not found: $n"
         [[ "$n" != "kanshi" ]] && names+=("$n")
      done
   fi
   echo "${names[@]}"
}

install_config() {
   local n="$1"
   if [[ -d ${conf_dir}/${n} ]]; then
      rm -rf ${conf_dir}/${n}
      echo "==> removed '$(tilde_path ${conf_dir}/${n})'"
   fi
   cp -rf ${src_dir}/${n} ${conf_dir}/${n}
   echo "==> installed '$(tilde_path ${conf_dir}/${n})'"
}

merge_config() {
   local n="$1"
   if [[ -d ${conf_dir}/${n} ]]; then
      rm -rf ${src_dir}/${n}
      cp -rf ${conf_dir}/${n} ${src_dir}/${n}
      echo "==> merged '$(tilde_path ${src_dir}/${n})'"
   fi
}

install_lite_xl_config() {
   mkdir -p ${conf_dir}/lite-xl
   local path="lite-xl/init.lua"
   cp -f ${src_dir}/${path} ${conf_dir}/${path}
   echo "==> installed '$(tilde_path ${conf_dir}/${path})'"
}

merge_lite_xl_config() {
   local path="lite-xl/init.lua"
   cp -f ${conf_dir}/${path} ${src_dir}/${path}
   echo "==> merged '$(tilde_path ${src_dir}/${path})'"
}

install_rime_wubi86s() {
   local rime_dir=~/.local/share/fcitx5/rime
   mkdir -p $rime_dir
   cp -f ${src_dir}/rime-wubi86s/*.yaml ${rime_dir}/
   echo "==> installed '$(tilde_path ${rime_dir})/*.yaml'"
}

merge_rime_wubi86s() {
   local rime_dir=~/.local/share/fcitx5/rime
   mapfile -t names < <(find ${src_dir}/rime-wubi86s -type f -name "*.yaml" \
      -exec basename '{}' \;)
   for n in ${names[@]}; do
      if [[ -f ${rime_dir}/${n} ]]; then
         cp -f ${rime_dir}/${n} ${src_dir}/rime-wubi86s/ 
      fi
   done
   echo "==> merged '$(tilde_path ${src_dir}/rime-wubi86s)/*.yaml'"
}

case "$1" in
   install)
      shift
      names=$(test_names "$@")
      [[ -n "$names" ]] || errf "empty names"
      for n in ${names[@]}; do
         case "$n" in
            lite-xl)
               install_lite_xl_config
               ;;
            rime-wubi86s|rime)
               install_rime_wubi86s
               ;;
            *)
               install_config $n
               ;;
         esac
      done
      ;;
   merge)
      shift
      names=$(test_names "$@")
      [[ -n "$names" ]] || errf "empty names"
      for n in ${names[@]}; do
         case "$n" in
            lite-xl)
               merge_lite_xl_config
               ;;
            rime-wubi86s|rime)
               merge_rime_wubi86s
               ;;
            *)
               merge_config $n
               ;;
         esac
      done
      ;;
   *)
      errf "Usage: $(basename $0) <install|merge>"
      ;;
esac

