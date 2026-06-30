#!/usr/bin/bash

errf() { printf "$@\n" >&2; exit 1; }

[[ "$EUID" == "0" ]] || errf "need root priviledge"

ip route del local default table 100 &>/dev/null
ip route add local default dev lo table 100

ip rule del fwmark 1 &>/dev/null
ip rule add fwmark 1 table 100
