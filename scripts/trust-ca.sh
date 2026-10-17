#!/bin/sh
# Exports the root certificate of Caddy's local CA (internal mode), so
# browsers and the biga CLI on other devices accept this server's HTTPS.
set -eu
cd "$(dirname "$0")/.."
out=biga-root-ca.crt
docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt "$out" >/dev/null
echo "Wrote $out. Install it once on every device that opens the site or runs biga:"
cat <<'EOF2'

  macOS     sudo security add-trusted-cert -d -r trustRoot \
              -k /Library/Keychains/System.keychain biga-root-ca.crt
  Debian, Ubuntu
            sudo cp biga-root-ca.crt /usr/local/share/ca-certificates/ \
              && sudo update-ca-certificates
  Fedora, RHEL
            sudo cp biga-root-ca.crt /etc/pki/ca-trust/source/anchors/ \
              && sudo update-ca-trust
  Windows   certutil -addstore -f Root biga-root-ca.crt   (as Administrator)

Firefox keeps its own store: Settings > Privacy & Security > Certificates >
View Certificates > Authorities > Import. Phones: open the file and follow
the prompts (iOS also needs Settings > General > About > Certificate Trust
Settings).

The certificate only proves who this server is; it cannot read anyone's
traffic. Keep the private key, in the caddy-data volume, private.
EOF2
