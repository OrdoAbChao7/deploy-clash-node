# Mihomo 策略与分流

仅在目标应用实际使用 Mihomo 且支持相应配置时采用。GUI 的 Script.js/merge 扩展还需单独确认，不能因同为 Mihomo 就假设具有 Clash Verge 的扩展入口。其他客户端见 [客户端适配](client-adaptation.md)。

记录实际内核版本，不能用 GUI 版本替代。审计原始订阅、active profile、全局/订阅 Script.js、merge、最终配置和控制器状态，确认规则来源。

| 组 | 语义 |
|---|---|
| PROXY/select | 统一入口、用户选择；持久化选择可能覆盖首成员 |
| AUTO/url-test | 探测延迟与 tolerance 等决定选择，不等于吞吐排行 |
| FAILOVER/fallback | 按顺序与健康检查故障切换；间隔和恢复行为按版本实测 |

节点顺序按用户需求；检查引用/循环/排除/probe URL/interval/lazy 和实际选择。

每次优化调研 [meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat)、[blackmatrix7](https://github.com/blackmatrix7/ios_rule_script)、[ACL4SSR](https://github.com/ACL4SSR/ACL4SSR) 及 [Loyalsoldier](https://github.com/Loyalsoldier/clash-rules) 等历史源当前维护状态。记录 commit/日期/License/分类/生成来源/MRS或YAML格式/behavior/大小/更新路径；聚合仓库许可不自动覆盖上游数据。

优先成熟规则集，少量显式补充并去重，防止大分类遮住细分类。建议顺序：私网→必要国内镜像例外→AI/开发/认证/CDN→海外→国内分类→GEOIP,CN,DIRECT→MATCH,PROXY。国内优先 DIRECT，未知国内通过 DNS/GEOIP 尽可能识别，未知海外代理；未分类不能默认 REJECT 或 DIRECT。忠实迁移与明确优化区别见 SKILL.md。

生产 Script.js → 独立候选 → 实际输入转换 → 隔离 Mihomo → 审查 diff/测试 → 用户批准 → 更新生产脚本 → 应用重生成 → 实际验收。不要手改生成 YAML。执行脚本先审查；Node VM 不是安全沙箱。

隔离端口/controller/DNS/缓存，关闭测试 TUN，不改系统代理，不复用生产 PID/缓存。测 provider 冷启动、更新、失败/缓存路径、格式、组/规则引用；首次无缓存不可假设下载失败能继续使用。请求期间记录 connections 的 rule/chains，并独立记录 HTTP/应用结果。

取样国内、未收录国内、未收录海外、AI/OAuth、开发依赖/镜像和真实下载。下载根路径 403/404 不证明文件可下载；广告 REJECT 是单独可选需求。备份脚本/merge/选择，更新后核对 hash、版本、数量、解析、命中、出口。DNS 见 [dns-design.md](dns-design.md)，规则语义核对[官方文档](https://wiki.metacubex.one/config/rules/)。
