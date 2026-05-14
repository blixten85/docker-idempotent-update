# docker-idempotent-update — Claude Code Guide

Daily Docker host maintenance in a single container. Pulls updated images, recreates changed containers, syncs backups via rclone, and sends an email summary only when something happened.

## Tech Stack

- POSIX shell / Bash
- Docker (socket or Compose)
- rclone for backups
- msmtp for email
- Internal cron daemon

## File Overview

```
entrypoint.sh       # Validates config, starts crond
run.sh              # Main daily job (update + backup + report)
rclone_backup.sh    # Rclone sync logic
send_report.sh      # Assembles and sends email summary
backup.conf.template
msmtprc.template
```

## Conventions

- All shell scripts must begin with `set -euo pipefail`
- POSIX-compatible where possible; bash only when necessary
- All secrets via environment variables — never hardcoded
- No external dependencies beyond what ships in the Docker image
- Test changes with `docker compose run --rm` before committing
