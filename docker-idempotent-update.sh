#!/bin/bash
set -euo pipefail

COMPOSE_DIR="${HOME}/.config/docker"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"
LOG_FILE="${HOME}/.log/docker-idempotent.log"
LOCK_FILE="${HOME}/.log/docker-idempotent.lock"
EMAIL_TO="root@denied.se"

mkdir -p "$(dirname "$LOG_FILE")"

# --- Lock ---
if [ -f "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
    echo "Already running, exiting."
    exit 0
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# --- Helpers ---
log() { echo "[$(date)] $1" | tee -a "$LOG_FILE"; }
send_mail() { echo -e "Subject: $1\n\n$2" | msmtp "$EMAIL_TO" || true; }
get_images() {
    docker compose -f "$COMPOSE_FILE" images --format '{{.Service}} {{.Repository}}:{{.Tag}} {{.ID}}' 2>/dev/null | sort || true
}

cd "$COMPOSE_DIR"

log "=== Docker update start ==="

# 1. Snapshot before
BEFORE=$(get_images)

# 2. Pull
log "Pulling images..."
docker compose -f "$COMPOSE_FILE" pull 2>&1 | tee -a "$LOG_FILE"

# 3. Up
log "Updating containers..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans 2>&1 | tee -a "$LOG_FILE"

# 4. Snapshot after
AFTER=$(get_images)

# 5. Compare
CHANGED=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -z "$CHANGED" ]; then
    log "No changes detected, exiting."
    exit 0
fi

log "Changes detected:"
echo "$CHANGED" | tee -a "$LOG_FILE"

# 6. Cleanup
docker container prune -f > /dev/null 2>&1
docker image prune -f > /dev/null 2>&1

# 7. Notify
MSG="Docker update on $(hostname) at $(date)

Changes:
$CHANGED"

send_mail "🐳 Docker update: changes applied" "$MSG"
log "=== Docker update complete ==="
