#!/bin/bash
set -euo pipefail

log() { echo "[$(date '+%H:%M:%S')] $*"; }

MODE="${MODE:-both}"
DRY_RUN="${DRY_RUN:-false}"
STATUS_FILE="/config/status.json"

NEEDS_UPDATE=false
NEEDS_BACKUP=false
if [ "$MODE" = "update" ] || [ "$MODE" = "both" ]; then NEEDS_UPDATE=true; fi
if [ "$MODE" = "backup" ] || [ "$MODE" = "both" ]; then NEEDS_BACKUP=true; fi

[ "$DRY_RUN" = "true" ] && log "=== DRY RUN MODE — no changes will be made ==="
log "=== mode: $MODE ==="

UPDATED_CONTAINERS=()
DOCKER_CHANGES=""

if $NEEDS_UPDATE; then
    log "=== docker update ==="
    BEFORE=$(docker ps --format '{{.Names}} {{.Image}} {{.ImageID}}' 2>/dev/null | sort || true)

    if [ -n "${COMPOSE_FILE:-}" ]; then
        cd "$(dirname "$COMPOSE_FILE")"

        ENV_FILE_ARG=""
        if [ -n "${COMPOSE_ENV_FILE:-}" ] && [ -f "$COMPOSE_ENV_FILE" ]; then
            ENV_FILE_ARG="--env-file $COMPOSE_ENV_FILE"
            log "Using env file: $COMPOSE_ENV_FILE"
        fi

        if [ "$DRY_RUN" = "true" ]; then
            log "[dry-run] would run: docker compose -f $COMPOSE_FILE $ENV_FILE_ARG pull (sequential) && up -d --remove-orphans"
        else
            # Pull one service at a time to avoid burst rate limits (e.g. lscr.io).
            # shellcheck disable=SC2086
            docker compose -f "$COMPOSE_FILE" $ENV_FILE_ARG config --services | while IFS= read -r svc; do
                pulled=false
                for attempt in 1 2 3; do
                    # shellcheck disable=SC2086
                    if docker compose -f "$COMPOSE_FILE" $ENV_FILE_ARG pull "$svc"; then
                        pulled=true
                        break
                    fi
                    [ "$attempt" -lt 3 ] && sleep $((attempt * 5))
                done
                $pulled || log "WARN: failed to pull $svc after 3 attempts"
            done
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
    DOCKER_CHANGES=$(diff <(echo "$BEFORE") <(echo "$AFTER") || true)

    if [ -n "$DOCKER_CHANGES" ] && [ "$DRY_RUN" != "true" ]; then
        log "Changes detected, pruning..."
        docker container prune -f >/dev/null 2>&1
        docker image prune -f >/dev/null 2>&1
    fi
fi

BACKUP_FAILURES=""
if $NEEDS_BACKUP; then
    log "=== rclone backup ==="
    FAILURES_TMP=$(mktemp)
    trap 'rm -f "$FAILURES_TMP"' EXIT
    BACKUP_FAILURES_FILE="$FAILURES_TMP" rclone_backup.sh
    [ -s "$FAILURES_TMP" ] && BACKUP_FAILURES=$(cat "$FAILURES_TMP")
fi

log "=== send report ==="
DOCKER_CHANGES="$DOCKER_CHANGES" BACKUP_FAILURES="$BACKUP_FAILURES" send_report.sh

log "=== writing status ==="
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
CONTAINERS_JSON=$(printf '%s\n' "${UPDATED_CONTAINERS[@]+"${UPDATED_CONTAINERS[@]}"}" | jq -Rsc 'split("\n") | map(select(. != ""))')
FAILURES_JSON=$(printf '%s\n' "${BACKUP_FAILURES}" | jq -Rsc 'split("\n") | map(select(. != ""))')
jq -n \
    --arg ts "$TIMESTAMP" \
    --arg mode "$MODE" \
    --argjson dry "$([ "$DRY_RUN" = "true" ] && echo true || echo false)" \
    --argjson containers "$CONTAINERS_JSON" \
    --argjson failures "$FAILURES_JSON" \
    --arg changes "$DOCKER_CHANGES" \
    '{timestamp:$ts, mode:$mode, dry_run:$dry, containers_updated:$containers, backup_failures:$failures, docker_changes:$changes}' \
    > "$STATUS_FILE"
log "Status written to $STATUS_FILE"
