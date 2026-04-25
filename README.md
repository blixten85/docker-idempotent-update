# 🐳 Docker Idempotent Update

[![Codacy Badge](https://api.codacy.com/project/badge/Grade/01bdbd3378de43bd8e1d2e355979a796)](https://app.codacy.com/gh/blixten85/docker-idempotent-update?utm_source=github.com&utm_medium=referral&utm_content=blixten85/docker-idempotent-update&utm_campaign=Badge_Grade)

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
