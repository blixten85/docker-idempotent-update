#!/bin/bash
set -euo pipefail

# Combines results from update and backup steps into one mail.
# Inputs (env vars):
#   EMAIL_TO         — recipient; if empty, function returns silently
#   DOCKER_CHANGES   — diff output from update step (empty if no changes)
#   BACKUP_FAILURES  — newline-separated list of failed app/dir pairs (empty if none)

EMAIL_TO="${EMAIL_TO:-}"
DOCKER_CHANGES="${DOCKER_CHANGES:-}"
BACKUP_FAILURES="${BACKUP_FAILURES:-}"

[ -n "$EMAIL_TO" ] || exit 0
[ -f /etc/msmtprc ] || exit 0

[ -z "$DOCKER_CHANGES" ] && [ -z "$BACKUP_FAILURES" ] && exit 0

HOST=$(hostname)
DATE=$(date '+%Y-%m-%d')
BODY=""

if [ -n "$DOCKER_CHANGES" ]; then
    BODY+="=== Container updates ===\n$DOCKER_CHANGES\n\n"
fi

if [ -n "$BACKUP_FAILURES" ]; then
    BODY+="=== Backup failures ===\n"
    while IFS= read -r F; do
        [ -n "$F" ] && BODY+="  ✗ $F\n"
    done <<< "$BACKUP_FAILURES"
fi

if [ -n "$BACKUP_FAILURES" ] && [ -n "$DOCKER_CHANGES" ]; then
    SUBJECT="🐳 Docker updated + ⚠️ backup failed – $HOST $DATE"
elif [ -n "$BACKUP_FAILURES" ]; then
    SUBJECT="⚠️ Backup failed – $HOST $DATE"
else
    SUBJECT="🐳 Docker updated – $HOST $DATE"
fi

echo -e "Subject: $SUBJECT\n\n$BODY" | msmtp "$EMAIL_TO" 2>/dev/null || true
echo "[$(date '+%H:%M:%S')] 📧 Mail sent: $SUBJECT"
