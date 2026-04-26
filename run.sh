#!/bin/bash
set -euo pipefail

COMPOSE_DIR="${COMPOSE_DIR:-${HOME}/.config/docker}"
COMPOSE_FILE="${COMPOSE_FILE:-${COMPOSE_DIR}/docker-compose.yml}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

get_images() {
    docker compose -f "$COMPOSE_FILE" images \
        --format '{{.Service}} {{.Repository}}:{{.Tag}} {{.ID}}' \
        2>/dev/null | sort || true
}

cd "$COMPOSE_DIR"

log "=== docker update ==="
BEFORE=$(get_images)
docker compose -f "$COMPOSE_FILE" pull
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans
AFTER=$(get_images)

export DOCKER_CHANGES
DOCKER_CHANGES=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -n "$DOCKER_CHANGES" ]; then
    log "Changes detected, pruning..."
    docker container prune -f >/dev/null 2>&1
    docker image prune -f >/dev/null 2>&1
fi

log "=== rclone backup ==="
rclone_backup.sh
