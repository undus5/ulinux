#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }
get_help() { errf "==> usage: $(basename $0) <on|off|switch|test>"; }

[[ -z "$1" || "$1" == "-h" ]] && get_help

################################################################################

URL="https://google.com/generate_204"

if [[ "$1" == "test" ]]; then
   echo "==> testing '$URL'"
   curl -sL -w "%{http_code}" -o /dev/null $URL
   printf "\n"
   exit 0
fi

################################################################################

[[ "$EUID" == "0" ]] || errf "need root priviledge"

################################################################################

if [[ "$1" == "off" ]]; then
   cd /usr/local/etc/
   ln -sf ./utpl/smartdns-compromise.conf ./smartdns.conf
   systemctl restart smartdns
   nft list table ip utun &>/dev/null && nft delete table ip utun
   exit 0
fi

if [[ "$1" == "on" ]]; then
   cd /usr/local/etc/
   ln -sf ./utpl/smartdns-bypass.conf ./smartdns.conf
   systemctl restart smartdns
   nft list table ip utun &>/dev/null || nft -f ./utun.nft
   exit 0
fi

################################################################################

[[ "$1" == "switch" ]] || get_help

srv_name="$2"
[[ -n "${srv_name}" ]] || errf "Usage: $(basename $0) <srv_name>"

cd /usr/local/etc/
naive_conf=./utun.d/naiveproxy-${srv_name}.json
gostu_conf=./utun.d/gost-uot-${srv_name}.yaml

[[ -f $naive_conf ]] || errf "file not found: $(realpath $naive_conf)"
[[ -f $gostu_conf ]] || errf "file not found: $(realpath $gostu_conf)"

ln -sf $naive_conf ./naiveproxy.json
echo "==> linked '$(basename $naive_conf)' to 'naiveproxy.json'"
ln -sf $gostu_conf ./gost-uot-tproxy.yaml
echo "==> linked '$(basename $gostu_conf)' to 'gost-uot-tproxy.yaml'"

systemctl restart naiveproxy@* gost-uot-tproxy@* gost-tcp-tproxy@* smartdns
echo "==> reloaded services"
