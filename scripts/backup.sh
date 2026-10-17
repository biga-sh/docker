#!/bin/sh
# Dumps the database to backups/biga-<time>.dump (pg_dump custom format).
# Restore with ./scripts/restore.sh <file>.
set -eu
cd "$(dirname "$0")/.."
mkdir -p backups
umask 077
file="backups/biga-$(date -u +%Y%m%dT%H%M%SZ).dump"
docker compose exec -T postgres pg_dump -U biga -d biga --format=custom >"$file"
echo "Wrote $file ($(wc -c <"$file" | tr -d ' ') bytes)"
