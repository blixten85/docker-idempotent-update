#!/bin/bash
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-${HOME}/.config/docker}"
COMPOSE_FILE="${COMPOSE_FILE:-${COMPOSE_DIR}/docker-compose.yml}"

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

get_images() {
    docker compose -f "$COMPOSE_FILE" images \
        --format '{{.Service}} {{.Repository}}:{{.Tag}} {{.ID}}' \
        2>/dev/null | sort || true
}

cd "$COMPOSE_DIR"

BEFORE=$(get_images)

log "Pulling images..."
docker compose -f "$COMPOSE_FILE" pull >&2

log "Updating containers..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans >&2

AFTER=$(get_images)
CHANGED=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -z "$CHANGED" ]; then
    log "No changes."
    exit 0
fi

docker container prune -f >/dev/null 2>&1
docker image prune -f >/dev/null 2>&1

echo "$CHANGED"
