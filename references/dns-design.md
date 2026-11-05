# DNS 设计与对照

记录系统代理/TUN、fake-ip/redir-host、IPv4/IPv6及应用自行解析行为，不能承诺系统代理模式零 DNS 泄漏。看有效配置，区分 bootstrap default-nameserver、节点 proxy-server-nameserver、nameserver-policy、默认解析器及 fallback。

防止节点域名、DoH 域名、provider 首次下载形成代理/DNS 循环。按网络可达性和需求选国内/海外解析器，不把固定公共 DNS 当万能方案。

对照未知域名默认海外，或默认国内+海外 fallback/filter 并让已知海外/AI/开发按 policy 走海外。后者可能改善未知国内可达性，但国内 DNS 将未知海外污染成 CN IP 时仍可能误判直连，记录限制。

GEOIP,CN,DIRECT,no-resolve 可能不主动解析尚无 IP 的域名，使未知国内落入 MATCH。必须按实际版本和 DNS 模式控制缓存/请求方式，对比有无 no-resolve，记录答案、rule/chains、HTTP与耗时；不要对所有 IP 规则一概删除 no-resolve。已知 IP 请求与保留域名请求行为可能不同。

至少测试真实未被国内规则收录的国内域名、未分类海外域名、已知国内/海外和 AI 认证域名；确认样本仍未分类。检查循环、污染、IPv6绕行、超时及 bootstrap，修改网络栈须在授权范围。重新核对[官方 DNS 文档](https://wiki.metacubex.one/config/dns/)，旧案例只用于实验设计。
