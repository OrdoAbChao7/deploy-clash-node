# deploy-clash-node

面向多种代理客户端的 VPS 多协议代理工程 Skill，覆盖部署前审计、协议选型、HTTPS 订阅、客户端分流、性能测试和故障回滚。

**当前版本：2.4.0。** 先交互确认设备、客户端和所需配置，再从现有服务器与客户端取证开始，先提供可审查的方案，再执行已获批准的生产变更。适合新建节点，也适合维护和升级已有服务。

## 能做什么

| 场景 | 工作内容 |
| --- | --- |
| 只读审计 | 检查系统资源、SSH、服务与配置、监听、防火墙、TLS、续期、日志和备份；未知项明确标注 |
| 多协议部署 | 调研官方上游，按网络、资源和客户端兼容性选择 VLESS + REALITY、Hysteria 2、AnyTLS、Shadowsocks 2022 等 |
| 既有部署升级 | 审计版本/兼容性/回滚点，逐项升级核心、配置、订阅、规则/DNS 或客户端 profile，不把升级等同重装 |
| 客户端适配 | 确认应用与内核版本，按目标生成节点订阅或原生完整配置，提供导入和验证步骤 |
| 移动网络兼容 | 区分订阅入口与节点连接；蜂窝优先 TCP/443 + TLS/REALITY，按目标网络验收 FAILOVER 顺序 |
| 认证门户直连 | 先确认是否需要；按实际门户地址段/认证域名配置 TUN 排除与 DIRECT 规则，避免门户被代理重置 |
| 统一订阅 | 同一节点数据生成各客户端格式，发布 HTTPS 订阅，保护 Token，保留旧订阅和回滚路径 |
| 分流优化 | 按客户端原生规则/DNS实现目标；Mihomo 分支审计 Script.js，设计 PROXY / AUTO / FAILOVER |
| 性能测试 | 分协议测试延迟、上传、下载、UDP、DNS、GitHub、应用访问和资源占用，在预算内验证稳定性 |
| 持续监控 | 服务/网络路径/应用三层检查，只读健康脚本、告警去重和跨网络证据 |
| 日常维护 | 核验证书续期钩子、监控流量与资源、分层排查故障并恢复已验证的配置 |

多协议部署通过 Agent 按实际环境实施；仓库里的 `deploy.sh` 仅辅助部署新机 VLESS + REALITY 和 HTTPS 订阅，不会自动安装所有协议。

## 调用时先问清楚客户端

信息未明确时，Skill 会先询问：

> 你准备在哪些设备和客户端使用？可以多选，例如 Windows + v2rayN、Android + Hiddify、iPhone + Shadowrocket；需要只导入节点，还是连分流和 DNS 一起配置？

已在本次请求中说明的内容不重复问；不清楚版本时帮助识别。目标未明确前，可继续独立的服务器只读审计，但不会默认生成 Mihomo 配置或据此修改生产。

| 客户端方向 | 适配方式 |
| --- | --- |
| Clash Verge Rev / Mihomo 前端 | YAML 与应用实际支持的覆写/脚本，使用 Mihomo 专用校验 |
| v2rayN / v2rayNG | 按应用版本与实际核心生成支持的节点订阅或自定义配置，原生路由/DNS单独核对 |
| sing-box / Hiddify | 按目标版本生成 JSON 或应用支持的导入格式，核对转换后的实际行为 |
| Shadowrocket | 按应用版本适配节点订阅/原生配置，在目标设备验证 |
| Surge / Quantumult X | 分别采用各自原生配置与规则资源，逐项确认协议和策略能力 |
| OpenClash / 路由器及其他应用 | 先核对插件、平台与核心，再确定配置和网络设置范围 |

这是**适配工作流覆盖范围**，不是所有客户端与协议组合已实测的承诺。不支持或未核实的功能会明确列出；没有目标设备时，交付候选、导入步骤和待验证项，不宣称已连通。多设备可从同一节点数据生成多个格式入口，不强行共用一份 YAML。详见 [客户端适配指南](references/client-adaptation.md)。

## 安装

先克隆仓库并审阅 [SKILL.md](SKILL.md)：

```bash
git clone https://github.com/OrdoAbChao7/deploy-clash-node.git
cd deploy-clash-node
```

将以下内容一起放入 Agent 的 `skills/deploy-clash-node/` 目录，不能只复制 `SKILL.md`：

```text
deploy-clash-node/
├── SKILL.md
├── CHANGELOG.md
├── references/
└── scripts/
```

Codex 或兼容 Agent 可能使用 `$CODEX_HOME/skills/deploy-clash-node`、`~/.codex/skills/deploy-clash-node` 或 `~/.agents/skills/deploy-clash-node`。先确认实际加载目录；已有安装先备份再更新。若同时维护多个技能目录，从同一份源码同步全部文件并逐文件核对，避免同名 Skill 内容不一致。

脚本依赖 Python 3 标准库；`deploy.sh` 需要 Linux/Bash。配置校验还需提供实际使用的 Mihomo、Xray 或 sing-box 二进制。读取技能本身不会安装服务器软件。

## 使用示例

在支持 Skill 的 Agent 中显式调用 `$deploy-clash-node`，或说明任务：

**只读审计**

> 用 deploy-clash-node 审计现有 VPS，检查服务、端口、证书续期、日志和备份。只读取证，列出未知项，不修改服务器。

**多协议部署**

> 用 deploy-clash-node 设计 VLESS、Hysteria2 和 AnyTLS 方案。保留已有可用服务，先给上游选型、配置差异、备份及回滚计划，我批准后部署。

**多设备适配**

> 用 deploy-clash-node 给 Windows 的 v2rayN 和 iPhone 的 Shadowrocket 适配现有节点。我想保留各自原有分流，请先确认版本和协议兼容性，分别给订阅或导入配置。

**既有部署升级**

> 用 deploy-clash-node 升级现有 VPS：先审计当前版本、配置、订阅和回滚点，再给逐项变更、兼容性和停止条件。不要重装，不要覆盖旧订阅，未经批准不要改生产。

**Mihomo 分流优化**

> 用 deploy-clash-node 优化当前 Script.js：国内直连，未知海外走代理，补齐 AI 和开发工具分流。先生成候选并隔离验证，未经批准不要修改生产。

**故障排查与回滚**

> 用 deploy-clash-node 排查订阅能下载但节点不通的问题，逐层验证；需要回滚时核对备份、版本和影响范围。

**移动网络排查**

> 用 deploy-clash-node 排查同一订阅在校园网可用、手机流量下无法更新或节点不通的问题。先区分订阅入口和节点连接，再按网络路径分层，不要直接重建服务器。

**校园认证门户**

> 用 deploy-clash-node 处理校园网认证门户被代理重置的问题。先确认是否需要门户直连模式，我会提供门户 IP/网段和认证域名；再给规则、验证和回滚方案，未经批准不要改生产。

**性能比较**

> 用 deploy-clash-node 在 1 GB 测试流量预算内比较节点。各协议分别采样，稳定性测试与大流量测试串行，不把单节点结果推广到所有节点。

**持续监控**

> 用 deploy-clash-node 设计一个只读健康检查：核对配置/订阅 hash、运行规则/provider、DNS、节点延迟、系统代理/TUN 和关键站点，异常告警。不要自动改生产或切换节点。

## 标准流程

| 阶段 | 工作 | 权限边界 |
| --- | --- | --- |
| Phase 0 | 确认客户端目标、只读取证 | 缺失信息交互确认；只读自动 |
| Phase 1 | 官方 GitHub 项目调研 | 自动 |
| Phase 2 | 架构设计 | 自动 |
| Phase 3 | 部署计划、备份与回滚方案 | 自动 |
| Phase 4 | 生产环境修改 | 需要覆盖具体变更的批准 |
| Phase 5 | 客户端订阅与规则集成 | 需要覆盖具体变更的批准 |
| Phase 6 | 性能和稳定性测试 | 按预算执行 |
| Phase 7 | 安全审计和清理 | 低风险自动，高风险需批准 |
| Phase 8 | 最终报告和维护交付 | 自动 |

已有明确授权无需重复确认。只读审计不会自动进入部署；SSH 指纹变化时停止连接并进行独立带外核验，不关闭主机密钥检查。

## 脚本入口

```bash
python scripts/preflight-audit.py --help
python scripts/config-validation.py --help
python scripts/health-check.py --help
bash scripts/deploy.sh --help
```

| 脚本 | 范围 |
| --- | --- |
| [preflight-audit.py](scripts/preflight-audit.py) | Linux 本机只读资源和服务摘要；不替代配置、指纹、TLS、日志及账单审计 |
| [config-validation.py](scripts/config-validation.py) | 使用实际核心校验候选配置；需要隔离工作目录，核心可能下载规则集或写缓存 |
| [health-check.py](scripts/health-check.py) | 经指定本地 HTTP 代理访问公开 HTTPS 目标，核对状态及可选正文标记；不输出 URL 或响应正文 |
| [deploy.sh](scripts/deploy.sh) | 全新 Ubuntu 24.04 x86_64 的 VLESS + REALITY 和 HTTPS 订阅辅助部署 |

配置校验示例：

```bash
python scripts/config-validation.py \
  --core mihomo \
  --binary /absolute/path/to/mihomo \
  --config /absolute/path/to/candidate.yaml \
  --work-dir /absolute/path/to/isolated-workdir
```

工作目录必须预先创建并与生产隔离。配置可解析不代表节点可连通，还需真实请求、路由和应用层验证。

### 新机部署脚本的前置条件

`deploy.sh` 会拒绝占用的端口和已有部署路径。运行前完成备份、审阅和生产授权，并提供：

| 必填变量 | 内容 |
| --- | --- |
| `XRAY_INSTALL_COMMIT` | 已审阅的官方安装器固定 commit |
| `XRAY_INSTALL_SHA256` | 对应安装器的可信 SHA256 |
| `XRAY_VERSION` | 明确的上游版本 |
| `XRAY_BINARY_SHA256` | 官方未压缩二进制摘要，或从已按官方摘要验证的归档提取后计算的摘要 |
| `CERTBOT_VERSION` | 已验证支持所选证书方案的明确版本 |

可选变量为 `NODE_IP`、`REALITY_SNI`、`LE_EMAIL`。该脚本使用 TCP 80 进行证书验证、TCP 443 提供节点、TCP 8443 提供 HTTPS 订阅；其他部署方案不必沿用这些端口。

订阅地址只写入服务器受保护的 `/root/clash-node/access.txt`，不打印到终端。旧版无参数一键部署命令已不适用。修订脚本完成了本地语法、帮助和缺参拒绝检查，**尚未在新 VPS 上完成端到端部署验证**，使用前需在隔离新机验收。

## 工程约束与验证范围

- 官方资产固定版本并验证摘要；不使用来源不明的一键脚本。
- 凭据、节点配置和订阅 URL 不进入命令行参数、日志或公开仓库。
- 验收按实际接入网络分别记录；Wi-Fi 通过不等于蜂窝/企业网可用。
- 升级先做版本、兼容和回滚审计，不把升级等同重装；脚本本地验证不代表新 VPS 端到端部署成功。
- 分流修改遵循“现有配置 → 候选 → 目标内核/应用验证 → 批准 → 生产应用”。Mihomo/Clash Verge 分支操作生产脚本，不手改生成的 `clash-verge.yaml`。
- 迁移旧配置保留原有策略；明确优化时未知海外用代理兜底。Mihomo 使用 `MATCH,PROXY`，其他客户端使用其原生语法，并在差异中说明变化。
- Certbot 模拟续期成功还需钩子执行、服务加载和实际握手证据。
- 本机 vnStat 与服务商账单分开记录，不自行假定套餐额度。

历史验证覆盖多协议短时测试、合并 PEM、续期钩子和 Mihomo 分流生产功能。它不代表所有版本、网络、登录流程或节点长期稳定。适用版本及未覆盖项见 [验证边界](references/validated-baseline.md)。

历史限时访客自动化未作为本版成熟脚本发布；独立凭据、到期撤销及验证流程见 [订阅管理](references/subscriptions.md)。

## 技术文档

| 文档 | 内容 |
| --- | --- |
| [客户端适配](references/client-adaptation.md) | 交互确认、版本兼容、原生输出、导入与逐设备验收 |
| [多协议部署](references/multi-protocol-deployment.md) | 端口/进程/证书/故障域、逐协议上线与回滚 |
| [升级与迁移](references/upgrade-playbook.md) | 变更分类、备份/候选/批准、订阅/规则/DNS/客户端升级 |
| [协议选型](references/protocol-selection.md) | 官方上游、维护状态、License、摘要和兼容性 |
| [安全基线](references/security-baseline.md) | 只读取证、最小权限、备份与收尾 |
| [证书续期](references/certificate-renewal.md) | 合并 PEM、原子替换、钩子验证 |
| [订阅管理](references/subscriptions.md) | HTTPS、Token、旧订阅兼容与访客撤销 |
| [Mihomo 分流](references/mihomo-routing.md) | 策略组、规则源和脚本变更流程 |
| [校园认证门户](references/campus-portal.md) | 交互确认、TUN 排除、DIRECT 规则、验证与回滚 |
| [Claude 降风控](references/claude-risk-reduction.md) | 出口 IP、经代理 DNS、IPv6、Claude 域名分流与验收 |
| [DNS 设计](references/dns-design.md) | 国内外解析、GEOIP 与 no-resolve 对照 |
| [基准测试](references/benchmarking.md) | 采样、预算、指标和结论边界 |
| [监控](references/monitoring.md) | 分层健康检查、连续检测、流量与资源 |
| [故障排查](references/troubleshooting.md) | 分层定位、跨网络差异与回滚 |

版本变化见 [CHANGELOG.md](CHANGELOG.md)。
