# 官方项目调研与架构

每次部署/升级重新调研：记录检索日期、仓库、目标 tag/commit、最近 Release/提交、相关未解决 Issue、安全公告/修复版本、tag 内 LICENSE、资产架构/CPU 指令要求、官方摘要来源和实算摘要、实际客户端兼容测试。访问失败记未核实，不能写没有漏洞；不根据 Star 决定。

优先 [Xray-core](https://github.com/XTLS/Xray-core)、[sing-box](https://github.com/SagerNet/sing-box)、[Hysteria](https://github.com/HyNetworks/hysteria)、[Mihomo](https://github.com/MetaCubeX/mihomo)、[shadowsocks-rust](https://github.com/shadowsocks/shadowsocks-rust)。其他实现核对协议规范、维护者与迁移关系。查看 Releases、commits、相关 issues、Security advisories 和许可证，不能只看 README。

从官方 HTTPS Release 下载固定资产，以官方 checksum/signature 验证；自行计算 hash 不证明来源。摘要不符停止。检查架构/AVX、压缩包路径后才安装。不用来源不明的一键脚本；官方安装器也需固定 commit、审阅及校验。

| 协议 | 选择与验证点 |
|---|---|
| VLESS + REALITY | 保留可用 TCP 基线；目标站可达、UUID/X25519/short ID、SNI/flow/fingerprint 匹配；私钥只在服务端 |
| Hysteria 2 | UDP/QUIC 可用性、TLS、实际拥塞配置；TCP 通不代表 UDP 通 |
| AnyTLS | 指定服务端实现与 Mihomo 版本的协议/认证/TLS 支持；参考实现不等于集成核心成熟度 |
| Shadowsocks 2022 | cipher/密钥长度与 TCP/UDP；不能套用 TLS 证书要求 |
| TUIC | 具体实现、协议版本、当前维护与兼容性；不永久照搬某次停更结论 |
| Trojan | TLS、端口复用、TCP/UDP及功能重叠 |
| WireGuard | 密钥、路由、MTU、UDP及全隧道/出站用途；不默默改本机 TUN/默认路由 |

列出网络环境、CPU/RAM/磁盘/带宽预算、认证、端口、进程故障域和回滚点。复用成熟核心；多个 inbound 同进程共用故障域。逐协议加入、测通再继续，不迁移原有可用服务。历史小内存实例成功不保证其他并发安全。

Hysteria 在用户态实现 QUIC 拥塞控制，Linux tcp_congestion_control 只控制内核 TCP。具体 BBR/Brutal/其他算法及带宽协商按运行 tag、配置和[官方文档](https://v2.hysteria.network/docs/advanced/Full-Server-Config/)核对。
