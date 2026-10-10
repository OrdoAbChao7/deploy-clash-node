# deploy-clash-node

在全新 Ubuntu 24.04 x64 服务器上，一条命令部署 **VLESS + Reality** 节点，并生成适用于 Clash Verge Rev / Mihomo 的 HTTPS 订阅链接。

## 一键部署

服务器需有公网 IPv4；云平台防火墙需放行 TCP `80`、`443`、`8443`。以有 `sudo` 权限的用户登录服务器后运行：

```bash
curl -fsSLo deploy-clash-node.sh https://raw.githubusercontent.com/OrdoAbChao7/deploy-clash-node/main/scripts/deploy.sh && sudo bash deploy-clash-node.sh
```

脚本会自动生成独立的 UUID、Reality 密钥和订阅随机路径。完成后将打印订阅 URL；把 URL 粘贴到 Clash Verge Rev 的“订阅”页面导入。URL 也保存在服务器的 `/root/clash-node/access.txt`。

如公网出口 IP 与服务器入口 IP 不同，可指定入口 IP：

```bash
sudo NODE_IP=203.0.113.10 bash deploy-clash-node.sh
```

`REALITY_SNI` 默认是 `www.cloudflare.com`；`LE_EMAIL` 可选，用于 Let's Encrypt 账户通知。

## 部署结果

| 项目 | 位置或端口 |
| --- | --- |
| Xray 节点 | TCP `443`，开机自启 |
| HTTPS 订阅 | TCP `8443`，随机 URL |
| 证书验证 | TCP `80`，供自动续期使用 |
| Clash 配置 | `/root/clash-node/profile.yaml` |
| Xray 配置 | `/usr/local/etc/xray/config.json` |

默认分流只有 `GEOIP,CN,DIRECT` 和 `MATCH,PROXY`。如果要沿用现有 Clash 的复杂规则，使用仓库中的 [Codex Skill](SKILL.md) 检查当前运行配置并合并规则；不要公开上传含节点凭据的订阅文件。

脚本仅用于全新服务器：检测到现有 Xray、部署目录或 `80/443/8443` 端口被占用时会停止。它不会覆盖已有节点。IP 地址证书有效期较短，脚本会安装自动续期任务并执行续期演练。

## Codex Skill

[SKILL.md](SKILL.md) 记录了部署前检查、凭据处理、现有规则迁移和端到端验证流程。可将仓库作为自定义 Skill 安装；一键脚本位于 [scripts/deploy.sh](scripts/deploy.sh)。

## 依据

- [Xray 官方 Reality 配置示例](https://github.com/XTLS/Xray-examples/blob/main/VLESS-TCP-XTLS-Vision-REALITY/config_server.jsonc)
- [Xray 官方安装脚本](https://github.com/XTLS/Xray-install)
- [Let's Encrypt 的 IP 地址证书说明](https://letsencrypt.org/2026/03/11/shorter-certs-certbot.html)
