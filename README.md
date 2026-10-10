# deploy-clash-node

在全新 **Ubuntu 24.04 x64** 服务器上部署 VLESS + Reality 节点，并生成可直接导入 **Clash Verge Rev / Mihomo** 的 HTTPS 订阅。

## 一键部署

服务器需要公网 IPv4。先在云平台防火墙放行入站 TCP `80`、`443`、`8443`，再用有 `sudo` 权限的账号登录服务器，运行：

```bash
curl -fsSLo deploy-clash-node.sh https://raw.githubusercontent.com/OrdoAbChao7/deploy-clash-node/main/scripts/deploy.sh && sudo bash deploy-clash-node.sh
```

脚本完成后会打印 `Subscription: https://...`。在 Clash Verge Rev 的「订阅」页面添加这个 URL，更新订阅后选择 `PROXY` 组中的节点即可。订阅链接也保存在服务器的 `/root/clash-node/access.txt`；链接包含获取节点凭据所需的随机路径，请妥善保存。

如果服务器对外显示的出口 IP 与客户端连接服务器所用的入口 IP 不同，可以在下载脚本后指定入口 IP：

```bash
sudo NODE_IP=203.0.113.10 bash deploy-clash-node.sh
```

运行 `bash deploy-clash-node.sh --help` 可查看脚本支持的参数。部署时还可设置 `REALITY_SNI`（默认 `www.cloudflare.com`）和 `LE_EMAIL`（可选，供 Let's Encrypt 账户通知使用）。

## 部署条件

| 条件 | 说明 |
| --- | --- |
| 系统 | Ubuntu 24.04 x86_64，全新服务器或尚未运行 Xray 的服务器 |
| 权限 | `root` 或 `sudo` |
| 网络 | 公网 IPv4；服务器可访问 GitHub、软件包源、PyPI、Reality 目标站和证书服务 |
| 端口 | TCP `80` 用于证书签发和续期，`443` 用于节点，`8443` 用于 HTTPS 订阅 |

如果上述端口已被占用，或检测到现有 Xray 配置、部署目录，脚本会停止，不会覆盖已有节点。脚本会安装 Xray、Nginx 和 Certbot，并为短期 IP 地址证书设置定时续期。

## 部署后在哪里找

| 内容 | 位置 |
| --- | --- |
| 订阅 URL 与文件路径 | `/root/clash-node/access.txt` |
| 本地 Clash 配置 | `/root/clash-node/profile.yaml` |
| Xray 服务配置 | `/usr/local/etc/xray/config.json` |
| 订阅服务 | Nginx，TCP `8443` |
| 证书续期 | `clash-node-cert.timer` |

默认配置只有两条分流规则：`GEOIP,CN,DIRECT` 和 `MATCH,PROXY`。这意味着中国大陆 IP 直连，其余未匹配流量走节点。**脚本不会自动读取你现有的 Clash 规则。** 如果需要保留当前的规则和策略组，可使用仓库中的 [Codex Skill](SKILL.md) 按实际运行配置迁移。

订阅提供的是部署时生成的配置文件。以后修改 `/root/clash-node/profile.yaml`，需要再把文件同步到 `/var/lib/clash-node/profile.yaml`，客户端更新订阅后才会获取新内容：

```bash
sudo install -m 640 -o root -g www-data /root/clash-node/profile.yaml /var/lib/clash-node/profile.yaml
```

## 检查与排错

部署完成后，可在服务器上查看服务与续期定时器：

```bash
systemctl status xray nginx clash-node-cert.timer
```

订阅无法导入时，先确认云平台防火墙已放行 TCP `8443`，再用浏览器访问脚本打印的完整 HTTPS URL。不要把订阅 URL、`profile.yaml` 或 `access.txt` 粘贴到公开 Issue。

## 仓库内容

- [scripts/deploy.sh](scripts/deploy.sh)：一键部署脚本，适用于上述全新 Ubuntu 环境。
- [SKILL.md](SKILL.md)：Codex 部署工作流，包含部署前检查、现有规则迁移和连接验证。

## 参考

- [Xray 官方 Reality 配置示例](https://github.com/XTLS/Xray-examples/blob/main/VLESS-TCP-XTLS-Vision-REALITY/config_server.jsonc)
- [Xray 官方安装脚本](https://github.com/XTLS/Xray-install)
- [Let's Encrypt 的 IP 地址证书说明](https://letsencrypt.org/2026/03/11/shorter-certs-certbot.html)
