#!/bin/bash

set -e

errf() { printf "$@\n" >&2; exit 1; }

if [[ -z "$1" || "$1" == "-h" ]]; then
   errf "==> usage: $(basename $0) <-s|-tx|-t>"
fi

# https://docs.x.com/make-your-first-request
URL="https://api.x.com/2/users/by/username/xdevelopers"

if [[ "$1" == "-tx" ]]; then
   echo "==> testing with proxy '$URL'"
   curl -sL -x http://127.0.0.1:8080 -U user:pass $URL | jq '.status'
   exit 0
fi

if [[ "$1" == "-t" ]]; then
   echo "==> testing '$URL'"
   curl -sL $URL | jq '.status'
   exit 0
fi

[[ "$EUID" == "0" ]] || errf "need root priviledge"

srv_name=${1}
[[ -n "${srv_name}" ]] || errf "Usage: $(basename $0) <srv_name>"

cd /usr/local/etc/
naive_conf=./utun-pool/naiveproxy-${srv_name}.json
gostu_conf=./utun-pool/gost-uot-${srv_name}.yaml

[[ -f $naive_conf ]] || errf "file not found: $(realpath $naive_conf)"
[[ -f $gostu_conf ]] || errf "file not found: $(realpath $gostu_conf)"

ln -sf $naive_conf ./naiveproxy.json
echo "==> linked '$(basename $naive_conf)' to 'naiveproxy.json'"
ln -sf $gostu_conf ./gost-uot-tproxy.yaml
echo "==> linked '$(basename $gostu_conf)' to 'gost-uot-tproxy.yaml'"

systemctl restart naiveproxy@* gost-uot-tproxy@* gost-tcp-tproxy@* smartdns
echo "==> reloaded services"
