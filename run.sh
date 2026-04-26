#!/bin/bash
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "=== docker update ==="

BEFORE=$(docker ps --format '{{.Names}} {{.Image}} {{.ImageID}}' 2>/dev/null | sort || true)

if [ -n "${COMPOSE_FILE:-}" ]; then
    cd "$(dirname "$COMPOSE_FILE")"
    docker compose -f "$COMPOSE_FILE" pull
    docker compose -f "$COMPOSE_FILE" up -d --remove-orphans
else
    docker ps --format '{{.Image}}' | sort -u | xargs -r -I{} docker pull {}
    docker ps --format '{{.ID}} {{.Image}}' | while read -r CID IMAGE; do
        RUNNING=$(docker inspect --format='{{.Image}}' "$CID")
        LATEST=$(docker inspect --format='{{.Id}}' "$IMAGE" 2>/dev/null || echo "")
        if [ -n "$LATEST" ] && [ "$RUNNING" != "$LATEST" ]; then
            NAME=$(docker inspect --format='{{.Name}}' "$CID" | tr -d '/')
            docker restart "$CID" >/dev/null
            log "Restarted: $NAME"
        fi
    done
fi

AFTER=$(docker ps --format '{{.Names}} {{.Image}} {{.ImageID}}' 2>/dev/null | sort || true)

export DOCKER_CHANGES
DOCKER_CHANGES=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -n "$DOCKER_CHANGES" ]; then
    log "Changes detected, pruning..."
    docker container prune -f >/dev/null 2>&1
    docker image prune -f >/dev/null 2>&1
fi

log "=== rclone backup ==="
rclone_backup.sh
