# Mihomo 策略与分流

仅在目标应用实际使用 Mihomo 且支持相应配置时采用。GUI 的 Script.js/merge 扩展还需单独确认，不能因同为 Mihomo 就假设具有 Clash Verge 的扩展入口。其他客户端见 [客户端适配](client-adaptation.md)。

记录实际内核版本，不能用 GUI 版本替代。审计原始订阅、active profile、全局/订阅 Script.js、merge、最终配置和控制器状态，确认规则来源。

| 组 | 语义 |
|---|---|
| PROXY/select | 统一入口、用户选择；持久化选择可能覆盖首成员 |
| AUTO/url-test | 探测延迟与 tolerance 等决定选择，不等于吞吐排行 |
| FAILOVER/fallback | 按顺序与健康检查故障切换；间隔和恢复行为按版本实测 |

节点顺序按用户需求；检查引用/循环/排除/probe URL/interval/lazy 和实际选择。跨网络使用时，优先把 TCP/443 + TLS/REALITY 节点放在 FAILOVER 首位；UDP/QUIC、非标准端口或无 TLS 节点作为补充，按目标网络实测排序，不能只在 Wi-Fi 测速后固定顺序。

## Clash Verge Rev / 服务模式

- 本机只读盘点 Clash 服务、核心、后台监控及临时测试进程的 PID、父进程、可执行文件名/路径、脱敏命令行和监听。检查实际版本的服务启动策略；同名核心即使使用不同目录、端口也可能使服务拒绝启动。记录所有者，不以名称模糊杀进程或擅停监控；需要改隔离策略时先验证不影响运行中的应用、原设置与回滚。

- GUI 版本不等于实际内核版本；从应用“关于/内核”或控制器读取实际 Mihomo 版本。
- 服务模式与 sidecar 模式的配置路径、控制器和运行配置可能不同；应用生成的 `clash-verge.yaml` 是产物，不是唯一运行配置。不要手改生成文件。
- 修改优先走应用支持的 Script.js/merge；需要控制器时先备份，确认实际 secret/pipe，`PUT /configs?force=true` 的 payload 必须是完整配置；不要假设 path reload 在所有模式可用。
- 控制器可能只暴露命名管道；从实际配置读取 `external-controller-pipe`，不要硬编码机器特定名称。服务 runtime 与生成文件可能不一致；内核单独重启后可能回到旧 runtime，需要在应用内重新应用 profile 并核对。
- 应用后核对 `/rules`、`/providers/rules`、`/configs`、`/proxies` 和真实请求；TUN/系统代理状态单独记录，不能由“订阅已更新”推断。
- provider 更新失败可能沿用缓存；首次无缓存时规则可能缺失。核对 `updatedAt`、`ruleCount` 和冷启动行为，不把“配置解析通过”当成规则完整。
- 系统代理模式下，应用自行解析的 DNS 可能绕过 Mihomo DNS；不能承诺零泄漏，必要时用真实查询/命中记录说明限制。

每次优化调研 [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat)、[blackmatrix7](https://github.com/blackmatrix7/ios_rule_script)、[ACL4SSR](https://github.com/ACL4SSR/ACL4SSR) 及 [Loyalsoldier](https://github.com/Loyalsoldier/clash-rules) 等历史源当前维护状态。记录 commit/日期/License/分类/生成来源/MRS或YAML格式/behavior/大小/更新路径；聚合仓库许可不自动覆盖上游数据。

优先成熟规则集，少量显式补充并去重，防止大分类遮住细分类。建议顺序：私网→必要国内镜像例外→AI/开发/认证/CDN→海外→国内分类→GEOIP,CN,DIRECT→MATCH,PROXY。国内优先 DIRECT，未知国内通过 DNS/GEOIP 尽可能识别，未知海外代理；未分类不能默认 REJECT 或 DIRECT。忠实迁移与明确优化区别见 SKILL.md。

接入网络是校园网/企业/酒店网页认证时，先交互确认是否需要“认证门户直连”模式，并收集用户确认的门户地址段与认证/自助域名；不预置或沿用其他学校的 IP/域名。需要时把门户 CIDR 加入 `tun.route-exclude-address`，并加 `IP-CIDR,<portal-cidr>,DIRECT,no-resolve` 与 `DOMAIN-SUFFIX,<auth-domain>,DIRECT`，置于代理与国内分类规则之前。认证站点即使解析到公网也要显式直连，否则会被送进海外节点并按海外来源重置。完整流程、验证与回滚见 [campus-portal.md](campus-portal.md)。

生产 Script.js → 独立候选 → 实际输入转换 → 隔离 Mihomo → 审查 diff/测试 → 用户批准 → 更新生产脚本 → 应用重生成 → 实际验收。不要手改生成 YAML。执行脚本先审查；Node VM 不是安全沙箱。

隔离端口/controller/DNS/缓存，关闭测试 TUN，不改系统代理，不复用生产 PID/缓存。测 provider 冷启动、更新、失败/缓存路径、格式、组/规则引用；首次无缓存不可假设下载失败能继续使用。请求期间记录 connections 的 rule/chains，并独立记录 HTTP/应用结果。

取样国内、未收录国内、未收录海外、AI/OAuth、开发依赖/镜像和真实下载。下载根路径 403/404 不证明文件可下载；广告 REJECT 是单独可选需求。至少在目标 Wi-Fi 与蜂窝各验证一次订阅更新和手动选点；本地命中或端口探测不代表移动网络可用。备份脚本/merge/选择，更新后核对 hash、版本、数量、解析、命中、出口。DNS 见 [dns-design.md](dns-design.md)，规则语义核对[官方文档](https://wiki.metacubex.one/config/rules/)。
