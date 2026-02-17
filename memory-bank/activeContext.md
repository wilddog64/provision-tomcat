# Active Context

## Current Session Objective: Clean-Room Azure & Vagrant Stabilization
We are rebuilding the `azure-dev` branch from the stable `main` foundation to resolve persistent Azure authentication issues (TAP shift) and Vagrant transport blockers (WinRM "true" error).

## The Strategy: Clean-Room Rebuild (2026-02-17)
Following a "messed up" merge attempt that introduced AWS logic pollution and redundant job overlaps, we have:
1.  Renamed the unstable `azure-dev` to `azure-dev-stale`.
2.  Reset `azure-dev` to a fresh state based on the security-hardened `main` branch.
3.  Porting only verified intent and diagnostics into this clean foundation.

## Current Technical Hurdle: Azure TAP-only Auth
- **Issue**: ACG no longer provides SP credentials. CI must use the runner's local session or a short-lived Temporary Access Pass (TAP).
- **Remediation**: Implementing a management API probe (`az account get-access-token`) in CI to detect TAP expiry and fail-fast before VM creation.

## Current Technical Hurdle: WinRM 'true' Error
- **Issue**: `kitchen-ansiblepush` sends POSIX `true` to Windows guests, causing PowerShell crashes.
- **Remediation**: Overriding the readiness command in `.kitchen.yml` with `cmd /c exit 0`.

## CI Pipeline Refactor
- **Objective**: Consolidate to a linear 3-job pipeline (`lint` -> `integration` -> `cleanup`).
- **Logic**: A single integration job that attempts Azure and falls back to Vagrant on failure, eliminating parallel resource contention.

## Recent Activity
- **Phase 1 Complete**: Backed up knowledge and reset `azure-dev` branch from `main`.
- **Phase 2 In Progress**: Restored diagnostics and documented rebuild strategy in `docs/plans/2026-02-17-azure-rebuild-strategy.md`.
