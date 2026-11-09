#!/usr/bin/env bash
# 撤销到期（或指定）的访客：删除订阅文件 + 从 Xray 移除访客 UUID。
#
# 用法：
#   sudo bash expire.sh              # 清理所有已到期的访客（systemd 定时器调用）
#   sudo bash expire.sh --revoke ID  # 立刻撤销某个访客（grant.sh 输出的访客标识）
#   sudo bash expire.sh --list       # 列出仍有效的访客
set -Eeuo pipefail
umask 077

readonly XRAY_CONFIG=/usr/local/etc/xray/config.json
readonly XRAY_BIN=/usr/local/bin/xray
readonly GUEST_DIR=/root/clash-node/guests
readonly SUB_DIR=/var/lib/clash-node/sub
readonly MAP_CONF=/etc/nginx/conf.d/clash-guest-expire.conf

die() { printf '错误: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

[[ $EUID -eq 0 ]] || die '请用 root 运行'

# 退出码 3 表示配置里本来就没有这个客户端
remove_client() {
  python3 - "$XRAY_CONFIG" "$1" <<'PY'
import json, os, sys, tempfile

path, email = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as fh:
    config = json.load(fh)

inbounds = [item for item in config.get("inbounds", []) if item.get("protocol") == "vless"]
if not inbounds:
    sys.exit("config.json 里没有 vless inbound")
clients = inbounds[0].setdefault("settings", {}).setdefault("clients", [])
kept = [entry for entry in clients if entry.get("email") != email]
if len(kept) == len(clients):
    sys.exit(3)
clients[:] = kept

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
}

changed=0
map_dirty=0

# 从所有 *.env 重新生成 nginx 的 $clash_guest_expire / $clash_guest_userinfo 映射，
# 让订阅响应带上 Subscription-Userinfo: ... expire=<epoch>，客户端可显示到期时间。
sync_map() {
  local tmp env_file id token expires
  tmp=$(mktemp)
  {
    printf '# 由 grant.sh / expire.sh 自动生成，请勿手改\n'
    printf 'map $uri $clash_guest_expire {\n    default "";\n'
    for env_file in "$GUEST_DIR"/*.env; do
      [[ -e $env_file ]] || continue
      id=$(awk -F= '$1 == "GUEST_ID" {print $2; exit}' "$env_file")
      token=$(awk -F= '$1 == "GUEST_TOKEN" {print $2; exit}' "$env_file")
      expires=$(awk -F= '$1 == "GUEST_EXPIRES" {print $2; exit}' "$env_file")
      if [[ $token =~ ^[a-f0-9]{32}$ && $expires =~ ^[0-9]+$ ]]; then
        printf '    /%s.yaml %s;  # %s\n' "$token" "$expires" "$id"
      fi
    done
    printf '}\n\n'
    printf 'map $clash_guest_expire $clash_guest_userinfo {\n    ""      "";\n'
    printf '    default "upload=0; download=0; total=0; expire=$clash_guest_expire";\n}\n'
  } >"$tmp"
  install -m 644 "$tmp" "$MAP_CONF"
  rm -f "$tmp"
  nginx -t >/dev/null 2>&1 || die "nginx 配置校验失败，请检查 $MAP_CONF"
  systemctl reload nginx
}

revoke() {
  local env_file=$1 status=0
  local GUEST_ID='' GUEST_EMAIL='' GUEST_TOKEN='' GUEST_NOTE='' GUEST_DEADLINE=''
  # shellcheck disable=SC1090
  source "$env_file"
  info "撤销访客 ${GUEST_ID:-$env_file}（${GUEST_EMAIL:-?}）"
  if [[ -n $GUEST_TOKEN ]]; then
    rm -f "$SUB_DIR/$GUEST_TOKEN.yaml"
  fi
  remove_client "$GUEST_EMAIL" || status=$?
  if (( status == 0 )); then
    changed=1
  elif (( status == 3 )); then
    info '  Xray 中已无该客户端，跳过'
  else
    die "移除 Xray 客户端失败（退出码 $status）"
  fi
  mv "$env_file" "$env_file.revoked"
  map_dirty=1
}

case ${1:-} in
  --list)
    printf '%-14s %-22s %-24s %s\n' 标识 备注 到期 状态
    for env_file in "$GUEST_DIR"/*.env; do
      [[ -e $env_file ]] || continue
      # shellcheck disable=SC1090
      (
        GUEST_ID='' GUEST_NOTE='' GUEST_DEADLINE='' GUEST_EXPIRES=0 GUEST_DEADLINE_LOCAL=''
        source "$env_file"
        if (( $(date +%s) >= GUEST_EXPIRES )); then state=待清理; else state=有效; fi
        printf '%-14s %-22s %-24s %s\n' "$GUEST_ID" "$GUEST_NOTE" "${GUEST_DEADLINE_LOCAL:-$GUEST_DEADLINE}" "$state"
      )
    done
    exit 0
    ;;
  --revoke)
    id=${2:-}
    [[ -n $id ]] || die '请提供访客标识：sudo bash expire.sh --revoke 3f2a1b4c5d6e'
    env_file=$(compgen -G "$GUEST_DIR/$id*.env" | head -n1 || true)
    [[ -n $env_file ]] || die "找不到访客 $id（可能已撤销）"
    revoke "$env_file"
    ;;
  --sync-map)
    sync_map
    info "已更新 $MAP_CONF 并重载 nginx"
    exit 0
    ;;
  '')
    now=$(date +%s)
    for env_file in "$GUEST_DIR"/*.env; do
      [[ -e $env_file ]] || continue
      expires=$(awk -F= '$1 == "GUEST_EXPIRES" {print $2; exit}' "$env_file")
      if [[ ! $expires =~ ^[0-9]+$ ]]; then
        info "跳过格式异常的 $env_file"
        continue
      fi
      if (( now >= expires )); then
        revoke "$env_file"
      fi
    done
    ;;
  *)
    die '未知参数，可选：--revoke ID / --list'
    ;;
esac

if (( changed )); then
  "$XRAY_BIN" run -test -config "$XRAY_CONFIG" >/dev/null || die 'Xray 配置校验失败，未重启服务'
  systemctl restart xray
  sleep 2
  systemctl is-active --quiet xray || die 'xray 重启后未保持运行，请查看 journalctl -u xray'
fi
if (( changed || map_dirty )); then
  sync_map
fi
if (( changed )); then
  info '已重启 xray 并更新到期时间表，访客节点凭据立即失效'
elif (( map_dirty )); then
  info '已更新到期时间表'
fi
exit 0
