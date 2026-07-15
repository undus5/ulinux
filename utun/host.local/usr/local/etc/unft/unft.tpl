#!/bin/nft -f

# arch /etc/nftables.conf
# fedora /etc/sysconfig/nftables.conf
#include "/usr/local/etc/utun.nft"

table ip utun {

   set ipset1 {
      type ipv4_addr; flags constant, interval; auto-merge
      elements = {
         127.0.0.0/8,
         10.0.0.0/8,
         172.16.0.0/12,
         192.168.0.0/16,
         _IPSET1_
      }
   }

   set ipset2 {
      type ipv4_addr; flags constant, interval; auto-merge
      elements = {
         _IPSET2_
      }
   }

   chain route_output {
      type route hook output priority filter
      ip daddr @ipset1 return
      ip daddr @ipset2 return
      meta l4proto { tcp, udp } meta mark set 1
   }

   chain filter_prerouting {
      type filter hook prerouting priority filter
      meta mark 1 ip daddr @ipset1 return
      meta mark 1 ip daddr @ipset2 return
      meta mark 1 meta l4proto { tcp, udp } tproxy to :1025
   }

}
