# 🐳 Docker Idempotent Update
![CodeRabbit Pull Request Reviews](https://img.shields.io/coderabbit/prs/github/blixten85/docker-idempotent-update?utm_source=oss&utm_medium=github&utm_campaign=blixten85%2Fdocker-idempotent-update&labelColor=171717&color=FF570A&link=https%3A%2F%2Fcoderabbit.ai&label=CodeRabbit+Reviews)

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
