---
name: deploy-clash-node
description: Audit, deploy, upgrade, maintain, and troubleshoot VPS proxy infrastructure across client apps and access networks with interactive client selection and version-specific profile/subscription adaptation; migrate routing and DNS, benchmark protocols, and perform verified rollbacks, plus Claude/Anthropic risk-reduction hardening.
metadata:
  version: "2.4.0"
---

# VPS 多协议代理工程

明确模式：只读审计、部署/升级、订阅迁移、分流优化、测试或故障回滚。沿用实际客户端、现有服务及已授予的权限；不为统一而迁移可用核心，不默认部署所有协议。以项目事实和实测为准，不把历史成绩或版本当成通用推荐。升级既有部署先做版本、兼容和回滚审计，不把升级等同于重装。

## 首先确认目标客户端

涉及部署、导入、订阅或分流时，先向用户确认设备系统、客户端名称（可多选）和交付范围；不能默认沿用本机 Mihomo 或上一台设备。信息已由本次用户明确提供则简要复述并继续，不重复询问。

首轮可直接问：“你准备在哪些设备和客户端使用？例如 Windows 的 Clash Verge Rev / v2rayN、Android 的 v2rayNG / Hiddify、iPhone 的 Shadowrocket / Surge，或其他客户端；需要只导入节点，还是连国内外分流和 DNS 一起配置？”

使用可用的交互提问工具；没有则用普通对话。先查已有上下文与获准读取的本机信息，再只追问影响兼容性的缺失项。客户端/目标设备未确定时，保持问题待答，可继续独立的只读服务器审计，不生成最终客户端配置、不按猜测选生产协议。用户不清楚版本时帮助只读识别或指引“关于”页面，不要求粘贴订阅凭据。仅服务器只读审计无需因缺客户端而停工，注明客户端适配未评估。

按 [客户端适配](references/client-adaptation.md) 记录系统、应用版本、实际内核/版本、节点或完整配置、是否保留原分流及多设备需求。生成目标客户端原生格式并验证；“支持适配流程”不等于所有客户端/协议组合已实测。已有生产变更授权和客户端选择是两件事，不混为一次批准。

接入网络可能是校园网/企业/酒店网页认证时，先交互确认是否需要“认证门户直连”模式，并收集实际门户地址段与认证/自助域名；不同学校/企业地址不同，不预置或沿用他处 IP/域名。用户确认不需要或无法确认时，不加该模式，按普通分流处理。详见 [校园认证门户](references/campus-portal.md)。

## 执行阶段

| 阶段 | 产出与放行条件 | 默认权限 |
|---|---|---|
| Phase 0 取证 | 客户端目标与缺失项；OS/资源/网络、SSH、核心版本与有效配置、监听、防火墙、Nginx/TLS/Certbot、日志、备份摘要；未知项标 unknown | 只读自动 |
| Phase 1 调研 | 官方仓库 Release、提交、Issue、安全公告、License、摘要与客户端兼容证据 | 自动 |
| Phase 2 设计 | 根据目标客户端兼容矩阵、TCP/UDP、资源、性能与故障域选协议/核心 | 自动 |
| Phase 3 计划 | 配置 diff、变更清单、备份与恢复步骤、停止条件、流量预算 | 自动 |
| Phase 4 部署 | 逐项实施，每项校验与健康检查后再继续 | 必须获覆盖具体变更的批准 |
| Phase 5 客户端 | 各目标原生订阅/配置候选、隔离或设备内验证后应用并核对运行状态 | 必须获覆盖具体变更的批准 |
| Phase 6 测试 | 分协议样本/中位数/失败率/资源/故障切换 | 按预算执行 |
| Phase 7 收尾 | 脱敏、临时进程/端口/凭据清理；保留回滚点 | 低风险自动，高风险需批准 |
| Phase 8 交付 | 已做/未做/限制、版本、证据、维护和回滚路径 | 自动 |

验收按实际接入网络分别记录；同一配置在 Wi-Fi 通过不代表蜂窝/企业网可用。

只读请求在 Phase 0 与必要的 Phase 1 后交付，不安装、续期、重启或修改系统。已有批准不重复询问；新范围先给可审查计划。安全异常停止受影响操作并报告，不连续尝试高风险绕行。SSH 指纹变化必须独立带外核验，禁止关闭 StrictHostKeyChecking。凭据仅通过受保护文件/输入传递，不进入 argv、日志、普通报告、版本库或 Skill。

## 按任务读取

- 首轮交互、客户端选择、跨格式输出与导入验收：[client-adaptation.md](references/client-adaptation.md)。先选择适配分支，再读相关技术文档。
- 在现有服务上新增协议、规划端口/证书/故障域：[multi-protocol-deployment.md](references/multi-protocol-deployment.md)。
- 升级核心、配置、订阅、规则/DNS 或客户端 profile：[upgrade-playbook.md](references/upgrade-playbook.md)。
- 同一配置在校园网/Wi-Fi/蜂窝表现不一致、订阅无法更新或节点全不可用：[troubleshooting.md](references/troubleshooting.md) 的网络路径分层；先区分订阅入口与节点，不据此重建服务器。
- 接入网络需要网页认证（校园网/企业/酒店），或门户、认证/自助站点被代理重置：[campus-portal.md](references/campus-portal.md)。先确认是否需要该模式及实际地址段/域名，再设计直连规则。
- 连续健康检查、告警与跨网络证据：[monitoring.md](references/monitoring.md)。

- 官方项目选型与多协议架构：[protocol-selection.md](references/protocol-selection.md)。保留 VLESS + REALITY，按需选择 Hysteria2、AnyTLS、SS2022、TUIC、Trojan、WireGuard。
- 审计/部署/收尾：[security-baseline.md](references/security-baseline.md)；资源与账单：[monitoring.md](references/monitoring.md)。
- 证书与 hook：[certificate-renewal.md](references/certificate-renewal.md)。dry-run 成功不等于业务更新成功。
- 统一 HTTPS 订阅与限时访客兼容：[subscriptions.md](references/subscriptions.md)。旧订阅不能随意覆盖。
- 仅 Mihomo 分支的 Script.js/策略组/规则源：[mihomo-routing.md](references/mihomo-routing.md)；DNS/GEOIP：[dns-design.md](references/dns-design.md)。
- 以 Claude / Anthropic 稳定性或降风控为目标（出口 IP、DNS 泄漏、IPv6、Claude 域名显式分流与验收）：[claude-risk-reduction.md](references/claude-risk-reduction.md)。
- 协议验收：[benchmarking.md](references/benchmarking.md)；排错与恢复：[troubleshooting.md](references/troubleshooting.md)。
- 证据与版本边界：[validated-baseline.md](references/validated-baseline.md)；变更：[CHANGELOG.md](CHANGELOG.md)。

忠实迁移时保留有效规则、组顺序及最终兜底语义，说明应用管理副本和订阅更新关系；明确请求智能分流优化时，未知海外默认代理、不默认拒绝。Mihomo 用 MATCH,PROXY，其他客户端使用其原生兜底语法，不复制 Mihomo 字段。不能表达的策略明确标记不支持并与用户选择替代方案，不能静默丢弃。策略变化必须体现在候选 diff。

## 辅助脚本

先看 --help；成功退出仅证明脚本声明的有限检查通过。

- [preflight-audit.py](scripts/preflight-audit.py)：Linux 本机只读资源/服务摘要，缺少工具或权限标 unknown；不能替代敏感配置审计。
- [config-validation.py](scripts/config-validation.py)：调用实际 Mihomo/Xray/sing-box 校验，要求隔离工作目录，隐藏可能敏感的核心输出。
- [health-check.py](scripts/health-check.py)：通过本地 HTTP 代理请求公开 HTTPS 目标；不替代 UDP、路由或稳定性验收。
- [deploy.sh](scripts/deploy.sh)：保留 Ubuntu 新机 VLESS + HTTPS 入口，增加固定上游版本/摘要要求。修订脚本仅本地静态验证，实际使用前需隔离新机验收，不作为无人值守生产保证。

交付分清：可解析、服务 active、端口可达、真实请求、路由正确、应用可用、长期稳定；前一层不能替代后一层。

## 客户端交付硬门槛

逐客户端记录交付类型（完整 profile、仅节点集合或分享链接列表）、实际应用入口、原始文件摘要、测试时补入或转换的内容、应用导入及更新结果、实际生效配置和未验证项。仅有 `proxies` 的 YAML 是节点集合；只有实际验证应用的合并链后，才能声明它可用于该入口，不能将其称作完整 profile。追加策略组与规则后的 `mihomo -t` 只证明拼接后的配置可解析。真实应用导入、更新和设置保持未验证时不得声称该客户端交付完成。权限不允许实际切换时保留隔离候选并明确未验收，不要求用户冒险验证。

在本机运行任何隔离核心或指导应用重载前，核查相关应用服务、已有核心进程的可执行文件、PID、父进程、命令行及监听（脱敏），识别监控程序或其他现有实例；按实际版本核对同名核心冲突。冲突存在或无法排除时，停止启动同名测试核心或指导重载，先找到并验证不干扰现有进程的隔离方式。隔离目录和端口不保证进程名隔离；不得终止不明进程或擅停监控。验证原状态、回滚与真实应用更新参见客户端适配及 Mihomo 分支。
