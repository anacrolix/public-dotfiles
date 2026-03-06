#!/bin/sh
iptables -I FORWARD -d 192.168.0.0/16 -j DROP
iptables -I FORWARD -d 10.0.0.0/8 -j DROP
iptables -I FORWARD -d 172.16.0.0/12 -j DROP
tail -f /dev/null  # keep container alive
