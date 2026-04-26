#!/bin/bash
set -euo pipefail

IMAGE="ghcr.io/blixten85/docker-idempotent-update:latest"
MISSING=0

if [ ! -f /config/rclone.conf ]; then
    echo "ERROR: rclone config not found at /config/rclone.conf"
    echo "       Run: docker run -it --rm -v <your-config-dir>:/config $IMAGE rclone --config /config/rclone.conf config"
    echo ""
    MISSING=1
fi

if [ ! -f /config/msmtprc ]; then
    cp /etc/msmtprc.template /config/msmtprc
    echo "INFO: Created /config/msmtprc from template — edit it with your mail server settings"
    echo ""
fi

if [ "$MISSING" -eq 1 ]; then
    echo "Fix the above, then run: docker restart docker-maintenance"
    sleep infinity
fi

ln -sf /config/msmtprc /etc/msmtprc

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
echo "$SCHEDULE /usr/local/bin/run.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "Scheduled: $SCHEDULE"
exec crond -f -l 2
