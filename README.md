# 🐳 Docker Idempotent Update

![Build](https://github.com/blixten85/docker-idempotent-update/actions/workflows/build.yml/badge.svg)
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/blixten85/docker-idempotent-update?utm_source=oss&utm_medium=github&utm_campaign=blixten85%2Fdocker-idempotent-update&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

Pull new images and recreate containers — only if changes are detected. Sends an email notification when containers are updated.

## Docker Compose

```bash
# Run update
docker compose run --rm update

# Run rclone backup
docker compose run --rm rclone-backup
```

Configure via environment variables or a `.env` file:

```env
EMAIL_TO=you@example.com
COMPOSE_DIR=~/.config/docker
LOG_DIR=~/.log
RCLONE_DST=gdrive:backups
RCLONE_SRC_DIR=~/.docker
RCLONE_LOG_DIR=~/.rclone/logs
```

Run via cron:

```bash
0 3 * * * cd /path/to/docker-idempotent-update && docker compose run --rm update
```

## Docker

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/.config/docker:/config:ro \
  -v ~/.log:/logs \
  -e COMPOSE_DIR=/config \
  -e LOG_FILE=/logs/docker-idempotent.log \
  -e EMAIL_TO=you@example.com \
  ghcr.io/blixten85/docker-idempotent-update
```

## Script

```bash
chmod +x docker-idempotent-update.sh
./docker-idempotent-update.sh
```

## Environment variables

### docker-idempotent-update.sh

| Variable | Default | Description |
|---|---|---|
| `COMPOSE_DIR` | `~/.config/docker` | Directory containing docker-compose.yml |
| `COMPOSE_FILE` | `$COMPOSE_DIR/docker-compose.yml` | Full path to compose file |
| `LOG_FILE` | `~/.log/docker-idempotent.log` | Log file path |
| `LOCK_FILE` | `~/.log/docker-idempotent.lock` | Lock file path |
| `EMAIL_TO` | *(unset — no mail)* | Recipient for change notifications |

### rclone_backup.sh

Syncs `backup/` and `backups/` subdirectories to a cloud destination via rclone.

| Variable | Default | Description |
|---|---|---|
| `RCLONE_SRC` | `~/.docker` | Source directory to scan |
| `RCLONE_DST` | `gdrive:backups` | rclone remote destination |
| `RCLONE_LOGDIR` | `~/.rclone/logs` | Log directory |
