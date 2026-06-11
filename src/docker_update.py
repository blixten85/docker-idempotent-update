import logging
import subprocess
import time
from pathlib import Path

from .config import Config

log = logging.getLogger(__name__)


def run_update(cfg: Config) -> tuple[str, list[str]]:
    before = _ps_snapshot()

    updated_containers: list[str] = []
    if cfg.compose_file:
        updated_containers = _compose_update(cfg)
    else:
        updated_containers = _socket_update(cfg)

    after = _ps_snapshot()
    changes = _diff(before, after)

    if changes and not cfg.dry_run:
        log.info("Changes detected, pruning...")
        subprocess.run(["docker", "container", "prune", "-f"], capture_output=True)
        subprocess.run(["docker", "image", "prune", "-f"], capture_output=True)

    return changes, updated_containers


def _ps_snapshot() -> list[str]:
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.Names}} {{.Image}} {{.ImageID}}"],
        capture_output=True,
        text=True,
    )
    return sorted(result.stdout.splitlines())


def _compose_update(cfg: Config) -> list[str]:
    compose_dir = str(Path(cfg.compose_file).parent)
    base_cmd = ["docker", "compose", "-f", cfg.compose_file]
    if cfg.compose_env_file and Path(cfg.compose_env_file).exists():
        base_cmd += ["--env-file", cfg.compose_env_file]
        log.info("Using env file: %s", cfg.compose_env_file)

    if cfg.dry_run:
        log.info(
            "[dry-run] would run: docker compose pull (sequential) && up -d --remove-orphans"
        )
        return []

    result = subprocess.run(
        base_cmd + ["config", "--services"],
        capture_output=True,
        text=True,
        check=True,
        cwd=compose_dir,
    )
    services = result.stdout.splitlines()

    before_images = _compose_image_snapshot(base_cmd, compose_dir)

    for svc in services:
        for attempt in range(1, 4):
            try:
                subprocess.run(base_cmd + ["pull", svc], check=True, cwd=compose_dir)
                break
            except subprocess.CalledProcessError:
                if attempt < 3:
                    time.sleep(attempt * 5)
                else:
                    log.warning("Failed to pull %s after 3 attempts", svc)

    subprocess.run(
        base_cmd + ["up", "-d", "--remove-orphans"], check=True, cwd=compose_dir
    )

    after_images = _compose_image_snapshot(base_cmd, compose_dir)
    return [svc for svc in services if after_images.get(svc) != before_images.get(svc)]


def _compose_image_snapshot(base_cmd: list[str], compose_dir: str) -> dict[str, str]:
    result = subprocess.run(
        base_cmd + ["images", "--format", "{{.Service}}\t{{.ID}}"],
        capture_output=True,
        text=True,
        cwd=compose_dir,
    )
    snapshot: dict[str, str] = {}
    for line in result.stdout.splitlines():
        parts = line.split("\t", 1)
        if len(parts) == 2:
            snapshot[parts[0].strip()] = parts[1].strip()
    return snapshot


def _socket_update(cfg: Config) -> list[str]:
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.Image}}"],
        capture_output=True,
        text=True,
        check=True,
    )
    images = sorted(set(result.stdout.splitlines()))

    if cfg.dry_run:
        log.info("[dry-run] would pull images: %s", " ".join(images))
        return []

    for image in images:
        r = subprocess.run(["docker", "pull", image], capture_output=True)
        if r.returncode != 0:
            log.warning("Failed to pull image: %s", image)

    updated: list[str] = []
    result = subprocess.run(
        ["docker", "ps", "--format", "{{.ID}} {{.Image}}"],
        capture_output=True,
        text=True,
        check=True,
    )
    for line in result.stdout.splitlines():
        cid, image = line.split(None, 1)
        running = subprocess.run(
            ["docker", "inspect", "--format={{.Image}}", cid],
            capture_output=True,
            text=True,
        ).stdout.strip()
        latest = subprocess.run(
            ["docker", "inspect", "--format={{.Id}}", image],
            capture_output=True,
            text=True,
        ).stdout.strip()
        if latest and running != latest:
            name = (
                subprocess.run(
                    ["docker", "inspect", "--format={{.Name}}", cid],
                    capture_output=True,
                    text=True,
                )
                .stdout.strip()
                .lstrip("/")
            )
            subprocess.run(["docker", "restart", cid], capture_output=True)
            log.info("Restarted: %s", name)
            updated.append(name)

    return updated


def _diff(before: list[str], after: list[str]) -> str:
    before_set = set(before)
    after_set = set(after)
    lines = [f"< {line}" for line in sorted(before_set - after_set)] + [
        f"> {line}" for line in sorted(after_set - before_set)
    ]
    return "\n".join(lines)
