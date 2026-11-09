#!/bin/bash
#
# diy-part2.sh —— 在 ./scripts/feeds install -a 且载入 .config 之后执行
# 工作目录：ImmortalWrt 源码根目录
# 作用：版本标识、默认 IPv4 单栈、默认主题、LAN 地址等源码级定制
#
set -e
# 1) 版本标识 25.12.2
#    ImmortalWrt openwrt-25.12 的 include/version.mk 默认写 25.12-SNAPSHOT，
#    这里统一替换成 25.12.2（VERSION_NUMBER 与 VERSION_REPO 一起生效）
sed -i 's/25\.12-SNAPSHOT/25.12.2/g' include/version.mk
# 2) 默认 IPv4 单栈：首次启动不生成 wan6 / ip6assign / IPv6 DNS
#    ImmortalWrt 的 config_generate 全部靠 [ -e /proc/sys/net/ipv6 ] 判断
sed -i 's|\[ -e /proc/sys/net/ipv6 \]|[ -e /proc/sys/net/ipv6-disabled ]|g' \
    package/base-files/files/bin/config_generate
# 3) 运行时全局禁用 IPv6
#    /etc/init.d/sysctl 的 start() 会依次读取 /etc/sysctl.d/*.conf 与 /etc/sysctl.conf，
#    且 sysctl.conf 最后应用。这里两处都写，保证不会被官方默认值覆盖。
mkdir -p package/base-files/files/etc/sysctl.d
cat > package/base-files/files/etc/sysctl.d/99-ipv4-only.conf <<'EOF'
# IPv4-only: 内核 IPv6 模块照常编译（nftables 打包依赖），但不允许任何接口启用 IPv6
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.default.forwarding=0
EOF
if ! grep -q 'IPv4-only' package/base-files/files/etc/sysctl.conf; then
cat >> package/base-files/files/etc/sysctl.conf <<'EOF'

# IPv4-only（本仓库定制）：
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
net.ipv6.conf.all.forwarding=0
net.ipv6.conf.default.forwarding=0
EOF
fi
# 4) 默认 LAN 地址 192.168.100.1（与现有局域网的 192.168.100.0/24 保持一致）
sed -i "s/192\.168\.1\.1/192.168.100.1/" package/base-files/files/bin/config_generate
# 5) 默认主题改为 Argon
#    ImmortalWrt 的 luci collections 默认依赖 luci-theme-bootstrap，替换为 argon，
#    这样不装 bootstrap 也能保证 luci 元包完整
if [ -d feeds/luci/collections ]; then
  find feeds/luci/collections -name Makefile \
    -exec sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' {} \;
fi
# 6) 时区设为中国标准时间
sed -i "s/timezone='GMT0'/timezone='CST-8'/" package/base-files/files/bin/config_generate
# 7) PassWall2 依赖修正
#    ImmortalWrt 25.12 的 feeds 里：
#      - 没有 lyaml（上游已不再提供），metadata 扫描会判为 "which does not exist"，
#        make defconfig 会把 luci-app-passwall2 整包清掉
#      - v2ray-geoip / v2ray-geosite 已合并为 v2ray-geodata
python3 - <<'PY'
import pathlib
path = 'package/luci-app-passwall2/Makefile'
f = pathlib.Path(path)
if not f.is_file():
    print('::warning::%s 不存在，跳过依赖修正' % path)
else:
    lines = f.read_text().splitlines(keepends=True)
    out, i, done = [], 0, False
    while i < len(lines):
        line = lines[i]
        if not done and line.lstrip().startswith('LUCI_DEPENDS:='):
            indent = line[:len(line) - len(line.lstrip())]
            block = [line.rstrip('\n')]
            while block[-1].rstrip().endswith('\\') and i + 1 < len(lines):
                i += 1
                block.append(lines[i].rstrip('\n'))
            joined = ' '.join(b.rstrip('\\').strip() for b in block)
            if joined.startswith('LUCI_DEPENDS:='):
                joined = joined[len('LUCI_DEPENDS:='):]
            if '+lyaml' in joined:
                joined = joined.replace('+lyaml ', '').replace(' +lyaml', '')
            if '+v2ray-geoip' in joined or '+v2ray-geosite' in joined:
                joined = joined.replace('+v2ray-geoip', '+v2ray-geodata')
                joined = joined.replace('+v2ray-geosite', '')
            joined = ' '.join(joined.split())
            out.append(indent + 'LUCI_DEPENDS:=' + joined + '\n')
            done = True
            i += 1
            continue
        out.append(line)
        i += 1
    f.write_text(''.join(out))
    print('passwall2: LYAML/geoip 依赖已修正 -> %s' % joined)
PY
# 8) uci-defaults 脚本需要可执行权限（files/ 里的权限会被原样打包进镜像）
if [ -d files/etc/uci-defaults ]; then
  chmod +x files/etc/uci-defaults/* 2>/dev/null || true
fi
echo "==== 定制结果自检 ===="
grep -n '25\.12\.2' include/version.mk | head -3 || true
echo -n "config_generate 已屏蔽的 IPv6 判断数："
grep -c '/proc/sys/net/ipv6-disabled' package/base-files/files/bin/config_generate || true
echo -n "默认 LAN 地址："
grep -o '192\.168\.100\.1' package/base-files/files/bin/config_generate | head -1 || true
echo -n "默认主题依赖："
grep -ho 'luci-theme-[a-z]*' feeds/luci/collections/*/Makefile 2>/dev/null | sort -u | tr '\n' ' ' || true
echo
cat package/base-files/files/etc/sysctl.d/99-ipv4-only.conf
echo "diy-part2 done."
