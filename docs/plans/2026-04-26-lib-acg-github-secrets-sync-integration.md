# lib-acg GitHub Secrets Sync Integration

**Status:** PLANNED — gate: lib-acg first feature PR merged (`feat/phase5-ci-setup`)
**Affects repos:** `lib-acg`, `provision-tomcat`
**Branch (lib-acg):** new branch off `main` after merge
**Branch (provision-tomcat):** `aws-dev`

---

## Problem

Credential sync is split across two repos with no clear ownership:

| Step | Where it lives | What it does |
|---|---|---|
| Extract ACG credentials from browser | `lib-acg` (`acg_get_credentials`) | Playwright scrapes Pluralsight, writes to `~/.aws/credentials` |
| Sync credentials to GitHub Secrets | `ansible/bin/sync-aws-secrets` | Reads `~/.aws/credentials`, calls `gh secret set` for `AWS_*` vars |

`sync-aws-secrets` is a standalone script in `ansible/bin/` — a sibling directory to `provision-tomcat`, not versioned with either repo. provision-tomcat's `sync-aws` Makefile target calls it via `../bin/sync-aws-secrets` (relative path assumption).

Problems:
- lib-acg owns credential extraction but not the downstream sync — the workflow is incomplete
- `sync-aws-secrets` is not tested, not shellcheck'd, has no error handling for partial credential sets
- Any consumer of lib-acg (provision-tomcat, future repos) has to re-implement the GitHub sync step
- The relative path `../bin/sync-aws-secrets` is fragile — breaks if provision-tomcat is cloned elsewhere

---

## Solution

Move the GitHub Secrets sync into lib-acg as `acg_sync_github_secrets` shell function.
lib-acg then owns the full ACG credential lifecycle: **extract → write local → sync remote**.

### lib-acg changes

New file: `scripts/plugins/acg_sync.sh`

```bash
#!/usr/bin/env bash
# scripts/plugins/acg_sync.sh
#
# Sync ACG-extracted credentials to a remote target.
# Supported targets: github-secrets (default)
#
# Usage:
#   acg_sync_github_secrets [--repo <owner/repo>]

function acg_sync_github_secrets() {
  # reads AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN from env
  # or falls back to ~/.aws/credentials default profile
  # pushes to GitHub Secrets via gh CLI
  # --repo flag scopes to a specific repo; defaults to current repo
}
```

The function:
1. Reads credentials from env (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) — env takes precedence over `~/.aws/credentials` so it composes cleanly with `acg_get_credentials`
2. Validates all three vars are non-empty; fails clearly if missing
3. Calls `gh secret set` for each var; handles missing `AWS_SESSION_TOKEN` (deletes stale value)
4. Accepts optional `--repo owner/repo` flag to target a specific GitHub repo

### provision-tomcat changes

`Makefile` `sync-aws` target becomes:

```makefile
sync-aws:
    scripts/k3d-manager acg_sync_github_secrets --repo wilddog64/provision-tomcat
```

Wait — provision-tomcat doesn't use k3d-manager. Instead, source lib-acg directly:

```makefile
sync-aws:
    @source scripts/lib/acg/scripts/plugins/acg_sync.sh && \
    acg_sync_github_secrets --repo wilddog64/provision-tomcat
```

Or add a thin wrapper at `scripts/providers/common/sync-github-secrets.sh` that sources lib-acg.

### ansible/bin/sync-aws-secrets

Delete after provision-tomcat is updated — it's replaced by `acg_sync_github_secrets`.

---

## Scope Boundary

lib-acg owns:
- `acg_get_credentials` — extract from Pluralsight browser
- `acg_sync_github_secrets` — push extracted credentials to GitHub Secrets

lib-acg does NOT own:
- AWS resource discovery (subnet, SG, AMI) — stays in `scripts/providers/aws/discover.sh`
- Azure/GCP credential sync — separate future tasks per provider

---

## Gating Condition

Do NOT start this work until:
1. lib-acg `feat/phase5-ci-setup` PR is merged to `lib-acg/main`
2. The merged lib-acg subtree is pulled into k3d-manager (`git subtree pull`)
3. A new feature branch is created off the updated `lib-acg/main`

Rationale: `acg_sync.sh` must live on a clean branch based on the stable `main` after P5
CI/pre-commit is in place, so the new file is automatically shellcheck'd on commit.

---

## Definition of Done

**lib-acg:**
- [ ] `scripts/plugins/acg_sync.sh` created with `acg_sync_github_secrets` function
- [ ] `shellcheck` + pre-commit pass
- [ ] Function documented in `README.md` public API section
- [ ] Committed and pushed to feature branch; PR opened against `lib-acg/main`

**provision-tomcat:**
- [ ] `Makefile` `sync-aws` target updated to source lib-acg and call `acg_sync_github_secrets`
- [ ] `ansible/bin/sync-aws-secrets` deleted
- [ ] `shellcheck` passes on updated Makefile wrapper
- [ ] `make sync-aws` dry-run validates without error
- [ ] Committed on `aws-dev`; pushed to origin

## What NOT to Do

- Do NOT start before lib-acg P5 is merged
- Do NOT copy `sync-aws-secrets` content verbatim — the function must read from env first, then fall back to `~/.aws/credentials`
- Do NOT add Azure or GCP credential sync to this task — those are separate
- Do NOT create a PR for provision-tomcat until lib-acg PR is merged and subtree is pulled
