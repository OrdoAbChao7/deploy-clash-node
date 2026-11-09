#!/usr/bin/env bash
# 一条命令完成：上传脚本 → 服务器安装 → 发放到期订阅链接 → 本地校验。
#
# 用法（在本地 Git Bash / WSL 里跑，不要用 cmd）：
#   bash issue.sh                          # 第一次会问服务器 IP，默认 2026-11-30 到期
#   bash issue.sh 203.0.113.10             # 指定服务器
#   bash issue.sh 203.0.113.10 2026-11-30
#   bash issue.sh 203.0.113.10 2026-11-30 23:59:59 alice
#
# 环境变量：SSH_USER（默认 root）、SSH_PORT（默认 22）
set -Eeuo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONF=$HERE/.issue-server
DEFAULT_UNTIL=2026-11-30

info() { printf '%s\n' "$*"; }
die() { printf '\n错误: %s\n' "$*" >&2; exit 1; }

HOST=${1:-}
UNTIL_DAY=${2:-$DEFAULT_UNTIL}
UNTIL_TIME=${3:-23:59:59}
NOTE=${4:-guest}
SSH_USER=${SSH_USER:-root}
SSH_PORT=${SSH_PORT:-22}

[[ $SSH_USER == root ]] || die '本脚本要求 root 登录（deploy.sh 部署的目录都在 /root 下）。可设 SSH_USER=root。'

if [[ -z $HOST ]]; then
  if [[ -f $CONF ]]; then
    HOST=$(cat "$CONF")
    info "使用上次的服务器: $HOST（想换就 bash issue.sh <新IP>）"
  else
    read -r -p '服务器 IP: ' HOST
  fi
fi
[[ -n $HOST ]] || die '需要服务器 IP'
printf '%s\n' "$HOST" >"$CONF"

[[ $UNTIL_DAY =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "到期日格式应为 YYYY-MM-DD，收到的：$UNTIL_DAY"
[[ $UNTIL_TIME =~ ^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]] || die "时间格式应为 HH:MM 或 HH:MM:SS，收到的：$UNTIL_TIME"

# 远端引导脚本：把整个目录搬到 /root，然后 setup + grant
BOOT=$(mktemp -d)
LOG=$HERE/issue-$(date +%Y%m%d-%H%M%S).log
cleanup() { rm -rf "$BOOT"; }
trap cleanup EXIT

cat >"$BOOT/remote-run.sh" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
install -d -m 755 /root/expiring-subscription
cp -a /tmp/esboot/expiring-subscription/. /root/expiring-subscription/
rm -rf /tmp/esboot
bash /root/expiring-subscription/setup.sh
bash /root/clash-node/guests/grant.sh --until $UNTIL_DAY $UNTIL_TIME $NOTE
EOF

info ''
info "目标: root@$HOST:$SSH_PORT"
info "到期: $UNTIL_DAY $UNTIL_TIME（服务器本地时区）"
info '开始执行，接下来会提示一次 SSH 密码...'
info ''

if ! tar -czf - \
      --exclude='issue-*.log' --exclude='.issue-server' \
      -C "$(dirname -- "$HERE")" expiring-subscription \
      -C "$BOOT" remote-run.sh \
    | ssh -p "$SSH_PORT" \
        -o StrictHostKeyChecking=accept-new \
        -o LogLevel=ERROR \
        -o ServerAliveInterval=30 \
        "$SSH_USER@$HOST" \
        'rm -rf /tmp/esboot && mkdir -p /tmp/esboot && tar xzf - -C /tmp/esboot && bash /tmp/esboot/remote-run.sh' \
        2>&1 | tee "$LOG"; then
  die "远程执行失败。日志: $LOG"
fi
chmod 600 "$LOG"

URL=$(grep -oE 'https://[0-9.]+(:[0-9]+)?/[a-f0-9]{32}\.yaml' "$LOG" | tail -n1 || true)
[[ -n $URL ]] || die "没在输出里找到订阅链接，请查看日志: $LOG"

info ''
info '本地校验订阅可拉取性...'
HDRS=$(curl -sSI --max-time 25 "$URL" 2>&1 || true)
CODE=$(printf '%s' "$HDRS" | head -n1 | tr -d '\r' | awk '{print $2}')
USERINFO=$(printf '%s' "$HDRS" | tr -d '\r' | grep -i '^subscription-userinfo:' || true)
EXPIRE=$(printf '%s' "$USERINFO" | sed 's/.*expire=\([0-9]*\).*/\1/' || true)

info ''
info '================== 完成 =================='
info "订阅链接: $URL"
if [[ -z $CODE ]]; then
  info 'HTTP: 本地连不上 8443（可能你的网络拦了该端口）'
  info '      链接已生成，建议用手机流量打开一次确认；对方能连上就行。'
elif [[ $CODE == 200 ]]; then
  info "HTTP: 200（可拉取）"
else
  info "HTTP: $CODE（异常，检查 TCP 8443 放行与 setup.sh 是否执行）"
fi
if [[ -n $EXPIRE && $EXPIRE =~ ^[0-9]+$ ]]; then
  info "客户端显示到期: $(date -d "@$EXPIRE" '+%Y-%m-%d %H:%M %Z')  /  $(date -u -d "@$EXPIRE" '+%Y-%m-%d %H:%M UTC')"
else
  info '客户端到期信息: 未取到（订阅头缺失，不影响实际失效）'
fi
info "服务器日志: /root/clash-node/guests/ 下的 *.env"
info "本次日志: $LOG（含凭据，别外传；权限已设 600）"
info '=========================================='
info ''
info '把这个链接发给对方，让他导入 Clash Verge / Mihomo 即可。'
info "核对谁还有效: ssh -p $SSH_PORT $SSH_USER@$HOST 'bash /root/clash-node/guests/expire.sh --list'"
