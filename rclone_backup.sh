#!/bin/bash
set -euo pipefail

BASE_SRC="/home/berduf/.docker"
BASE_DST="gdrive:backups"

LOGDIR="$HOME/.rclone/logs"
LOGFILE="$LOGDIR/backup_$(date +%Y%m%d_%H%M%S).log"
LOCKFILE="$LOGDIR/rclone_backup.lock"

mkdir -p "$LOGDIR"

log() {
  echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# -------------------------
# SAFE LOCK
# -------------------------
if [ -f "$LOCKFILE" ] && kill -0 "$(cat "$LOCKFILE")" 2>/dev/null; then
  log "Backup already running — exit"
  exit 1
fi

echo $$ > "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# -------------------------
# RCLONE FLAGS
# -------------------------
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

log "=== STRICT BACKUP START ==="

# -------------------------
# LOOP APPS (DEPTH 1 ONLY)
# -------------------------
for APP_DIR in "$BASE_SRC"/*; do
  [ -d "$APP_DIR" ] || continue

  APP=$(basename "$APP_DIR")
  APP_CLEAN=$(echo "$APP" | tr '[:upper:]' '[:lower:]')

  log "SCAN: $APP_CLEAN"

  # -------------------------
  # ONLY EXACT BACKUP FOLDERS (DEPTH MAX 2)
  # -------------------------
  while IFS= read -r DIR; do

    [ -d "$DIR" ] || continue

    REL="${DIR#$APP_DIR/}"

    # enforce max depth 2
    DEPTH=$(echo "$REL" | awk -F/ '{print NF}')
    if [ "$DEPTH" -gt 2 ]; then
      continue
    fi

    NAME=$(basename "$DIR")

    # STRICT MATCH ONLY
    case "${NAME,,}" in
      backup|backups)
        ;;
      *)
        continue
        ;;
    esac

    log "SYNC: $APP_CLEAN -> $REL"

    if ! ls -A "$DIR" >/dev/null 2>&1; then
      log "SKIP (empty): $DIR"
      continue
    fi

    DEST="$BASE_DST/$APP_CLEAN/$REL"

    for i in 1 2 3; do
      rclone sync "$DIR" "$DEST" \
        "${RCLONE_FLAGS[@]}" \
        >> "$LOGFILE" 2>&1 && break

      log "Retry $i failed: $APP_CLEAN/$REL"
      sleep 15
    done

    log "OK: $APP_CLEAN/$REL"

  done < <(find "$APP_DIR" -maxdepth 2 -type d 2>/dev/null)

done

log "=== STRICT BACKUP COMPLETE ==="
