#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="$(dirname "$0")/backups"
DEST="${BACKUP_DIR}/mumble_$(date +%F).sqlite"

docker compose -f "$(dirname "$0")/docker-compose.yml" exec -T mumble \
    cat /data/mumble-server.sqlite > "$DEST"

# Backups älter als 30 Tage löschen
find "$BACKUP_DIR" -name "mumble_*.sqlite" -mtime +30 -delete

echo "Backup gespeichert: $DEST"
