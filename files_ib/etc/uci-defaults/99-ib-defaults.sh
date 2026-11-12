#!/bin/sh
# ImageBuilder 出包专用首启初始化（源码编译那条走 diy-part2.sh + files/）
# 只设置几项最基础的东西，避免和源码版的两套逻辑互相干扰

uci set network.lan.ipaddr='192.168.100.1' 2>/dev/null || true
uci set network.lan.netmask='255.255.255.0' 2>/dev/null || true
uci set system.@system[0].hostname='ImmortalWrt' 2>/dev/null || true
uci set system.@system[0].timezone='CST-8' 2>/dev/null || true
uci commit network 2>/dev/null || true
uci commit system 2>/dev/null || true

# 关掉 WAN 口的 IPv6（用户偏好纯 IPv4 局域网）
[ -f /etc/sysctl.d/99-ipv4-only.conf ] || {
  echo 'net.ipv6.conf.all.disable_ipv6=1' > /etc/sysctl.d/99-ipv4-only.conf
  echo 'net.ipv6.conf.default.disable_ipv6=1' >> /etc/sysctl.d/99-ipv4-only.conf
}

exit 0
