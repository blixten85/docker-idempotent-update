# 🐳 docker-idempotent-update

![Build](https://github.com/blixten85/docker-idempotent-update/actions/workflows/build.yml/badge.svg)
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/blixten85/docker-idempotent-update?utm_source=oss&utm_medium=github&utm_campaign=blixten85%2Fdocker-idempotent-update&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

Daily Docker host maintenance in a single container:

1. **Pulls** new images and recreates any containers that changed
2. **Backs up** app data to Google Drive via rclone
3. **Emails** a summary — only when something actually happened

Designed to run unattended via a systemd timer.

---

## How it works

`run.sh` is the entrypoint. It runs the two operations in sequence and passes results to the mail step:

```
run.sh
  ├── docker compose pull + up   (detects changes via image diff)
  └── rclone_backup.sh           (syncs backup dirs, sends one mail)
        ├── 🐳 container updates — always included if any
        └── ⚠️  backup failures  — included if any, silent on success
```

Mail is only sent when containers were updated or a backup failed. If nothing changed, no mail is sent.

---

## Setup

### 1. Configure environment

Create `/home/$USER/.config/docker-maintenance.env`:

```env
EMAIL_TO=you@example.com
RCLONE_DST=gdrive:backups
```

### 2. Configure rclone

Set up a Google Drive remote named `gdrive`:

```bash
rclone config
```

### 3. Backup folder structure

The backup script scans `~/.docker/` and syncs any folder named `backup` or `backups` up to two levels deep:

```
~/.docker/
  prowlarr/
    backups/      →  gdrive:backups/prowlarr/backups/
  sonarr/
    config/
      backup/     →  gdrive:backups/sonarr/backup/
```

### 4. Install systemd timer

```bash
sudo cp systemd/docker-maintenance.service /etc/systemd/system/
sudo cp systemd/docker-maintenance.timer   /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now docker-maintenance.timer
```

> Edit the `ExecStart` path in `docker-maintenance.service` to match where you cloned this repo.

Run once manually to verify:

```bash
sudo systemctl start docker-maintenance.service
journalctl -u docker-maintenance.service -f
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `EMAIL_TO` | *(unset — no mail)* | Mail recipient |
| `COMPOSE_DIR` | `~/.config/docker` | Directory containing docker-compose.yml |
| `COMPOSE_FILE` | `$COMPOSE_DIR/docker-compose.yml` | Full path to compose file |
| `RCLONE_SRC` | `~/.docker` | Root directory to scan for backup folders |
| `RCLONE_DST` | `gdrive:backups` | rclone remote destination |

---

## Running manually

```bash
docker compose run --rm maintenance
```
