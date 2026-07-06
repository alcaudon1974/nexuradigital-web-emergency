#!/usr/bin/env bash
set -u
LOG_DIR="/root/nexura/web-maintenance"
LOG="$LOG_DIR/checks.jsonl"
mkdir -p "$LOG_DIR"
TS="$(date -Iseconds)"
DOMAIN="nexuradigital.es"
IP_EXPECTED="187.33.159.38"

status="ok"
notes=()

nginx_state="$(systemctl is-active nginx 2>/dev/null || true)"
openclaw_state="$(systemctl is-active openclaw-gateway.service 2>/dev/null || true)"
local_health="$(curl -fsS --max-time 5 http://127.0.0.1/healthz 2>/dev/null || true)"
phrase_count="$(curl -fsS --max-time 8 http://127.0.0.1/ 2>/dev/null | grep -ic 'webs para empresas en España' || true)"
openclaw_health="$(curl -fsS --max-time 8 http://127.0.0.1:1515/health 2>/dev/null || true)"
disk_pct="$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')"
mem_available_mb="$(free -m | awk '/^Mem:/{print $7}')"
dns_ip="$(getent ahostsv4 "$DOMAIN" 2>/dev/null | awk 'NR==1{print $1}' || true)"
public_domain_status="pending_dns"

if [ "$nginx_state" != "active" ]; then status="warn"; notes+=("nginx_not_active"); fi
if [ "$openclaw_state" != "active" ]; then status="warn"; notes+=("openclaw_not_active"); fi
if [ "$local_health" != "ok" ]; then status="warn"; notes+=("web_health_bad"); fi
if [ "${phrase_count:-0}" -lt 1 ]; then status="warn"; notes+=("seo_phrase_missing"); fi
if ! printf '%s' "$openclaw_health" | grep -q '"status":"live"'; then status="warn"; notes+=("openclaw_health_bad"); fi
if [ "${disk_pct:-0}" -ge 90 ]; then status="warn"; notes+=("disk_high"); fi
if [ -n "$dns_ip" ]; then
  if [ "$dns_ip" = "$IP_EXPECTED" ]; then
    public_domain_status="dns_ok"
    if ! curl -fsS --max-time 8 "http://$DOMAIN/healthz" >/dev/null 2>&1; then status="warn"; notes+=("domain_http_bad"); fi
  else
    public_domain_status="dns_wrong:$dns_ip"
    status="warn"; notes+=("dns_wrong")
  fi
else
  notes+=("dns_pending")
fi

notes_json="$(printf '%s\n' "${notes[@]}" | python3 -c 'import sys,json; print(json.dumps([x.strip() for x in sys.stdin if x.strip()], ensure_ascii=False))')"
printf '{"ts":"%s","status":"%s","nginx":"%s","openclaw":"%s","local_health":"%s","seo_phrase_count":%s,"disk_pct":%s,"mem_available_mb":%s,"dns_ip":"%s","public_domain_status":"%s","notes":%s}\n' \
  "$TS" "$status" "$nginx_state" "$openclaw_state" "$local_health" "${phrase_count:-0}" "${disk_pct:-0}" "${mem_available_mb:-0}" "$dns_ip" "$public_domain_status" "$notes_json" >> "$LOG"

tail -n 1 "$LOG"
