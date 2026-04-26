#!/bin/bash
set -euo pipefail

BASE_SRC="${RCLONE_SRC:-${HOME}/.docker}"
BASE_DST="${RCLONE_DST:-gdrive:backups}"
EMAIL_TO="${EMAIL_TO:-}"
DOCKER_CHANGES="${DOCKER_CHANGES:-}"

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

send_mail() {
    [ -n "$EMAIL_TO" ] || return 0
    echo -e "Subject: $1\n\n$2" | msmtp "$EMAIL_TO" 2>/dev/null || true
}

FAILURES=()

log "=== backup start: $BASE_SRC -> $BASE_DST ==="

for APP_DIR in "$BASE_SRC"/*/; do
    [ -d "$APP_DIR" ] || continue
    APP=$(basename "$APP_DIR" | tr '[:upper:]' '[:lower:]')

    while IFS= read -r DIR; do
        [ -d "$DIR" ] || continue
        NAME=$(basename "$DIR")
        case "${NAME,,}" in backup|backups) ;; *) continue ;; esac

        DEST="$BASE_DST/$APP/$NAME"
        SYNCED=false

        for i in 1 2 3; do
            if rclone sync "$DIR" "$DEST" "${RCLONE_FLAGS[@]}" 2>&1; then
                SYNCED=true
                break
            fi
            log "retry $i: $APP/$NAME"
            sleep 15
        done

        if $SYNCED; then
            log "ok: $APP/$NAME"
        else
            log "FAILED: $APP/$NAME"
            FAILURES+=("$APP/$NAME")
        fi

    done < <(find "$APP_DIR" -maxdepth 2 -type d 2>/dev/null)
done

log "=== backup complete ==="

[ -z "$DOCKER_CHANGES" ] && [ ${#FAILURES[@]} -eq 0 ] && exit 0

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d')
BODY=""

if [ -n "$DOCKER_CHANGES" ]; then
    BODY+="=== Container updates ===\n$DOCKER_CHANGES\n\n"
fi

if [ ${#FAILURES[@]} -gt 0 ]; then
    BODY+="=== Backup failures ===\n"
    for F in "${FAILURES[@]}"; do BODY+="  ✗ $F\n"; done
fi

if [ ${#FAILURES[@]} -gt 0 ] && [ -n "$DOCKER_CHANGES" ]; then
    SUBJECT="🐳 Docker updated + ⚠️ backup failed – $HOST $DATE"
elif [ ${#FAILURES[@]} -gt 0 ]; then
    SUBJECT="⚠️ Backup failed – $HOST $DATE"
else
    SUBJECT="🐳 Docker updated – $HOST $DATE"
fi

send_mail "$SUBJECT" "$BODY"
log "📧 Mail sent: $SUBJECT"
