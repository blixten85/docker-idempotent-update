# docker-idempotent-update — AI Agent Guide

Daily Docker host maintenance in a single container. Pulls updated images, recreates changed containers, syncs backups via rclone, and sends an email summary only when something happened.

## Tech Stack

- Python 3.13
- Docker (socket or Compose)
- rclone for backups
- msmtp for email
- Internal cron daemon

## File Overview

```
src/entrypoint.py   # Validates config, registers cron, execs crond
src/run.py          # Main daily job (update + backup + report + status)
src/docker_update.py# Docker pull + restart logic
src/backup.py       # Rclone sync logic
src/report.py       # Assembles and sends email summary
src/config.py       # Config class — reads env vars and backup.conf
backup.conf.template
msmtprc.template
```

## Conventions

- All secrets via environment variables — never hardcoded
- No third-party Python packages — stdlib only
- Test changes with `docker compose run --rm` before committing

## Allowed
- Create branches
- Modify code
- Run tests
- Open PRs

## Forbidden
- Push directly to main/master
- Merge PRs
- Delete branches
- Disable workflows
- Modify secrets
- Change GitHub org settings

## Requirements
- All tests must pass
- Keep PRs focused
- Never include unrelated changes
- Never commit credentials
- Never force push
