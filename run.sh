#!/bin/bash
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

DRY_RUN="${DRY_RUN:-false}"
STATUS_FILE="/config/status.json"

[ "$DRY_RUN" = "true" ] && log "=== DRY RUN MODE — no changes will be made ==="

log "=== docker update ==="

UPDATED_CONTAINERS=()
BEFORE=$(docker ps --format '{{.Names}} {{.Image}} {{.ImageID}}' 2>/dev/null | sort || true)

if [ -n "${COMPOSE_FILE:-}" ]; then
    cd "$(dirname "$COMPOSE_FILE")"

    ENV_FILE_ARG=""
    if [ -n "${COMPOSE_ENV_FILE:-}" ] && [ -f "$COMPOSE_ENV_FILE" ]; then
        ENV_FILE_ARG="--env-file $COMPOSE_ENV_FILE"
        log "Using env file: $COMPOSE_ENV_FILE"
    fi

    if [ "$DRY_RUN" = "true" ]; then
        log "[dry-run] would run: docker compose -f $COMPOSE_FILE $ENV_FILE_ARG pull && up -d --remove-orphans"
    else
        # shellcheck disable=SC2086
        docker compose -f "$COMPOSE_FILE" $ENV_FILE_ARG pull
        # shellcheck disable=SC2086
        docker compose -f "$COMPOSE_FILE" $ENV_FILE_ARG up -d --remove-orphans
    fi
else
    if [ "$DRY_RUN" = "true" ]; then
        log "[dry-run] would pull images: $(docker ps --format '{{.Image}}' | sort -u | tr '\n' ' ')"
    else
        docker ps --format '{{.Image}}' | sort -u | xargs -r -I{} docker pull {}
        docker ps --format '{{.ID}} {{.Image}}' | while read -r CID IMAGE; do
            RUNNING=$(docker inspect --format='{{.Image}}' "$CID")
            LATEST=$(docker inspect --format='{{.Id}}' "$IMAGE" 2>/dev/null || echo "")
            if [ -n "$LATEST" ] && [ "$RUNNING" != "$LATEST" ]; then
                NAME=$(docker inspect --format='{{.Name}}' "$CID" | tr -d '/')
                docker restart "$CID" >/dev/null
                log "Restarted: $NAME"
                UPDATED_CONTAINERS+=("$NAME")
            fi
        done
    fi
fi

AFTER=$(docker ps --format '{{.Names}} {{.Image}} {{.ImageID}}' 2>/dev/null | sort || true)

export DOCKER_CHANGES
DOCKER_CHANGES=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -n "$DOCKER_CHANGES" ] && [ "$DRY_RUN" != "true" ]; then
    log "Changes detected, pruning..."
    docker container prune -f >/dev/null 2>&1
    docker image prune -f >/dev/null 2>&1
fi

log "=== rclone backup ==="
rclone_backup.sh

log "=== writing status ==="
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
CONTAINERS_JSON=$(printf '%s\n' "${UPDATED_CONTAINERS[@]+"${UPDATED_CONTAINERS[@]}"}" | jq -R . | jq -sc .)
cat > "$STATUS_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "dry_run": $DRY_RUN,
  "containers_updated": $CONTAINERS_JSON,
  "docker_changes": $(echo "$DOCKER_CHANGES" | jq -Rs .)
}
EOF
log "Status written to $STATUS_FILE"
