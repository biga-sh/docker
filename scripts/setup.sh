#!/bin/sh
# Writes .env for this stack: asks how people will reach it, generates the
# database password and an access key, and prints how to point the CLI here.
#
#   ./scripts/setup.sh                 ask
#   ./scripts/setup.sh --mode internal --domain 10.0.0.5 --yes
#   ./scripts/setup.sh --force         replace an existing .env
set -eu

cd "$(dirname "$0")/.."

mode="" domain="" bind="" keys="yes" force="" yes=""
http_port=80 https_port=443

usage() {
	cat <<'EOF'
Usage: setup.sh [options]

  --mode public|internal|http   How people reach the server (see the README)
  --domain NAME                 Domain name, or an IP address in internal/http mode
  --bind ADDRESS                Listen on one address only (IPv6 in brackets)
  --http-port N --https-port N  Host ports (default 80 and 443)
  --no-access-key               Let anyone who can reach the server broadcast
  --yes                         Accept defaults instead of asking
  --force                       Overwrite an existing .env
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
	--mode) mode=$2; shift 2 ;;
	--domain) domain=$2; shift 2 ;;
	--bind) bind=$2; shift 2 ;;
	--http-port) http_port=$2; shift 2 ;;
	--https-port) https_port=$2; shift 2 ;;
	--no-access-key) keys=""; shift ;;
	--yes) yes=1; shift ;;
	--force) force=1; shift ;;
	-h | --help) usage; exit 0 ;;
	*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
	esac
done

if [ -f .env ] && [ -z "$force" ]; then
	echo ".env already exists; pass --force to replace it." >&2
	exit 1
fi

# ask CURRENT QUESTION DEFAULT prints CURRENT when a flag already set it,
# otherwise the answer to QUESTION (or DEFAULT without a terminal or --yes).
ask() {
	if [ -n "$1" ]; then
		printf '%s' "$1"
	elif [ -n "$yes" ] || [ ! -t 0 ]; then
		printf '%s' "$3"
	else
		printf '%s [%s]: ' "$2" "$3" >&2
		read -r answer
		printf '%s' "${answer:-$3}"
	fi
}

# 32 random bytes as URL-safe base64, the same shape biga-server gen-key prints.
random() {
	head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'
}

echo "How will people reach this server?"
echo "  public    a domain name on the internet (HTTPS from Let's Encrypt)"
echo "  internal  a private network: office LAN, VPN, homelab (HTTPS from a local CA)"
echo "  http      plain HTTP, for a network you fully trust"
mode=$(ask "$mode" "Mode" public)
case "$mode" in public | internal | http) ;; *) echo "unknown mode: $mode" >&2; exit 2 ;; esac

case "$mode" in
public) domain=$(ask "$domain" "Domain (its A/AAAA records must point here)" biga.example.com) ;;
*) domain=$(ask "$domain" "Name or IP address people will type" "$(hostname 2>/dev/null || echo localhost)") ;;
esac

# The public URL: the address plus the port when it is not the default.
host=$domain
case "$domain" in
*:*:*) case "$domain" in \[*) ;; *) host="[$domain]" ;; esac ;; # bare IPv6
esac
if [ "$mode" = http ]; then
	url="http://$host"
	[ "$http_port" = 80 ] || url="$url:$http_port"
else
	url="https://$host"
	[ "$https_port" = 443 ] || url="$url:$https_port"
fi

access_key=""
if [ -n "$keys" ]; then
	access_key="bgk_$(random)"
fi

umask 077
cat >.env <<EOF
# Written by scripts/setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ). Keep it private.
BIGA_PROXY_MODE=$mode
BIGA_DOMAIN=$host
BIGA_PUBLIC_URL=$url
BIGA_BIND_ADDRESS=$bind
BIGA_HTTP_PORT=$http_port
BIGA_HTTPS_PORT=$https_port
BIGA_UPSTREAM_PROXIES=127.0.0.1/32

POSTGRES_PASSWORD=$(random)
BIGA_ACCESS_KEYS=$access_key
VALKEY_PASSWORD=$(random)

BIGA_RETENTION_DAYS=30
BIGA_READ_RATE_LIMIT=3000
BIGA_LOG_LEVEL=info
BIGA_DEMO_SESSION_ID=
EOF
chmod 600 .env

cat <<EOF

Wrote .env ($mode mode, $url).

Next:
  docker compose up -d --build        # the first build takes a few minutes
  docker compose ps                   # wait for every service to be healthy

Then broadcast from any machine that can reach it:
EOF
if [ -n "$access_key" ]; then
	echo "  BIGA_API_URL=$url BIGA_ACCESS_KEY=$access_key biga start"
	echo
	echo "Only people with that key can broadcast. Viewers need just the link."
else
	echo "  BIGA_API_URL=$url biga start"
	echo
	echo "Anyone who can reach this server can broadcast through it."
fi
if [ "$mode" = internal ]; then
	echo
	echo "Internal mode uses a local certificate authority. Once the stack is up,"
	echo "run ./scripts/trust-ca.sh and install the certificate on each device."
fi
if [ "$mode" = http ]; then
	echo
	echo "HTTP mode sends owner tokens and access keys in clear text. Use it only"
	echo "on a network you trust, or behind something that adds TLS."
fi
