#!/bin/bash
set -euo pipefail

COMPOSE_FILE="/home/berduf/.config/docker/docker-compose.yml"
LOG_FILE="/home/berduf/.log/docker-idempotent.log"

EMAIL_TO="root@denied.se"

cd "$(dirname "$COMPOSE_FILE")"

send_mail() {
    SUBJECT="$1"
    BODY="$2"
    echo -e "Subject: $SUBJECT\n\n$BODY" | msmtp "$EMAIL_TO" || true
}

echo "=========================================" | tee -a "$LOG_FILE"
echo "[$(date)] Docker update start" | tee -a "$LOG_FILE"

# -----------------------------
# 1. Snapshot BEFORE (image per service)
# -----------------------------
BEFORE=$(docker compose -f "$COMPOSE_FILE" images 2>/dev/null | awk 'NR>1 {print $2,$3,$4}' | sort || true)

# -----------------------------
# 2. Pull
# -----------------------------
echo "Pulling images..." | tee -a "$LOG_FILE"
docker compose -f "$COMPOSE_FILE" pull | tee -a "$LOG_FILE"

# -----------------------------
# 3. Up
# -----------------------------
echo "Updating containers..." | tee -a "$LOG_FILE"
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans | tee -a "$LOG_FILE"

# -----------------------------
# 4. Snapshot AFTER
# -----------------------------
AFTER=$(docker compose -f "$COMPOSE_FILE" images 2>/dev/null | awk 'NR>1 {print $2,$3,$4}' | sort || true)

# -----------------------------
# 5. Detect changes
# -----------------------------
DIFF=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -z "$DIFF" ]; then
    echo "No changes detected → exit" | tee -a "$LOG_FILE"
    exit 0
fi

# -----------------------------
# 6. Cleanup
# -----------------------------
docker container prune -f >/dev/null
docker image prune -f >/dev/null

# -----------------------------
# 7. Mail only if change
# -----------------------------
MSG="Docker update completed on $(hostname) at $(date)

Changes detected:
$DIFF"

echo "$MSG" | tee -a "$LOG_FILE"
send_mail "🐳 Docker update: changes applied" "$MSG"

echo "=========================================" | tee -a "$LOG_FILE"
