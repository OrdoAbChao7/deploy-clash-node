#!/usr/bin/env bash
# 发放一个「限时远程订阅链接」：到期后自动失效。
#
# 用法（在已由 deploy.sh 部署好的服务器上执行）：
#   sudo bash grant.sh                          # 24 小时
#   sudo bash grant.sh 6                        # 6 小时
#   sudo bash grant.sh 24 alice                 # 备注名 alice
#   sudo bash grant.sh --until 2026-11-30       # 到该日 23:59:59（服务器本地时区）
#   sudo bash grant.sh --until 2026-11-30 18:00 # 到该日 18:00
#   sudo bash grant.sh --until 2026-11-30 23:59:59 alice
#
# 做两件事：
#   1) 在 Xray 里新增一个访客专属 UUID（不影响你自己的节点凭据）
#   2) 生成只含该 UUID 的 Clash 配置，放到 nginx 的限时订阅目录
# 到期后由 expire.sh（systemd 定时器每 5 分钟扫一次）删除订阅文件并撤销 UUID。
set -Eeuo pipefail
umask 077

readonly XRAY_CONFIG=/usr/local/etc/xray/config.json
readonly XRAY_BIN=/usr/local/bin/xray
readonly OWNER_PROFILE=/root/clash-node/profile.yaml
readonly GUEST_DIR=/root/clash-node/guests
readonly SUB_DIR=/var/lib/clash-node/sub

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

HOURS=''
NOTE=guest
UNTIL_DAY=''
UNTIL_TIME='23:59:59'
case ${1:-} in
  --until)
    UNTIL_DAY=${2:-}
    [[ -n $UNTIL_DAY ]] || die '用法：grant.sh --until 2026-11-30 [HH:MM[:SS]] [备注]'
    UNTIL_TIME=${3:-23:59:59}
    NOTE=${4:-guest}
    ;;
  --help|-h)
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  '')
    HOURS=24
    ;;
  *)
    HOURS=$1
    NOTE=${2:-guest}
    ;;
esac

[[ $EUID -eq 0 ]] || die '请用 root 运行：sudo bash grant.sh 24'
[[ $NOTE =~ ^[A-Za-z0-9._-]{1,32}$ ]] || die '备注只能用字母、数字、点、下划线、短横线（≤32 字符）'
if [[ -n $UNTIL_DAY ]]; then
  [[ $UNTIL_DAY =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die '日期格式应为 YYYY-MM-DD，例如 2026-11-30'
  [[ $UNTIL_TIME =~ ^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]] || die '时间格式应为 HH:MM 或 HH:MM:SS'
else
  [[ $HOURS =~ ^[0-9]+$ ]] && (( HOURS > 0 )) || die '小时数必须是正整数，例如 24；或改用 --until YYYY-MM-DD'
fi
[[ -f $XRAY_CONFIG ]] || die "找不到 $XRAY_CONFIG，请先运行 deploy.sh"
[[ -f $OWNER_PROFILE ]] || die "找不到 $OWNER_PROFILE，请先运行 deploy.sh"
[[ -x $XRAY_BIN ]] || die "找不到 $XRAY_BIN"
[[ -d /etc/nginx/snippets ]] || die '未找到 nginx 片段目录，请先运行 setup.sh'

field() { awk -v k="$1" '$1 == k":" {print $2; exit}' "$OWNER_PROFILE"; }

NODE_SERVER=$(field server)
NODE_PORT=$(field port)
NODE_SNI=$(field servername)
NODE_PUBKEY=$(field public-key)
NODE_SHORTID=$(field short-id)
for name in NODE_SERVER NODE_PORT NODE_SNI NODE_PUBKEY NODE_SHORTID; do
  [[ -n ${!name} ]] || die "无法从 $OWNER_PROFILE 解析 ${name#NODE_}"
done

read -r GUEST_ID GUEST_UUID GUEST_TOKEN < <(python3 - <<'PY'
import secrets, uuid
print(secrets.token_hex(6), uuid.uuid4(), secrets.token_hex(16))
PY
)
GUEST_EMAIL="guest-$GUEST_ID"
if [[ -n $UNTIL_DAY ]]; then
  GUEST_EXPIRES=$(date -d "$UNTIL_DAY $UNTIL_TIME" +%s 2>/dev/null) || die "无法解析日期 $UNTIL_DAY $UNTIL_TIME"
  (( GUEST_EXPIRES > $(date +%s) )) || die "$UNTIL_DAY $UNTIL_TIME 已经过去了"
else
  GUEST_EXPIRES=$(( $(date +%s) + HOURS * 3600 ))
fi
GUEST_DEADLINE_UTC=$(date -u -d "@$GUEST_EXPIRES" '+%Y-%m-%d %H:%M UTC')
GUEST_DEADLINE_LOCAL=$(date -d "@$GUEST_EXPIRES" '+%Y-%m-%d %H:%M %Z')
GUEST_DEADLINE=$GUEST_DEADLINE_UTC

install -d -m 700 "$GUEST_DIR"
install -d -m 750 -o root -g www-data "$SUB_DIR"
[[ -x $GUEST_DIR/expire.sh ]] || die "找不到 $GUEST_DIR/expire.sh，请先运行 setup.sh"

# 任何一步失败都用 expire.sh 走正规撤销路径清干净，不留可用凭据。
rollback() {
  info "回滚本次发放 $GUEST_ID ..."
  bash "$GUEST_DIR/expire.sh" --revoke "$GUEST_ID" >/dev/null 2>&1 \
    || info "回滚未完成，请手动：bash $GUEST_DIR/expire.sh --revoke $GUEST_ID"
}

cat >"$GUEST_DIR/$GUEST_ID.env" <<EOF
GUEST_ID=$GUEST_ID
GUEST_EMAIL=$GUEST_EMAIL
GUEST_UUID=$GUEST_UUID
GUEST_TOKEN=$GUEST_TOKEN
GUEST_EXPIRES=$GUEST_EXPIRES
GUEST_DEADLINE="$GUEST_DEADLINE_UTC"
GUEST_DEADLINE_LOCAL="$GUEST_DEADLINE_LOCAL"
GUEST_NOTE="$NOTE"
EOF
chmod 600 "$GUEST_DIR/$GUEST_ID.env"

info "新增 Xray 客户端 $GUEST_EMAIL，到期时间 $GUEST_DEADLINE_LOCAL（$GUEST_DEADLINE_UTC）"
if ! python3 - "$XRAY_CONFIG" "$GUEST_UUID" "$GUEST_EMAIL" <<'PY'
import json, os, sys, tempfile

path, uuid, email = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as fh:
    config = json.load(fh)

inbounds = [item for item in config.get("inbounds", []) if item.get("protocol") == "vless"]
if not inbounds:
    sys.exit("config.json 里没有 vless inbound")
clients = inbounds[0].setdefault("settings", {}).setdefault("clients", [])
clients[:] = [entry for entry in clients if entry.get("email") != email]
clients.append({"id": uuid, "flow": "xtls-rprx-vision", "email": email})

stat = os.stat(path)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    json.dump(config, fh, indent=2)
    fh.write("\n")
os.chmod(tmp, stat.st_mode & 0o7777)
try:
    os.chown(tmp, stat.st_uid, stat.st_gid)
except (AttributeError, PermissionError):
    pass
os.replace(tmp, path)
PY
then
  rollback
  die '写入 Xray 客户端失败'
fi

"$XRAY_BIN" run -test -config "$XRAY_CONFIG" >/dev/null || { rollback; die 'Xray 配置校验失败，未重启服务'; }
systemctl restart xray || { rollback; die 'xray 重启失败'; }
sleep 2
systemctl is-active --quiet xray || { rollback; die 'xray 重启后未保持运行，请查看 journalctl -u xray'; }
ss -ltnH | awk '{print $4}' | grep -Eq '(^|:)443$' || { rollback; die '443 端口未在监听'; }

info '生成访客配置...'
tmp_profile=$(mktemp)
trap 'rm -f "$tmp_profile"' EXIT
cat >"$tmp_profile" <<EOF
mode: rule
proxies:
  - name: Guest-$GUEST_ID
    type: vless
    server: $NODE_SERVER
    port: $NODE_PORT
    uuid: $GUEST_UUID
    network: tcp
    udp: true
    tls: true
    servername: $NODE_SNI
    client-fingerprint: chrome
    flow: xtls-rprx-vision
    reality-opts:
      public-key: $NODE_PUBKEY
      short-id: $NODE_SHORTID
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - Guest-$GUEST_ID
      - DIRECT
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
install -m 640 -o root -g www-data "$tmp_profile" "$SUB_DIR/$GUEST_TOKEN.yaml" || { rollback; die '写入订阅文件失败'; }

info '写入到期时间表并重载 nginx...'
if ! bash "$GUEST_DIR/expire.sh" --sync-map >/dev/null; then
  rollback
  die '写入 nginx 到期时间表失败，请检查 nginx -t'
fi

SUBSCRIPTION_URL="https://$NODE_SERVER:8443/$GUEST_TOKEN.yaml"
if ! printf 'url = "%s"\n' "$SUBSCRIPTION_URL" \
  | curl -K - --noproxy '*' --connect-to "$NODE_SERVER:8443:127.0.0.1:8443" -fsS --max-time 20 \
  | cmp -s - "$SUB_DIR/$GUEST_TOKEN.yaml"; then
  rollback
  die "订阅自检失败：确认 TCP 8443 已放行、setup.sh 已执行"
fi

info ''
info "订阅链接: $SUBSCRIPTION_URL"
if [[ -n $UNTIL_DAY ]]; then
  info "有效期至: $GUEST_DEADLINE_LOCAL（$GUEST_DEADLINE_UTC，届时自动失效）"
else
  info "有效期至: $GUEST_DEADLINE_LOCAL（$GUEST_DEADLINE_UTC，$HOURS 小时后自动失效）"
fi
info "访客标识: $GUEST_ID（备注 $NOTE）"
info ''
info '提前撤销: sudo bash /root/clash-node/guests/expire.sh --revoke '"$GUEST_ID"
info '查看列表: sudo bash /root/clash-node/guests/expire.sh --list'
