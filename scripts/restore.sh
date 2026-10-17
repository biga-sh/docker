#!/bin/sh
# Restores a dump from ./scripts/backup.sh, replacing the current data.
set -eu
cd "$(dirname "$0")/.."
if [ $# -ne 1 ] || [ ! -f "$1" ]; then
	echo "usage: restore.sh backups/biga-<time>.dump" >&2
	exit 2
fi
printf 'This replaces every session in the database with %s. Continue? [y/N] ' "$1"
read -r answer
case "$answer" in y | Y | yes) ;; *) echo "Cancelled."; exit 1 ;; esac
docker compose stop server
docker compose exec -T postgres pg_restore -U biga -d biga --clean --if-exists --no-owner <"$1"
docker compose start server
echo "Restored $1."
