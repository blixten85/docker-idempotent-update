import logging
import os
import subprocess
import sys
from pathlib import Path
from shutil import copy2

logging.basicConfig(
    format="[%(asctime)s] %(message)s",
    datefmt="%H:%M:%S",
    level=logging.INFO,
    stream=sys.stdout,
)
log = logging.getLogger(__name__)

_VALID_MODES = ("update", "backup", "both")


def main() -> None:
    mode = os.environ.get("MODE", "both")
    if mode not in _VALID_MODES:
        log.error("Invalid MODE=%r — must be one of: update, backup, both", mode)
        sys.exit(1)

    needs_update = mode in ("update", "both")
    needs_backup = mode in ("backup", "both")

    if needs_update and not Path("/var/run/docker.sock").is_socket():
        log.error("docker socket not found at /var/run/docker.sock")
        log.error(
            "MODE=%r requires the host docker socket mounted into the container.", mode
        )
        sys.exit(1)

    if needs_backup and not Path("/config/rclone.conf").exists():
        log.error("rclone config not found at /config/rclone.conf")
        log.error("Run: docker exec -it docker-maintenance rclone config")
        log.error("Then: docker restart docker-maintenance")
        log.error("")
        sys.exit(1)

    if needs_backup and not Path("/config/backup.conf").exists():
        copy2("/etc/backup.conf.template", "/config/backup.conf")
        log.info(
            "Created /config/backup.conf from template"
            " — edit it to configure backup settings"
        )

    email_to = os.environ.get("EMAIL_TO", "")
    if email_to and not Path("/config/msmtprc").exists():
        copy2("/etc/msmtprc.template", "/config/msmtprc")
        log.info(
            "Created /config/msmtprc from template"
            " — edit it with your mail server settings"
        )

    msmtprc = Path("/config/msmtprc")
    if msmtprc.exists():
        etc_msmtprc = Path("/etc/msmtprc")
        if not etc_msmtprc.exists(follow_symlinks=False):
            etc_msmtprc.symlink_to(msmtprc)

    schedule = os.environ.get("CRON_SCHEDULE", "0 3 * * *")
    cron_line = f"{schedule} cd /app && python3 -m src.run >> /proc/1/fd/1 2>&1\n"
    subprocess.run(["crontab", "-"], input=cron_line, text=True, check=True)

    log.info("Mode: %s", mode)
    log.info("Scheduled: %s", schedule)

    os.execvp("crond", ["crond", "-f", "-l", "2"])


if __name__ == "__main__":
    main()
