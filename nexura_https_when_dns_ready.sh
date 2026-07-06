#!/usr/bin/env bash
set -euo pipefail
DOMAIN="nexuradigital.es"
WWW="www.nexuradigital.es"
IP_EXPECTED="187.33.159.38"
EMAIL="nexuradigital2026@gmail.com"
LOG_DIR="/root/nexura/web-maintenance"
LOG="$LOG_DIR/https_dns_ready.log"
mkdir -p "$LOG_DIR"
exec >>"$LOG" 2>&1
printf '\n[%s] HTTPS check start\n' "$(date -Iseconds)"

if [ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
  echo "cert_exists"
  exit 0
fi

ip_root="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
ip_www="$(getent ahostsv4 "$WWW" 2>/dev/null | awk 'NR==1{print $1}' || true)"
echo "dns_root=${ip_root:-EMPTY} dns_www=${ip_www:-EMPTY}"

if [ "$ip_root" != "$IP_EXPECTED" ] || [ "$ip_www" != "$IP_EXPECTED" ]; then
  echo "dns_not_ready"
  exit 0
fi

if ! curl -fsS --max-time 10 "http://$DOMAIN/healthz" >/dev/null; then
  echo "domain_http_not_ready"
  exit 0
fi

if ! command -v certbot >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
fi

certbot --nginx -d "$DOMAIN" -d "$WWW" --non-interactive --agree-tos --email "$EMAIL" --redirect --keep-until-expiring
nginx -t
systemctl reload nginx
curl -fsS --max-time 10 "https://$DOMAIN/healthz"
echo "https_enabled"
