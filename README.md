# Actions-ImmortalWrt-X86

用 GitHub Actions 编译 **ImmortalWrt x86/64** 固件。仓库结构沿用 [ywgf88/Actions-OpenWrt-X86](https://github.com/ywgf88/Actions-OpenWrt-X86)（P3TERX/Actions-OpenWrt 模板思路），源码改成 ImmortalWrt 官方的 `openwrt-25.12` 分支。

## 编译产物

| 项目 | 值 |
|---|---|
| 源码 | `https://github.com/immortalwrt/immortalwrt` |
| 分支 | `openwrt-25.12` |
| 版本标识 | **25.12.2**（改写 `include/version.mk`，文件名里也是 25.12.2） |
| 目标 | x86/64 Generic（ext4 + squashfs，GRUB BIOS + GRUB EFI） |
| rootfs 分区 | **1024 MiB（1G）**，Kernel 分区 64 MiB |
| 默认网络 | **IPv4**：不生成 wan6 / ip6assign / IPv6 DNS，运行时全局 `disable_ipv6=1` |
| 默认 LAN | `192.168.100.1` |

## 插件清单

| 插件 | 来源 |
|---|---|
| luci-app-run | [wukongdaily/luci-app-run](https://github.com/wukongdaily/luci-app-run) |
| luci-app-quickfile（含 quickfile 主程序） | [sbwml/luci-app-quickfile](https://github.com/sbwml/luci-app-quickfile) |
| luci-theme-aurora | [eamonxg/luci-theme-aurora](https://github.com/eamonxg/luci-theme-aurora) |
| luci-app-partexp | [sirpdboy/luci-app-partexp](https://github.com/sirpdboy/luci-app-partexp) |
| PassWall2（只编 Xray 内核 + Nftables 透明代理） | [Openwrt-Passwall/openwrt-passwall2](https://github.com/Openwrt-Passwall/openwrt-passwall2) |
| SSR Plus（ssrp，Nftables + Xray + ShadowSocksR-libev + SS-rust 客户端） | [fw876/helloworld](https://github.com/fw876/helloworld) |
| Clashoo（核心 + LuCI） | [kenzok8/openwrt-clashoo](https://github.com/kenzok8/openwrt-clashoo) |
| Docker + luci-app-dockerman | ImmortalWrt 官方 feeds（`utils/docker`） |
| luci-app-diskman | ImmortalWrt 官方 feeds |
| luci-theme-argon（默认主题） | ImmortalWrt 官方 feeds（`themes/luci-theme-argon`） |
| luci-theme-vantage | [anothaDev/luci-theme-vantage](https://github.com/anothaDev/luci-theme-vantage) |

## 目录结构

```
.github/workflows/openwrt-builder.yml   # 编译流程
.config                                 # 编译配置（目标/分区/插件/主题）
feeds.conf.default                      # ImmortalWrt 官方 feeds
diy-part1.sh                            # feeds update 前：拉第三方插件源码到 package/
diy-part2.sh                            # 加载 .config 后：版本号、IPv4 单栈、主题、依赖修正
files/etc/uci-defaults/99-immortalwrt-x86-defaults   # 首次启动默认主题/语言
```

## 怎么用

1. 仓库 **Settings → Actions → General → Workflow permissions** 选 **Read and write permissions** 并保存。
   不设的话编译能过，但最后上传 Release 会 403（`Resource not accessible by integration`），固件只能在 run 页的 Artifacts 里下载。
2. **Actions → ImmortalWrt Builder X86 → Run workflow**，分支选默认分支即可。
3. 编译耗时实测 **2 小时 52 分**（4 线程 runner，含 Docker/Go 包；其中 `Compile the firmware` 占 2h41m）。结束后：
   - 固件在 **Releases** 里（`*.img.gz`、`*rootfs.tar.gz`、`*sysupgrade*`）
   - 中间产物在本次 run 的 **Artifacts** 里
4. 刷机：x86 软路由用 `*-combined-efi.img.gz`（UEFI 启动）或 `*-combined.img.gz`（BIOS 启动）。

## 关键定制说明

**版本号 25.12.2**：ImmortalWrt 把版本配置从 Kconfig 移到了 `include/version.mk`，所以不用 `CONFIG_VERSION_NUMBER`，而是 `diy-part2.sh` 里把 `25.12-SNAPSHOT` 全量替换成 `25.12.2`（版本号与 apk/opkg 源地址一起生效，指向 `downloads.immortalwrt.org/releases/25.12.2`）。

**默认 IPv4**：内核 `CONFIG_IPV6` 保持开启（ImmortalWrt 里是 `def_bool y` 强制符号，且 nftables 的 kmod 打包引用了 `net/ipv6/netfilter/*.ko`，关掉会编译失败）。"默认 IPv4"落在运行时：
- `config_generate` 里所有 `[ -e /proc/sys/net/ipv6 ]` 判断改成 `[ -e /proc/sys/net/ipv6-disabled ]`，首次启动不会生成 wan6 / ip6assign / IPv6 DNS；
- `/etc/sysctl.d/99-ipv4-only.conf` 与 `/etc/sysctl.conf` 都写入 `disable_ipv6=1`（`/etc/init.d/sysctl` 会先读 sysctl.d 再读 sysctl.conf，两处都写才不会被覆盖）。

**第三方插件不走 feed**：`passwall-packages`、`helloworld` 里有大量包与 ImmortalWrt 官方 feeds 重名（xray-core、v2ray-core、shadowsocks-rust、chinadns-ng…），以 `src-git` 引入会在 metadata 扫描阶段出现 duplicate package name。所以 `diy-part1.sh` 逐个 clone、只拷贝需要的包。

**PassWall2 依赖修正**：上游 `LUCI_DEPENDS` 里的 `lyaml` 在 ImmortalWrt 25.12 的 feeds 中已经不存在，`v2ray-geoip` / `v2ray-geosite` 也已合并成 `v2ray-geodata`。不修正的话 `make defconfig` 会把 `luci-app-passwall2` 整包清掉。`diy-part2.sh` 用 python 就地改写这段依赖。

**编译前先校验，不白等两小时**：`Verify configuration` 步骤在 `make defconfig` 后会做三件事——把 defconfig 里 `which does not exist` 的依赖缺失告警打成 `::error::`；逐个检查上面 15 个必需包是否真的被选中；检查版本号、rootfs 分区、IPv4 配置文件是否到位。任何一项不通过就直接失败，不会编出一个少插件的固件。

## 注意

- **三个分流工具同时装会互相抢 nftables 规则/端口**（PassWall2、SSR Plus、Clashoo）。同时编译进去只是为了都在固件里可选，实际用的时候只开一个。
- **SSR Plus 里的「Shadowsocks-libev」模式不可用**：ImmortalWrt 25.12 的 feeds 已经把 shadowsocks-libev 拆体包（`ss-local`/`ss-redir`/`ss-server`）移出，所以 `.config` 里显式关掉了 libev 客户端/服务端选项。可用的协议是 **ShadowSocksR-libev、Shadowsocks-rust、Xray**；`make defconfig` 里会看到几条 `shadowsocks-libev-ss-* which does not exist` 的告警，属于已知无害项，工作流的 Verify 步骤会识别并放行。
- 首次进后台：默认主题 Argon（Vantage / Aurora 可在「系统 → 语言和界面」里切换），语言中文，LAN `192.168.100.1`，默认账号 root。
- rootfs 已放大到 1G，装 Docker 镜像够用；真不够再用 `luci-app-partexp` 或 DiskMan 扩分区。

## 首次编译验证（2026-11-09）

| 项目 | 结果 |
|---|---|
| Actions run | [#1](https://github.com/ywgf88/Actions-ImmortalWrt-X86/actions/runs/42571491204)，`succeeded in 2h 52m 5s` |
| 关键步骤 | Init 2m37s → Clone 27s → feeds 52s+30s → Verify 33s → Download 4m11s → **Compile 2h41m50s** → Upload/Release 42s+17s |
| Release | 标签 `2026.11.09-1702`，17 个 asset |
| 主力固件 | `immortalwrt-x86-64-generic-squashfs-combined-efi.img.gz`（146 MB）、`immortalwrt-x86-64-generic-ext4-combined-efi.img.gz`（184 MB），另有 `-combined`（BIOS 引导）、`-rootfs.img.gz`、`kernel.bin`、`rootfs.tar.gz` |
| 配置核对 | Release 内 `config.buildinfo`：`CONFIG_TARGET_ROOTFS_PARTSIZE=1024`、`CONFIG_TARGET_KERNEL_PARTSIZE=64`、`CONFIG_TARGET_x86_64_DEVICE_generic=y`，15 个必需包全部 `=y` |
| 版本号核对 | `Load custom configuration` 日志：`VERSION_NUMBER ... 25.12.2`、`VERSION_REPO ... releases/25.12.2`、`config_generate 已屏蔽的 IPv6 判断数：4`、`默认 LAN 地址：192.168.100.1` |
| 注解 | 5 条 `WARNING` annotation，全部是 ssr-plus 对 shadowsocks-libev 拆体包的可选依赖缺失，属已知无害项 |

体验提示：`Upload firmware to release` 依赖 **Settings → Actions → General → Workflow permissions = Read and write**；这一项没设时编译能全绿、Release 却会 403，固件只剩 Artifacts。
