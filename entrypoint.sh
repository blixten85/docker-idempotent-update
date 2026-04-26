#!/bin/bash
set -euo pipefail

if [ ! -f /config/rclone.conf ]; then
    echo "ERROR: rclone config not found at /config/rclone.conf"
    echo "       Run: docker exec -it docker-maintenance rclone config"
    echo "       Then: docker restart docker-maintenance"
    echo ""
    sleep infinity
fi

if [ ! -f /config/msmtprc ]; then
    cp /etc/msmtprc.template /config/msmtprc
    echo "INFO: Created /config/msmtprc from template — edit it with your mail server settings"
    echo ""
fi

if [ ! -f /config/backup.conf ]; then
    cp /etc/backup.conf.template /config/backup.conf
    echo "INFO: Created /config/backup.conf from template — edit it to configure backup settings"
    echo ""
fi

ln -sf /config/msmtprc /etc/msmtprc

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
echo "$SCHEDULE /usr/local/bin/run.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "Scheduled: $SCHEDULE"
exec crond -f -l 2
