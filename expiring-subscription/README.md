# 限时访客订阅链接（默认 24 小时自动失效）

给 `deploy-clash-node` 部署好的节点加一个能力：**发放只活 N 小时（默认 24 小时）的远程订阅链接**。

## 为什么不能只让 URL 过期

订阅链接只是一次"配置下载"：对方点开就会拿到 `server / uuid / public-key / short-id`。你事后关掉 URL，他本地那份 YAML 照样能连——节点凭据还在他手里。

所以真正的"有效一天"必须做两层：

| 层 | 到期后 | 作用 |
| --- | --- | --- |
| 链接层 | nginx 返回 `410 Gone` | 无法再拉取、无法再转发 |
| 节点层 | 访客专属 UUID 从 Xray 移除并重启 | 已下载的配置也连不上 |

本方案用**独立的访客 UUID**，所以撤销访客时你自己的节点凭据、你自己的订阅链接完全不受影响。如果直接把自己的 profile 发给别人，撤销时必然连自己一起断。

## 对方电脑上的实际表现

把链接发给别人（导入 Clash Verge / Mihomo / 其他客户端）后：

| 时刻 | 对方看到什么 |
| --- | --- |
| 导入时 | 节点名 `Guest-xxxxxx`，订阅卡片显示到期时间（来自 `Subscription-Userinfo`） |
| 使用中 | 正常连接，**没有流量/天数倒计时限制** |
| 到期瞬间 | 已建立的连接不断，但**新连接一律失败**（握手被服务端拒绝） |
| 到期后点「更新订阅」 | HTTP `410`，客户端提示更新失败，旧配置仍在但连不上 |

要让客户端显示到期时间，靠的是 `Subscription-Userinfo: ... expire=<epoch>` 响应头（由 `conf.d/clash-guest-expire.conf` 生成）。**这个头只是显示，不做拦截**——Mihomo 内核不会因为过期就断连，真正的闸门是服务端撤销 UUID。

不能做的事（期望管理）：

- **不能远程删除对方本地的配置。** 订阅是一份 YAML，导入后就存在他机器上。「自动过期」的实际含义是**到期后连不上**，不是「配置消失」。
- **不能限制中间用量。** 有效期内他可以跑满带宽。
- **他在有效期内转发给别人，那个人也能用到期满**，然后一起失效（因为共用同一个访客 UUID）。

## 安装（服务器上执行一次）

想省事就用一键脚本 `issue.sh`（在本地跑，自动上传+安装+发放+校验，只输一次密码）：

```bash
cd deploy-clash-node/expiring-subscription
bash issue.sh <服务器IP> 2026-11-30
```

手动分步做法：

```bash
cd deploy-clash-node/expiring-subscription
sudo bash setup.sh
```

`setup.sh` 会：安装 nginx 片段并 include 进 `clash-node-subscription` 站点（改前自动备份）、生成 `/etc/nginx/conf.d/clash-guest-expire.conf`（到期时间表 map）、创建 `/var/lib/clash-node/sub`、把 `grant.sh`/`expire.sh` 装到 `/root/clash-node/guests/`、启用每 5 分钟扫描一次的 `clash-guest-expiry.timer`。

## 发放链接

```bash
sudo bash /root/clash-node/guests/grant.sh          # 24 小时
sudo bash /root/clash-node/guests/grant.sh 6        # 6 小时
sudo bash /root/clash-node/guests/grant.sh 24 alice # 带备注
```

## 指定到期日（例如 11 月 30 日）

```bash
sudo bash /root/clash-node/guests/grant.sh --until 2026-11-30
```

默认到该日 `23:59:59`，时间基准是**服务器本地时区**，脚本会同时打印对应的 UTC。

需要指定时分秒：

```bash
sudo bash /root/clash-node/guests/grant.sh --until 2026-11-30 18:00
sudo bash /root/clash-node/guests/grant.sh --until 2026-11-30 23:59:59 alice
```

如果服务器时区是 UTC、而你要按**北京时间** 11.30 24:00 失效，换算成 UTC 再写：

```bash
sudo bash /root/clash-node/guests/grant.sh --until 2026-11-30 15:59:59
```

> 时区不对会导致实际失效时间偏几小时。先 `timedatectl` 看一眼，再用 `expire.sh --list` 核对到期时间。

输出：

```
订阅链接: https://203.0.113.10:8443/4f3c9e...e1.yaml
有效期至: 2026-10-30 09:14 UTC（24 小时后自动失效）
访客标识: 3f2a1b4c5d6e（备注 alice）
```

脚本内部顺序：生成访客 UUID → 写入 Xray `clients`（带 `email: guest-xxx` 标记）→ 校验并重启 → 生成只含访客 UUID 的 profile → 放入订阅目录 → 用 HTTPS 回环自检一次 → 打印链接。

## 到期会发生什么

`clash-guest-expiry.timer` 每 5 分钟跑一次 `expire.sh`：

1. 删除 `/var/lib/clash-node/sub/<token>.yaml` → 该 URL 从此返回 `410`
2. 从 `config.json` 移除 `email=guest-xxx` 的客户端 → `xray run -test` 通过后重启
3. 把 `/root/clash-node/guests/<id>.env` 改名为 `.env.revoked` 留档

访客侧表现：客户端刷新订阅报错；即使不刷新，现有连接也会在重连时被服务端拒绝。

## 日常命令

```bash
sudo bash /root/clash-node/guests/expire.sh --list                  # 谁还有效、几号到期
sudo bash /root/clash-node/guests/expire.sh --revoke 3f2a1b4c5d6e   # 提前撤销
sudo bash /root/clash-node/guests/expire.sh --sync-map              # 重建到期时间表并重载 nginx
sudo bash /root/clash-node/guests/grant.sh 1                        # 再发一个 1 小时的
systemctl list-timers clash-guest-expiry.timer                      # 定时器状态
```

## 验证

```bash
# 过期后应为 410（同时看响应头：应带 Subscription-Userinfo 且 expire 已过）
curl -sS -o /dev/null -w '%{http_code}\n' https://<服务器IP>:8443/<token>.yaml
curl -sSI https://<服务器IP>:8443/<访客token>.yaml | grep -i subscription-userinfo

# 自己的订阅仍然正常
curl -fsS -o /dev/null -w '%{http_code}\n' https://<服务器IP>:8443/<自己的token>.yaml

# Xray 里只剩自己的客户端
python3 -c "import json;print(json.load(open('/usr/local/etc/xray/config.json'))['inbounds'][0]['settings']['clients'])"
```

## 边界

- **只保证到期失效，不管中间用量。** Xray 的 VLESS inbound 本身没有流量配额/限速；24 小时内对方可以用满你的带宽。要限量需要接 Xray Stats API + 定时封禁，或前面再加一层网关计费，不在本方案范围内。
- **时钟依赖服务端。** 到期判断用服务器 `date`，请确认 `timedatectl` 已同步。
- **到期精度约 5 分钟**（定时器扫描间隔），要更严格就把 `clash-guest-expiry.timer` 的 `OnUnitActiveSec` 调小。
- **链接仍是一次性凭据。** 24 小时内被转发，接转的人也还能用——但同样会在到期时一起失效。
- 需要删除访客时不要手改 `config.json`，用 `expire.sh --revoke`，否则 `.env` 里的记录和实际配置会不一致。

## 文件

| 文件 | 用途 |
| --- | --- |
| `issue.sh` | 本地一键：上传 → `setup.sh` → `grant.sh` → 本地校验，单次 SSH 连接 |
| `setup.sh` | 一次性安装（nginx 片段 + 到期时间表 + 脚本 + 定时器） |
| `grant.sh` | 发放限时链接 |
| `expire.sh` | 到期扫描 / 手动撤销 / 列表 |
| `clash-node-guest-sub.conf` | nginx 片段：`/var/lib/clash-node/sub/<32位hex>.yaml`，文件不存在即 410 |
