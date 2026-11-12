#!/bin/bash
#
# diy-part1.sh —— 在 ./scripts/feeds update -a 之前执行
# 工作目录：ImmortalWrt 源码根目录
# 作用：把第三方插件源码放进 package/，让后续 feeds install / make defconfig 能扫描到
#
# 说明：这里不用 src-git feed 的方式引入，而是逐个 clone 后按需拷贝，
#       原因是 helloworld / passwall-packages 里有很多包与 ImmortalWrt 官方
#       feeds 重名（xray-core、v2ray-core、shadowsocks-rust、chinadns-ng 等），
#       以 feed 形式引入会在 metadata 扫描阶段产生 duplicate package name。
#
set -e
SRC=/tmp/openwrt-diy-src
rm -rf "$SRC"
mkdir -p "$SRC"
# 先清理同名包，避免和 feeds 里的包发生同名冲突
rm -rf package/luci-app-run package/luci-app-partexp package/luci-app-quickfile \
       package/quickfile package/luci-theme-aurora package/luci-theme-vantage \
       package/clashoo package/luci-app-clashoo \
       package/luci-app-passwall2 \
       package/luci-app-ssr-plus package/lua-neturl package/dns2tcp \
       package/microsocks package/shadowsocksr-libev
git_diy() { git clone --depth 1 -b "$2" "$1" "$3"; }
# 1) luci-app-run —— Run 安装器（.run 包安装，兼容 25.12 的 apk）
git_diy https://github.com/wukongdaily/luci-app-run.git master "$SRC/run"
cp -rf "$SRC/run/luci-app-run" package/
# 2) luci-app-quickfile —— LuCI 页面 + quickfile 主程序（Rust/Axum）
#    仓库里是两个独立包，只拷 LuCI 页面会因 +quickfile 依赖不满足被 defconfig 清掉
git_diy https://github.com/sbwml/luci-app-quickfile.git main "$SRC/quickfile"
cp -rf "$SRC/quickfile/luci-app-quickfile" "$SRC/quickfile/quickfile" package/
# 3) luci-app-partexp —— 分区扩容
git_diy https://github.com/sirpdboy/luci-app-partexp.git main "$SRC/partexp"
cp -rf "$SRC/partexp/luci-app-partexp" package/
# 4) luci-theme-aurora —— 仓库根目录本身就是包
git_diy https://github.com/eamonxg/luci-theme-aurora.git master package/luci-theme-aurora
rm -rf package/luci-theme-aurora/.git
# 5) luci-theme-vantage —— 只取主题；luci-app-vantage 是可选仪表盘，未启用
git_diy https://github.com/anothaDev/luci-theme-vantage.git main "$SRC/vantage"
cp -rf "$SRC/vantage/luci-theme-vantage" package/
# 6) clashoo —— 核心 + LuCI 插件（两个包都要）
git_diy https://github.com/kenzok8/openwrt-clashoo.git main "$SRC/clashoo"
cp -rf "$SRC/clashoo/clashoo" "$SRC/clashoo/luci-app-clashoo" package/
# 7) PassWall2 —— 只要 LuCI 插件；内核（xray-core 等）由 ImmortalWrt 官方 feeds 提供
git_diy https://github.com/Openwrt-Passwall/openwrt-passwall2.git main "$SRC/passwall2"
cp -rf "$SRC/passwall2/luci-app-passwall2" package/
# 8) helloworld 的若干小包（dns2tcp / microsocks / shadowsocksr-libev / lua-neturl）
#    这些是 passwall2 等运行时可能用到的辅助组件，本身不含 rust，保留。
#    注意：不再拷 luci-app-ssr-plus —— 它是唯一会牵扯 rust 生态的应用，
#    而 feeds/packages/lang/rust 1.96.0 的 host 编译要从 ci 拉预编译 LLVM（已 404），
#    每轮固定在 2h44m 处失败（run #4）。代理能力由 passwall2（Xray 内核）覆盖。
git_diy https://github.com/fw876/helloworld.git master "$SRC/helloworld"
cp -rf "$SRC/helloworld/lua-neturl" \
       "$SRC/helloworld/dns2tcp" \
       "$SRC/helloworld/microsocks" \
       "$SRC/helloworld/shadowsocksr-libev" package/
# 说明：luci-theme-argon 由 ImmortalWrt 官方 luci feeds（themes/luci-theme-argon）自带，
#       不额外克隆，避免同名冲突
echo "==== 已注入 package/ 的第三方包 ===="
ls -1 package | grep -E '^(luci-|clashoo|quickfile|dns2tcp|microsocks|shadowsocksr-libev)' | sort || true
rm -rf "$SRC"
