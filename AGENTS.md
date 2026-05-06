# AI Agent Coordination

This repository is maintained with help from three AI agents:

- **Claude Code** (Anthropic) — scheduled weekly reviews, CI/CD, infra, Dependabot/security fixes
- **Codex** (OpenAI) — interactive feature work and bug fixes invoked by the maintainer
- **Copilot** (GitHub) — interactive feature work and bug fixes invoked by the maintainer

## Branch Naming

| Agent | Prefix | Example |
|---|---|---|
| Claude | `claude/` | `claude/fix-backup-logic` |
| Codex | `codex/` | `codex/add-slack-notification` |
| Copilot | `copilot/` | `copilot/add-slack-notification` |

All three prefixes auto-merge via the `auto-merge.yml` workflow once CI passes.

## Ownership Map

| Area | Primary owner | Notes |
|---|---|---|
| `.github/workflows/` | Claude | CI/CD, auto-merge, release-please |
| `.github/dependabot.yml` | Claude | Dependency update schedule |
| `entrypoint.sh`, `run.sh` | Codex | Core execution logic |
| `send_report.sh` | Codex | Mail/report logic |
| `Dockerfile` | Claude | Container build |
| `docker-compose.yml` | Claude | Infrastructure |
| `SECURITY.md`, `AGENTS.md` | Claude | Maintenance docs |
| `README.md` | Shared | Either may update |

## Conflict Protocol

Before opening a PR:

1. Run `gh pr list --repo API-Apoteket/docker-idempotent-update --state open` and check for open PRs touching the same files.
2. If another agent has an open PR on a file you need to modify, wait for it to merge and then rebase.
3. Never force-push to a branch you did not create.
4. Never close or edit another agent's PR.

## PR Labels

- Claude PRs: `ai:claude`
- Codex PRs: `ai:codex`
- Copilot PRs: `ai:copilot`

## Standards

- Shell scripts: POSIX-compatible where possible, bash where needed
- All secrets via environment variables — never hardcoded
- `set -euo pipefail` at the top of every shell script
