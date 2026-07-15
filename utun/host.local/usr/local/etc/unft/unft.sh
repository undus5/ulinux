#!/bin/bash

set -e

self_dir=$(dirname $(realpath ${BASH_SOURCE[0]}))

# https://raw.githubusercontent.com/17mon/china_ip_list\
# /refs/heads/master/china_ip_list.txt
china_ip_file=${self_dir}/china_ip_list.txt
nft_tpl_file=${self_dir}/unft.tpl
hosts_file=/etc/hosts

indent_list() {
   sed -i -e '/^$/d' \
      -e '/.*:.*/d' \
      -e 's/^/         /g' -e 's/$/,/g' \
      $1
}

host_ip_tmp=$(mktemp -t host-ip-XXX.txt)
sed -e "/^$/d" -e "/^#/d" -e "/^127./d" -e "/^::1/d" $hosts_file \
   | awk '{print $1}' | uniq > $host_ip_tmp
indent_list $host_ip_tmp

china_ip_tmp=$(mktemp -t china-ip-XXX.txt)
cat $china_ip_file > $china_ip_tmp
indent_list $china_ip_tmp

nft_tmp=$(mktemp -t utun-XXX.nft)
cat $nft_tpl_file > $nft_tmp

placeholder1="_IPSET1_"
placeholder2="_IPSET2_"

sed -i "/${placeholder1}/r ${host_ip_tmp}" $nft_tmp
sed -i "/${placeholder2}/r ${china_ip_tmp}" $nft_tmp

sed -e "/${placeholder1}/d" -e "/${placeholder2}/d" $nft_tmp

rm $host_ip_tmp
rm $china_ip_tmp
rm $nft_tmp
