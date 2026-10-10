#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

readonly XRAY_CONFIG=/usr/local/etc/xray/config.json
readonly PROFILE_DIR=/root/clash-node
readonly PROFILE_FILE=$PROFILE_DIR/profile.yaml
readonly WEB_DIR=/var/lib/clash-node
readonly WEB_FILE=$WEB_DIR/profile.yaml
readonly NGINX_SITE=/etc/nginx/sites-available/clash-node-subscription
readonly CERTBOT=/opt/clash-node-certbot/bin/certbot
readonly INSTALLER_URL=https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

if [[ ${1:-} == --help ]]; then
  cat <<'HELP'
Usage: sudo bash deploy.sh

Deploy a new VLESS Reality node and HTTPS Clash subscription on a clean Ubuntu
24.04 x86_64 server. Optional environment variables: NODE_IP, REALITY_SNI,
LE_EMAIL. Ports 80, 443 and 8443 must be reachable from the Internet.

The script stops if these ports or its configuration paths are already used.
It does not modify an existing Xray installation.
HELP
  exit 0
fi
[[ $# -eq 0 ]] || die 'Unknown option. Run --help.'
[[ $EUID -eq 0 ]] || die 'Run as root (sudo bash deploy.sh).'
[[ -r /etc/os-release ]] || die 'Cannot identify the operating system.'
source /etc/os-release
[[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || die 'Ubuntu 24.04 is required.'
[[ $(uname -m) == x86_64 ]] || die 'x86_64 is required.'

for command in curl ss python3 systemctl; do
  command -v "$command" >/dev/null || die "Missing command: $command"
done
for port in 80 443 8443; do
  if ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
    die "TCP port $port is already in use. Stop here and inspect the service."
  fi
done
for path in "$XRAY_CONFIG" "$PROFILE_DIR" "$WEB_DIR" "$NGINX_SITE" /etc/systemd/system/clash-node-cert.timer; do
  [[ ! -e $path ]] || die "Existing deployment path: $path"
done
[[ ! -x /usr/local/bin/xray ]] || die 'Xray is already installed.'

NODE_IP=${NODE_IP:-$(curl --noproxy '*' -fsS4 --max-time 10 https://api.ipify.org)}
REALITY_SNI=${REALITY_SNI:-www.cloudflare.com}
python3 - "$NODE_IP" "$REALITY_SNI" <<'PY' || die 'Invalid NODE_IP or REALITY_SNI.'
import ipaddress, re, sys
ipaddress.IPv4Address(sys.argv[1])
assert re.fullmatch(r"[A-Za-z0-9.-]{1,253}", sys.argv[2])
assert "." in sys.argv[2] and ".." not in sys.argv[2]
PY
curl --noproxy '*' -sSI --max-time 10 "https://$REALITY_SNI/" >/dev/null || die 'Reality target is not reachable from this server.'

info 'Installing Xray, Nginx and Certbot...'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl nginx openssl python3-venv
python3 -m venv /opt/clash-node-certbot
"/opt/clash-node-certbot/bin/pip" install -q 'certbot>=5.4,<6'
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
curl --noproxy '*' -fsSL --retry 3 "$INSTALLER_URL" -o "$installer"
bash "$installer" install --without-geodata
[[ -x /usr/local/bin/xray ]] || die 'Xray installation did not produce a binary.'

key_output=$(/usr/local/bin/xray x25519)
private_key=$(awk '/^PrivateKey:/ {print $2; exit}' <<<"$key_output")
public_key=$(awk '/^(Password \(PublicKey\)|PublicKey):/ {print $NF; exit}' <<<"$key_output")
[[ -n $private_key && -n $public_key ]] || die 'Could not parse Xray key pair.'
uuid=$(cat /proc/sys/kernel/random/uuid)
short_id=$(openssl rand -hex 8)
token=$(openssl rand -hex 32)
node_name=Self-hosted-Reality

cat >"$XRAY_CONFIG" <<EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "listen": "0.0.0.0", "port": 443, "protocol": "vless",
    "settings": {"clients": [{"id": "$uuid", "flow": "xtls-rprx-vision"}], "decryption": "none"},
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "dest": "$REALITY_SNI:443", "serverNames": ["$REALITY_SNI"],
        "privateKey": "$private_key", "shortIds": ["$short_id"]
      }
    }
  }],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}]
}
EOF
service_user=$(systemctl show -p User --value xray)
service_user=${service_user:-root}
service_group=$(id -gn "$service_user")
chown "$service_user:$service_group" "$XRAY_CONFIG"
chmod 600 "$XRAY_CONFIG"
/usr/local/bin/xray run -test -config "$XRAY_CONFIG"
systemctl enable --now xray
systemctl restart xray
sleep 2
systemctl is-active --quiet xray || die 'Xray failed to start.'
ss -ltnH | awk '{print $4}' | grep -Eq '(^|:)443$' || die 'Xray is not listening on TCP 443.'

install -d -m 700 "$PROFILE_DIR"
cat >"$PROFILE_FILE" <<EOF
mode: rule
proxies:
  - name: $node_name
    type: vless
    server: $NODE_IP
    port: 443
    uuid: $uuid
    network: tcp
    udp: true
    tls: true
    servername: $REALITY_SNI
    client-fingerprint: chrome
    flow: xtls-rprx-vision
    reality-opts:
      public-key: $public_key
      short-id: $short_id
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - $node_name
      - DIRECT
rules:
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
EOF
chmod 600 "$PROFILE_FILE"

info 'Requesting a short-lived HTTPS certificate for the server IP...'
systemctl enable --now nginx
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow 80/tcp
fi
cert_args=(certonly --preferred-profile shortlived --webroot --webroot-path /var/www/html
  --ip-address "$NODE_IP" --non-interactive --agree-tos)
if [[ -n ${LE_EMAIL:-} ]]; then
  cert_args+=(--email "$LE_EMAIL")
else
  cert_args+=(--register-unsafely-without-email)
fi
"$CERTBOT" "${cert_args[@]}"

install -d -m 750 -o root -g www-data "$WEB_DIR"
install -m 640 -o root -g www-data "$PROFILE_FILE" "$WEB_FILE"
cat >"$NGINX_SITE" <<EOF
server {
    listen 8443 ssl;
    server_name $NODE_IP;
    ssl_certificate /etc/letsencrypt/live/$NODE_IP/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$NODE_IP/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    location = /$token.yaml {
        alias $WEB_FILE;
        default_type application/yaml;
        add_header Cache-Control "private, no-store" always;
    }
    location / { return 404; }
}
EOF
ln -s "$NGINX_SITE" /etc/nginx/sites-enabled/clash-node-subscription
nginx -t
systemctl reload nginx

cat >/etc/systemd/system/clash-node-cert.service <<EOF
[Unit]
Description=Renew short-lived Clash subscription certificate
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$CERTBOT renew --quiet --deploy-hook "/usr/bin/systemctl reload nginx"
EOF
cat >/etc/systemd/system/clash-node-cert.timer <<'EOF'
[Unit]
Description=Check Clash subscription certificate renewal twice daily

[Timer]
OnCalendar=*-*-* 03,15:00:00
RandomizedDelaySec=30m
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now clash-node-cert.timer
if command -v ufw >/dev/null && ufw status | grep -q '^Status: active'; then
  ufw allow 443/tcp
  ufw allow 8443/tcp
fi

subscription_url="https://$NODE_IP:8443/$token.yaml"
printf 'url = "%s"\n' "$subscription_url" | curl -K - --noproxy '*' --connect-to "$NODE_IP:8443:127.0.0.1:8443" -fsS --max-time 20 | cmp -s - "$PROFILE_FILE" \
  || die 'HTTPS subscription check failed. Check the cloud firewall for TCP 8443.'
info 'Testing certificate renewal (this may take several minutes)...'
timeout 300 "$CERTBOT" renew --dry-run --non-interactive

cat >"$PROFILE_DIR/access.txt" <<EOF
Subscription: $subscription_url
Local profile: $PROFILE_FILE
Server config: $XRAY_CONFIG
EOF
chmod 600 "$PROFILE_DIR/access.txt"
info 'Deployment complete.'
info "Subscription: $subscription_url"
info "Local profile: $PROFILE_FILE"
info "Access details: $PROFILE_DIR/access.txt"
info 'Keep the subscription URL private: it grants access to node credentials.'
