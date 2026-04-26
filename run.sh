#!/bin/bash
set -euo pipefail

EMAIL_TO="${EMAIL_TO:-}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

send_mail() {
    [ -n "$EMAIL_TO" ] || return 0
    echo -e "Subject: $1\n\n$2" | msmtp "$EMAIL_TO" 2>/dev/null || true
}

RCLONE_STATUS=0
DOCKER_CHANGES=""
DOCKER_STATUS=0

log "=== rclone backup ==="
rclone_backup.sh || RCLONE_STATUS=$?

log "=== docker update ==="
DOCKER_CHANGES=$(docker-idempotent-update.sh) || DOCKER_STATUS=$?
[ -n "$DOCKER_CHANGES" ] && echo "$DOCKER_CHANGES"

[ $RCLONE_STATUS -eq 0 ] && [ -z "$DOCKER_CHANGES" ] && [ $DOCKER_STATUS -eq 0 ] && {
    log "=== Nothing to report, done ==="
    exit 0
}

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M')
BODY=""

[ -n "$DOCKER_CHANGES" ] && BODY+="=== Docker changes ===\n$DOCKER_CHANGES\n\n"
[ $DOCKER_STATUS -ne 0 ]  && BODY+="❌ Docker update failed (exit $DOCKER_STATUS)\n\n"
[ $RCLONE_STATUS -ne 0 ]  && BODY+="❌ rclone backup failed (exit $RCLONE_STATUS)\n\n"

if [ $RCLONE_STATUS -ne 0 ] || [ $DOCKER_STATUS -ne 0 ]; then
    SUBJECT="❌ Maintenance failed – $HOST $DATE"
else
    SUBJECT="🐳 Docker updated – $HOST $DATE"
fi

send_mail "$SUBJECT" "$BODY"
log "📧 Mail sent: $SUBJECT"
log "=== Done ==="
