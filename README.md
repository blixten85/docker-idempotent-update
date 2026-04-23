# 🐳 Docker Idempotent Update

Pull new images and recreate containers, only if changes are detected.

## Setup

1. Edit the script and set your compose file path
2. Make it executable:
   
```bash
chmod +x docker-idempotent-update.sh
```

## Usage

```bash
./docker-idempotent-update.sh
```

Run via cron to auto-update:

```bash
0 3 * * * /path/to/docker-idempotent-update.sh
```

## Requirements

- Docker and docker compose
- msmtp (for email notifications, optional)
