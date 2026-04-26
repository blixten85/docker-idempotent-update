#!/bin/bash
set -euo pipefail

IMAGE="ghcr.io/blixten85/docker-idempotent-update:latest"
MISSING=0

check() {
    local file="$1" label="$2" hint="$3"
    if [ ! -f "$file" ]; then
        echo "ERROR: $label not found at $file"
        echo "       $hint"
        echo ""
        MISSING=1
    fi
}

check /config/rclone.conf "rclone config" \
    "Run: docker run -it --rm -v <your-config-dir>:/config $IMAGE rclone --config /config/rclone.conf config"

if [ -n "${EMAIL_TO:-}" ]; then
    check /config/msmtprc "msmtp config" \
        "Create <your-config-dir>/msmtprc — see https://marlam.de/msmtp/msmtprc.html for syntax"
fi

if [ "$MISSING" -eq 1 ]; then
    echo "Fix the above, then run: docker restart docker-maintenance"
    sleep infinity
fi

ln -sf /config/msmtprc /etc/msmtprc 2>/dev/null || true

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
echo "$SCHEDULE /usr/local/bin/run.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "Scheduled: $SCHEDULE"
exec crond -f -l 2
