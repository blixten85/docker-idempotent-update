#!/bin/bash
set -euo pipefail

MODE="${MODE:-both}"
case "$MODE" in
    update|backup|both) ;;
    *)
        echo "ERROR: invalid MODE='$MODE' — must be one of: update, backup, both"
        exit 1
        ;;
esac

NEEDS_UPDATE=false
NEEDS_BACKUP=false
if [ "$MODE" = "update" ] || [ "$MODE" = "both" ]; then NEEDS_UPDATE=true; fi
if [ "$MODE" = "backup" ] || [ "$MODE" = "both" ]; then NEEDS_BACKUP=true; fi

if $NEEDS_UPDATE && [ ! -S /var/run/docker.sock ]; then
    echo "ERROR: docker socket not found at /var/run/docker.sock"
    echo "       MODE='$MODE' requires the host docker socket mounted into the container."
    sleep infinity
fi

if $NEEDS_BACKUP && [ ! -f /config/rclone.conf ]; then
    echo "ERROR: rclone config not found at /config/rclone.conf"
    echo "       Run: docker exec -it docker-maintenance rclone config"
    echo "       Then: docker restart docker-maintenance"
    echo ""
    sleep infinity
fi

if $NEEDS_BACKUP && [ ! -f /config/backup.conf ]; then
    cp /etc/backup.conf.template /config/backup.conf
    echo "INFO: Created /config/backup.conf from template — edit it to configure backup settings"
    echo ""
fi

if [ -n "${EMAIL_TO:-}" ] && [ ! -f /config/msmtprc ]; then
    cp /etc/msmtprc.template /config/msmtprc
    echo "INFO: Created /config/msmtprc from template — edit it with your mail server settings"
    echo ""
fi

[ -f /config/msmtprc ] && ln -sf /config/msmtprc /etc/msmtprc

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
echo "$SCHEDULE /usr/local/bin/run.sh >> /proc/1/fd/1 2>&1" | crontab -

echo "Mode: $MODE"
echo "Scheduled: $SCHEDULE"
exec crond -f -l 2
