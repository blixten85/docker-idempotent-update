#!/bin/bash
set -euo pipefail

# Backs up directories matching $BACKUP_DIRS under $BASE_SRC to $BASE_DST.
# Writes the names of failed backups (one per line) to $BACKUP_FAILURES_FILE
# if set. Mail reporting is handled by send_report.sh.

# shellcheck source=/dev/null
[ -f /config/backup.conf ] && source /config/backup.conf

BASE_SRC="${RCLONE_SRC:-/data}"
BASE_DST="${RCLONE_DST:-gdrive:backups}"
BACKUP_DIRS="${BACKUP_DIRS:-backup backups}"
DRY_RUN="${DRY_RUN:-false}"
FAILURES_FILE="${BACKUP_FAILURES_FILE:-}"

RCLONE_FLAGS=(
  --fast-list
  --transfers 4
  --checkers 6
  --tpslimit 5
  --retries 5
  --low-level-retries 10
  --timeout 15m
  --contimeout 30s
  --stats-one-line
  --checksum
  --delete-during
)

log() { echo "[$(date '+%H:%M:%S')] $*"; }

FAILURES=()

log "=== backup start: $BASE_SRC -> $BASE_DST ==="

for APP_DIR in "$BASE_SRC"/*/; do
    [ -d "$APP_DIR" ] || continue
    APP=$(basename "$APP_DIR" | tr '[:upper:]' '[:lower:]')

    while IFS= read -r DIR; do
        [ -d "$DIR" ] || continue
        NAME=$(basename "$DIR")
        NAME_LOWER="${NAME,,}"
        MATCH=false
        for BDIR in $BACKUP_DIRS; do
            [ "${BDIR,,}" = "$NAME_LOWER" ] && MATCH=true && break
        done
        $MATCH || continue

        DEST="$BASE_DST/$APP/$NAME"
        SYNCED=false

        if [ "$DRY_RUN" = "true" ]; then
            log "[dry-run] would sync: $DIR -> $DEST"
            SYNCED=true
        else
            for i in 1 2 3; do
                if rclone sync "$DIR" "$DEST" "${RCLONE_FLAGS[@]}" 2>&1; then
                    SYNCED=true
                    break
                fi
                log "retry $i: $APP/$NAME"
                sleep 15
            done
        fi

        if $SYNCED; then
            log "ok: $APP/$NAME"
        else
            log "FAILED: $APP/$NAME"
            FAILURES+=("$APP/$NAME")
        fi

    done < <(find "$APP_DIR" -maxdepth 2 -type d 2>/dev/null)
done

log "=== backup complete ==="

if [ -n "$FAILURES_FILE" ] && [ ${#FAILURES[@]} -gt 0 ]; then
    printf '%s\n' "${FAILURES[@]}" > "$FAILURES_FILE"
fi
