#!/usr/bin/env bash
# 一次性安装：让已用 deploy.sh 部署好的节点支持「限时访客订阅链接」。
#
#   sudo bash setup.sh
#
# 做四件事：
#   1) 安装 nginx 片段并在 clash-node-subscription 站点里 include 它（幂等）
#   2) 创建 /var/lib/clash-node/sub 目录
#   3) 把 grant.sh / expire.sh 安装到 /root/clash-node/guests
#   4) 安装每 5 分钟扫描一次到期访客的 systemd 定时器
set -Eeuo pipefail
umask 077

readonly HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SITE=/etc/nginx/sites-available/clash-node-subscription
readonly SNIPPET=/etc/nginx/snippets/clash-node-guest-sub.conf
readonly MAP_CONF=/etc/nginx/conf.d/clash-guest-expire.conf
readonly SUB_DIR=/var/lib/clash-node/sub
readonly GUEST_DIR=/root/clash-node/guests

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

[[ $EUID -eq 0 ]] || die '请用 root 运行：sudo bash setup.sh'
[[ -f $SITE ]] || die "找不到 $SITE，请先运行 deploy.sh 完成节点部署"
[[ -f $HERE/grant.sh && -f $HERE/expire.sh && -f $HERE/clash-node-guest-sub.conf ]] \
  || die "安装文件不完整，请确认 $HERE 下有 grant.sh、expire.sh、clash-node-guest-sub.conf"

info '安装 nginx 片段与目录...'
install -d -m 755 /etc/nginx/snippets
install -d -m 750 -o root -g www-data "$SUB_DIR"
install -d -m 700 "$GUEST_DIR"
install -m 644 "$HERE/clash-node-guest-sub.conf" "$SNIPPET"

# 空的到期时间表（map 必须在 http 上下文，所以放在 conf.d 而不是 server 块里）
if [[ ! -f $MAP_CONF ]]; then
  cat >"$MAP_CONF" <<'EOF'
# 由 grant.sh / expire.sh 自动生成，请勿手改
map $uri $clash_guest_expire {
    default "";
}

map $clash_guest_expire $clash_guest_userinfo {
    ""      "";
    default "upload=0; download=0; total=0; expire=$clash_guest_expire";
}
EOF
  chmod 644 "$MAP_CONF"
fi
grep -q 'conf.d/\*.conf' /etc/nginx/nginx.conf \
  || die '/etc/nginx/nginx.conf 未 include conf.d/*.conf，无法注入到期时间表'

info '在站点配置中加入 include...'
python3 - "$SITE" <<'PY' || exit 1
import pathlib, shutil, sys, time

site = pathlib.Path(sys.argv[1])
text = site.read_text(encoding="utf-8")
include = "    include /etc/nginx/snippets/clash-node-guest-sub.conf;"

if include in text:
    print("已存在 include，跳过")
    raise SystemExit(0)

anchor = "    location / { return 404; }"
if anchor not in text:
    sys.exit(f"未在 {site} 中找到 `{anchor.strip()}`，请手动把 include 放在 404 规则之前")

backup = site.with_name(site.name + time.strftime(".bak-%Y%m%d-%H%M%S"))
shutil.copy2(site, backup)
site.write_text(text.replace(anchor, include + "\n" + anchor, 1), encoding="utf-8")
print(f"已修改 {site}，备份 {backup}")
PY

nginx -t || die 'nginx 配置校验失败，请检查上面的报错并手动修正'
systemctl reload nginx

info '安装 grant.sh / expire.sh...'
install -m 755 "$HERE/grant.sh" "$GUEST_DIR/grant.sh"
install -m 755 "$HERE/expire.sh" "$GUEST_DIR/expire.sh"

info '安装到期扫描定时器...'
cat >/etc/systemd/system/clash-guest-expiry.service <<EOF
[Unit]
Description=Revoke expired Clash guest subscription links

[Service]
Type=oneshot
ExecStart=/root/clash-node/guests/expire.sh
EOF
cat >/etc/systemd/system/clash-guest-expiry.timer <<'EOF'
[Unit]
Description=Scan for expired Clash guest subscriptions every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now clash-guest-expiry.timer

info ''
info '安装完成。发一个 24 小时的链接：'
info '  sudo bash /root/clash-node/guests/grant.sh 24'
info '查看仍有效的访客：'
info '  sudo bash /root/clash-node/guests/expire.sh --list'
info '定时器状态：systemctl list-timers clash-guest-expiry.timer'
