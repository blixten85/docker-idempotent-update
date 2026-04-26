#!/bin/bash
set -euo pipefail

BASE_SRC="${RCLONE_SRC:-${HOME}/.docker}"
BASE_DST="${RCLONE_DST:-gdrive:backups}"

RCLONE_FLAGS=(
  --fast-list
  --transfers 4
  --checkers 6
  --tpslimit 5
  --retries 5
  --low-level-retries 10
  --timeout 15m
  --contimeout 30s
  --stats 10s
  --stats-one-line
  --checksum
  --delete-during
)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

FAILED=0

log "=== backup start: $BASE_SRC -> $BASE_DST ==="

for APP_DIR in "$BASE_SRC"/*/; do
    [ -d "$APP_DIR" ] || continue
    APP=$(basename "$APP_DIR" | tr '[:upper:]' '[:lower:]')

    while IFS= read -r DIR; do
        [ -d "$DIR" ] || continue
        NAME=$(basename "$DIR")
        case "${NAME,,}" in backup|backups) ;; *) continue ;; esac

        REL="${DIR#$APP_DIR}"
        DEST="$BASE_DST/$APP/$NAME"

        log "sync: $APP/$NAME"

        SYNCED=false
        for i in 1 2 3; do
            if rclone sync "$DIR" "$DEST" "${RCLONE_FLAGS[@]}" 2>&1; then
                SYNCED=true
                break
            fi
            log "retry $i failed: $APP/$NAME"
            sleep 15
        done

        if $SYNCED; then
            log "ok: $APP/$NAME"
        else
            log "FAILED: $APP/$NAME"
            FAILED=1
        fi

    done < <(find "$APP_DIR" -maxdepth 2 -type d 2>/dev/null)
done

log "=== backup complete ==="

exit $FAILED
