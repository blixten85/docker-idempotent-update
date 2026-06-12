import json
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
    if result.returncode != 0:
        raise RuntimeError(f"docker ps failed: {result.stderr.strip()}")
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
            if _recreate_container(cid, image, name):
                log.info("Recreated: %s", name)
                updated.append(name)
            else:
                log.warning("Failed to recreate: %s", name)

    return updated


def _recreate_container(cid: str, image: str, name: str) -> bool:
    result = subprocess.run(["docker", "inspect", cid], capture_output=True, text=True)
    if result.returncode != 0:
        return False
    try:
        info = json.loads(result.stdout)[0]
    except (ValueError, IndexError):
        return False

    hc = info.get("HostConfig") or {}
    container_cfg = info.get("Config") or {}

    cmd = ["docker", "run", "--detach", "--name", name]

    rp = hc.get("RestartPolicy") or {}
    rp_name = rp.get("Name") or "no"
    if rp_name and rp_name != "no":
        retries = rp.get("MaximumRetryCount") or 0
        if rp_name == "on-failure" and retries:
            cmd += ["--restart", f"on-failure:{retries}"]
        else:
            cmd += ["--restart", rp_name]

    nm = hc.get("NetworkMode") or ""
    if nm and nm not in ("default", "bridge"):
        cmd += ["--network", nm]

    for env_var in container_cfg.get("Env") or []:
        cmd += ["-e", env_var]

    for bind in hc.get("Binds") or []:
        cmd += ["-v", bind]

    for cport, bindings in (hc.get("PortBindings") or {}).items():
        for b in bindings or []:
            hip = b.get("HostIp", "")
            hport = b.get("HostPort", "")
            cmd += ["-p", (f"{hip}:{hport}:{cport}" if hip else f"{hport}:{cport}")]

    for k, v in (container_cfg.get("Labels") or {}).items():
        cmd += ["-l", f"{k}={v}"]

    cmd.append(image)

    subprocess.run(["docker", "stop", cid], capture_output=True)
    subprocess.run(["docker", "rm", cid], capture_output=True)
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        log.error("Failed to recreate %s: %s", name, r.stderr.strip())
        return False
    return True


def _diff(before: list[str], after: list[str]) -> str:
    before_set = set(before)
    after_set = set(after)
    lines = [f"< {line}" for line in sorted(before_set - after_set)] + [
        f"> {line}" for line in sorted(after_set - before_set)
    ]
    return "\n".join(lines)
