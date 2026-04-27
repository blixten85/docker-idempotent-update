# docker-idempotent-update

![Build](https://github.com/blixten85/docker-idempotent-update/actions/workflows/build.yml/badge.svg)

Daily Docker host maintenance in a single container:

1. **Pulls** new images and recreates any containers that changed
2. **Backs up** app data to a rclone remote
3. **Emails** a summary — only when something actually happened

Runs on a schedule via an internal cron daemon. No systemd, no host dependencies beyond Docker itself.

---

## How it works

```
entrypoint.sh  (validates config, starts crond)
└── run.sh     (runs daily at 03:00 by default)
      ├── docker compose pull + up   (or socket-only — see Options)
      └── rclone_backup.sh
            ├── syncs backup dirs to rclone remote
            └── sends one combined mail if anything changed or failed
```

Mail is only sent when containers were updated or a backup failed.

---

## Setup

### 1. Add the service to your docker-compose.yml

Copy the contents of [`docker-compose.yml`](docker-compose.yml) into your own compose file.  
Required variables in your `.env`:

```env
DOCKER=/path/to/your/docker/data    # e.g. /home/user/.docker
CONFIG=/path/to/your/compose/dir    # e.g. /home/user/.config/docker (Option B only)
EMAIL_TO=you@example.com
```

### 2. Start the container

```bash
docker compose up -d maintenance
```

On first start the container will:
- Create `$DOCKER/docker-maintenance/config/msmtprc` from template
- Create `$DOCKER/docker-maintenance/config/backup.conf` from template
- Wait for rclone config (see step 3)

### 3. Configure rclone

```bash
docker exec -it docker-maintenance rclone config
docker restart docker-maintenance
```

The config is written to `$DOCKER/docker-maintenance/config/rclone.conf`.

### 4. Edit config files

All config lives in `$DOCKER/docker-maintenance/config/`:

| File | Purpose |
|---|---|
| `rclone.conf` | rclone remote configuration (created via `rclone config`) |
| `msmtprc` | Mail server settings (created from template) |
| `backup.conf` | Backup source, destination and folder names (created from template) |

After editing, apply changes with:

```bash
docker restart docker-maintenance
```

---

## Options

### Option A — Docker socket (no compose file needed)

The default. Pulls images for all running containers and restarts any that were updated.  
No additional volume mount required.

### Option B — Compose file (recommended)

Runs `docker compose pull` + `up -d --remove-orphans`. Requires mounting your compose directory.  
Uncomment `COMPOSE_FILE` and the `${CONFIG}:/compose:ro` volume in your compose file.

---

## Backup folder structure

`backup.conf` controls which directory is scanned and which folder names are synced.  
Default: scans `$DOCKER` for folders named `backup` or `backups` (case-insensitive) up to two levels deep.

```
$DOCKER/
  prowlarr/
    backups/      →  gdrive:backups/prowlarr/backups/
  sonarr/
    config/
      backup/     →  gdrive:backups/sonarr/backup/
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `EMAIL_TO` | *(required)* | Mail recipient |
| `CRON_SCHEDULE` | `0 3 * * *` | When to run |
| `RCLONE_CONFIG` | `/config/rclone.conf` | rclone config path inside container |
| `COMPOSE_FILE` | *(unset)* | Full path to compose file inside container (Option B) |
