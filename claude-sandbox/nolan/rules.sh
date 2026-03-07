#!/bin/sh
set -e

# Allow the sandbox's own docker network (must come before the 10.0.0.0/8 block)
iptables -A OUTPUT -d 10.69.0.0/24 -j ACCEPT

# Allow Docker Desktop's internal subnet — this is how host.docker.internal
# (192.168.65.254) is reached, needed to access services on the macOS host
# such as a local API proxy. This is Docker's internal network, not the LAN.
iptables -A OUTPUT -d 192.168.65.0/24 -j ACCEPT

# Block RFC1918 private networks — prevents sandbox from reaching host LAN
iptables -A OUTPUT -d 192.168.0.0/16 -j REJECT --reject-with icmp-net-prohibited
iptables -A OUTPUT -d 10.0.0.0/8     -j REJECT --reject-with icmp-net-prohibited
iptables -A OUTPUT -d 172.16.0.0/12  -j REJECT --reject-with icmp-net-prohibited

# Defence in depth: also reject in FORWARD chain
iptables -A FORWARD -d 192.168.0.0/16 -j REJECT --reject-with icmp-net-prohibited
iptables -A FORWARD -d 10.0.0.0/8     -j REJECT --reject-with icmp-net-prohibited
iptables -A FORWARD -d 172.16.0.0/12  -j REJECT --reject-with icmp-net-prohibited

tail -f /dev/null  # keep container alive
