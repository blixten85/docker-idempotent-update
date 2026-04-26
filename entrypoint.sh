#!/bin/bash
set -euo pipefail

[ -f /config/msmtprc ] && ln -sf /config/msmtprc /etc/msmtprc

SCHEDULE="${CRON_SCHEDULE:-0 3 * * *}"
echo "$SCHEDULE /usr/local/bin/run.sh >> /proc/1/fd/1 2>&1" | crontab -

exec crond -f -l 2
