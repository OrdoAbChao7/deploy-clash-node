# Claude / Anthropic 稳定性与降风控

本流程用于以 Claude / Claude Code 为主要用途的节点部署与客户端分流，目标是降低因出口 IP、DNS、IPv6 或分流不一致触发账号风控的概率。**不保证不封号**：Anthropic 的判定规则不公开，本流程只处理可观测、可配置的部分。

第三方来源：ip.net.coffee《Claude Code 稳定使用指南》（2026-11 阅读）提供了检查项与域名清单；它不是官方文档，域名与行为需按实际连接日志复核。本文的规则/DNS 字段是 Mihomo 示例，其他客户端按 [客户端适配](client-adaptation.md) 用原生语法实现，不复制字段。

## 1. Anthropic 实际能看到什么

- 到 `anthropic.com`、`claude.ai` 等域名的连接出口 IP（代理节点），以及 TLS/HTTP 指纹、时间/时区、账号与设备信息。
- DNS 不一致：连接 IP 在海外，但权威 DNS 看到中国大陆解析器。这是本流程要消除的主要矛盾。
- 浏览器对国内 IP 回显站（如 `my.ip.cn`、`2026.ip138.com`）的请求不属于 Anthropic 路径；检测页出现“中国出口”不等于 Claude 看到真实 IP。判断以 `claude.ai/cdn-cgi/trace` 或 Anthropic 端点的实际出口为准。

## 2. 出口 IP

- 住宅/ISP IP 最优；机房 IP 不是不能用，但 IP 信誉/ASN 属于供应商层面，规则改不了。
- 固定一个稳定出口，避免频繁切换节点/IP；AUTO/FAILOVER 的切换会改变 Claude 看到的地址。
- 避免共享严重或超售的出口；记录 IP、ASN、归属和变更时间，不把“检测页评分”当作账号安全结论。
- IPv4 优先；IPv6 关闭（见 §5）。

## 3. TLS 与传输

- 客户端使用浏览器类指纹（Mihomo `client-fingerprint: chrome` 或等价），入口优先 TCP/443 + TLS/REALITY；UDP/QUIC、非标准端口节点作为补充。
- 不能承诺“指纹一定通过”；按目标客户端版本与接入网络实测并记录。
- 订阅、配置和日志按 [security-baseline.md](security-baseline.md) 收尾，不泄露节点凭据。

## 4. DNS 必须经代理

- 海外域名必须由经代理的加密 DNS（DoH via PROXY）解析；国内域名可走国内解析保持直连速度，但不能让本地运营商解析海外域名。
- Mihomo 参考结构（需要 geosite 数据）：

  ```yaml
  dns:
    enhanced-mode: fake-ip
    nameserver:
    - "https://1.1.1.1/dns-query#PROXY"
    - "https://1.0.0.1/dns-query#PROXY"
    nameserver-policy:
      "geosite:cn":
      - <国内 DNS>
      "geosite:private":
      - <国内 DNS>
    proxy-server-nameserver:
    - <国内 bootstrap DNS>
  ```

- DoH 不带 `#PROXY` 时仍从本地出口发出，解析器身份不会变；这是“用了 DoH 仍泄露”的常见原因。
- `fake-ip` 与 `redir-host` 行为不同；系统代理模式下应用自行解析可能绕过 Mihomo DNS，不能承诺零泄漏（见 [dns-design.md](dns-design.md)）。
- 网关场景注意 TUN 会劫持网关自身 :53：回退探测若拿到 `198.18.0.0/16` fake-ip，应判为“回退不可用”，不能据此切换。

## 5. IPv6 关闭

- 客户端、内核、TUN、DNS 全链路关闭 IPv6；否则可能出现分流失效、AAAA 直连绕行与 DNS 泄漏。
- 验证：路由表无默认 IPv6、客户端开关关闭、实际请求不出现 IPv6 路径。

## 6. Claude 域名显式分流

将 Claude/Anthropic 相关域名显式放在通用规则之前并指向同一代理组；不要依赖 `geosite`/`GEOIP` 兜底，也不要被“智能分流”覆盖。

参考清单（2026-11 第三方指南；上线前按实际连接日志复核）：

```yaml
rules:
- DOMAIN-SUFFIX,anthropic.com,PROXY
- DOMAIN-SUFFIX,claude.ai,PROXY
- DOMAIN-SUFFIX,claude.com,PROXY
- DOMAIN-SUFFIX,clau.de,PROXY
- DOMAIN-SUFFIX,claudemcpclient.com,PROXY
- DOMAIN-SUFFIX,claudemcpcontent.com,PROXY
- DOMAIN-SUFFIX,claudeusercontent.com,PROXY
- DOMAIN,servd-anthropic-website.b-cdn.net,PROXY
- DOMAIN,anthropic.com.cdn.cloudflare.net,PROXY
- DOMAIN,anthropic.auth0.com,PROXY
- DOMAIN,anthropic-com.ghost.io,PROXY
- DOMAIN-SUFFIX,sentry.io,PROXY
- DOMAIN-SUFFIX,statsigapi.net,PROXY
- DOMAIN,browser-intake-us5-datadoghq.com,PROXY
- DOMAIN-KEYWORD,datadog,PROXY
- DOMAIN-KEYWORD,sift,PROXY
- DOMAIN-SUFFIX,intercom.io,PROXY
- DOMAIN-SUFFIX,intercomcdn.com,PROXY
- DOMAIN,cdn.usefathom.com,PROXY
- IP-CIDR,160.79.104.0/21,PROXY,no-resolve
- GEOSITE,anthropic,PROXY
```

- `GEOSITE,anthropic` 需要 geosite 数据；记录加载记录数（参考环境为 21 条）。
- `IP-ASN,399358` 需要 ASN 库；没有就省略，不假装覆盖。
- IPv6 CIDR 在 IPv6 关闭时可不加。
- `DOMAIN-KEYWORD,sift` 较宽泛，可能命中无关域名，可改精确域名。
- 规则顺序与 [mihomo-routing.md](mihomo-routing.md) 一致：Claude 显式 → 必要国内镜像例外 → 海外/AI → 国内分类 → `GEOIP,CN,DIRECT` → `MATCH,PROXY`。

### 不要用全局模式

`mode: global` 把所有连接（含国内）交给代理，并跳过全部规则：广告拦截、直连例外、NCSI 等失效；国内流量绕海外，代理故障时国内也断。它能让检测页“看不到中国出口”，但代价与故障域远大于收益。

## 7. 验收清单

| 检查 | 期望 | 记录 |
|---|---|---|
| `https://claude.ai/cdn-cgi/trace` | `ip` 为代理出口、`loc` 非 CN | IP、时间、节点 |
| `https://api.anthropic.com/` | 可达（根路径 404 正常），命中显式 `DomainSuffix` | rule、HTTP、耗时 |
| EDNS 解析器（如 `https://edns.ip-api.com/json`） | 非本地运营商 | resolver IP/geo |
| DNS 泄漏页 | 海外/云解析器，非本地 ISP | 页面结果、时间 |
| IPv6 | 无 AAAA 直连绕行 | 客户端/路由表 |
| 规则命中 | `/rules` 或日志显示显式规则，不是 `MATCH` 兜底 | rule、chains |
| 真实使用 | Claude Code 登录/长会话/不同接入网络 | 应用结果 |
| 变更 | 备份、候选、热重载/重启记录、回滚点 | 文件/版本/摘要 |

检测页只能作为辅助；“中国出口”可能来自浏览器对国内回显站的直连，需要与 Claude 端点实际出口区分。

## 8. 常见误区

- “检测页有中国出口 = Claude 看到真实 IP”：否，见 §1。
- “开全局就安全”：规则全失效、国内全绕海外、故障域扩大。
- “用了公共 DoH 就没泄漏”：DoH 不经过代理时，解析器仍是本地出口。
- “住宅 IP 一定安全 / 机房 IP 一定封”：都不是绝对；行为、账号、地区、频率同样重要。
- “多节点轮换更安全”：频繁切换 IP 本身是风控信号；Claude 固定一个稳定出口。
- “伪装 TLS 指纹就能绕过”：只是一层，不能替代 IP 与行为治理。

## 9. 与部署流程的衔接

- Phase 2 设计：把出口 IP 类型、固定/切换策略、DNS 方案、IPv6、Claude 域名分流列为约束。
- Phase 3 计划：给出配置 diff、备份、回滚与验收样本。
- Phase 4/5 部署与客户端应用后，按 §7 验收；未实测项标 unknown，不宣称“已降风控”。
- 相关：[dns-design.md](dns-design.md)、[mihomo-routing.md](mihomo-routing.md)、[client-adaptation.md](client-adaptation.md)、[validated-baseline.md](validated-baseline.md)。
