---
name: deploy-clash-node
description: Audit, deploy, maintain, and troubleshoot VPS proxy infrastructure for Clash/Mihomo; publish HTTPS subscriptions, migrate profiles, optimize Script.js routing and DNS, benchmark protocols, and perform verified rollbacks.
metadata:
  version: "2.0.0"
---

# VPS 多协议代理工程

明确模式：只读审计、部署/升级、订阅迁移、分流优化、测试或故障回滚。沿用实际客户端、现有服务及已授予的权限；不为统一而迁移可用核心，不默认部署所有协议。以项目事实和实测为准，不把历史成绩或版本当成通用推荐。

## 执行阶段

| 阶段 | 产出与放行条件 | 默认权限 |
|---|---|---|
| Phase 0 取证 | OS/资源/网络、SSH、核心版本与有效配置、监听、防火墙、Nginx/TLS/Certbot、日志、备份摘要；未知项标 unknown | 只读自动 |
| Phase 1 调研 | 官方仓库 Release、提交、Issue、安全公告、License、摘要与客户端兼容证据 | 自动 |
| Phase 2 设计 | 根据 TCP/UDP、资源、性能与故障域选协议/核心 | 自动 |
| Phase 3 计划 | 配置 diff、变更清单、备份与恢复步骤、停止条件、流量预算 | 自动 |
| Phase 4 部署 | 逐项实施，每项校验与健康检查后再继续 | 必须获覆盖具体变更的批准 |
| Phase 5 客户端 | 订阅/生产脚本候选、隔离验证后应用并核对运行状态 | 必须获覆盖具体变更的批准 |
| Phase 6 测试 | 分协议样本/中位数/失败率/资源/故障切换 | 按预算执行 |
| Phase 7 收尾 | 脱敏、临时进程/端口/凭据清理；保留回滚点 | 低风险自动，高风险需批准 |
| Phase 8 交付 | 已做/未做/限制、版本、证据、维护和回滚路径 | 自动 |

只读请求在 Phase 0 与必要的 Phase 1 后交付，不安装、续期、重启或修改系统。已有批准不重复询问；新范围先给可审查计划。安全异常停止受影响操作并报告，不连续尝试高风险绕行。SSH 指纹变化必须独立带外核验，禁止关闭 StrictHostKeyChecking。凭据仅通过受保护文件/输入传递，不进入 argv、日志、普通报告、版本库或 Skill。

## 按任务读取

- 官方项目选型与多协议架构：[protocol-selection.md](references/protocol-selection.md)。保留 VLESS + REALITY，按需选择 Hysteria2、AnyTLS、SS2022、TUIC、Trojan、WireGuard。
- 审计/部署/收尾：[security-baseline.md](references/security-baseline.md)；资源与账单：[monitoring.md](references/monitoring.md)。
- 证书与 hook：[certificate-renewal.md](references/certificate-renewal.md)。dry-run 成功不等于业务更新成功。
- 统一 HTTPS 订阅与限时访客兼容：[subscriptions.md](references/subscriptions.md)。旧订阅不能随意覆盖。
- Script.js/策略组/规则源：[mihomo-routing.md](references/mihomo-routing.md)；DNS/GEOIP：[dns-design.md](references/dns-design.md)。
- 协议验收：[benchmarking.md](references/benchmarking.md)；排错与恢复：[troubleshooting.md](references/troubleshooting.md)。
- 证据与版本边界：[validated-baseline.md](references/validated-baseline.md)；变更：[CHANGELOG.md](CHANGELOG.md)。

忠实迁移时保留有效规则、组顺序、DIRECT/REJECT 和原 MATCH 语义，说明应用管理副本和订阅更新关系；明确请求智能分流优化时使用 MATCH,PROXY，不让未分类流量默认 DIRECT 或 REJECT。策略变化必须体现在候选 diff。

## 辅助脚本

先看 --help；成功退出仅证明脚本声明的有限检查通过。

- [preflight-audit.py](scripts/preflight-audit.py)：Linux 本机只读资源/服务摘要，缺少工具或权限标 unknown；不能替代敏感配置审计。
- [config-validation.py](scripts/config-validation.py)：调用实际 Mihomo/Xray/sing-box 校验，要求隔离工作目录，隐藏可能敏感的核心输出。
- [health-check.py](scripts/health-check.py)：通过本地 HTTP 代理请求公开 HTTPS 目标；不替代 UDP、路由或稳定性验收。
- [deploy.sh](scripts/deploy.sh)：保留 Ubuntu 新机 VLESS + HTTPS 入口，增加固定上游版本/摘要要求。修订脚本仅本地静态验证，实际使用前需隔离新机验收，不作为无人值守生产保证。

交付分清：可解析、服务 active、端口可达、真实请求、路由正确、应用可用、长期稳定；前一层不能替代后一层。
