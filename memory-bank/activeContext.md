# Active Context

## Current Session Objective: Clean-Room Azure-Dev Recovery
We are executing a prioritized recovery of the `azure-dev` branch, resetting it to a stable foundation based on `main` (4c27520) and applying targeted, locally-validated fixes to resolve the WinRM "true" error and CI environment instability.

## The Strategy: Clean-Room Rebuild & Recovery (2026-02-17)
Following a post-mortem of the "messed up" merge attempt, we have adopted a "Vagrant-First" stabilization approach:
1.  **Branch Reset**: `azure-dev` is now a clean branch from `main`. The unstable history is preserved in `azure-dev-stale`.
2.  **Ruby Stabilization**: Pinning CI to Ruby 3.3.x to eliminate the Ruby 4.0 dependency spiral found on the self-hosted runner.
3.  **Vagrant-Only CI**: Establishing a linear 2-job pipeline (`lint` -> `integration`). Azure tests are "parked" with `if: false` until the ACG TAP-shift model is stabilized locally.
4.  **Local Validation Protocol**: All technical fixes (WinRM "true" override, VDI naming) must be verified locally before a single clean commit is pushed.

## Operational Protocols (Anti-Regressive)
To prevent falling back into "shotgun debugging," the following protocols are active:
- **Local-First Mandate**: No "push-to-test" on GitHub. Every change must pass `kitchen converge` or `make check` locally first.
- **Single-Commit Delivery**: Technical fixes are committed as atomic units once verified, keeping the branch history clean and auditable.
- **Defensive Configuration**: Using `ENV.fetch` in `.kitchen.yml` to prevent crashes when cloud secrets are missing during local development.
- **Linearized Pipeline**: Building a simple `lint` -> `integration` flow using the `setup` composite action from `main`.

## Current Technical Hurdle: WinRM 'true' Error
- **Issue**: `kitchen-ansiblepush` sends POSIX `true` to Windows guests as a readiness check, causing PowerShell crashes.
- **Remediation**: Overriding the readiness command in `.kitchen.yml` with `cmd /c exit 0`.

## Current Technical Hurdle: Ruby 4.0 Dependency Spiral
- **Issue**: The M2 runner's default Ruby 4.0.0 triggers cascading gem compatibility issues.
- **Remediation**: Pinning CI jobs to Ruby 3.3.x via `rbenv` or the setup-ruby action.

## Active Blocker: upgrade-baseline-win11 Failures (2026-02-17)

Two bugs in `tests/playbook-upgrade.yml` cause `make test-upgrade-baseline-win11` to fail:

1. **404 on Tomcat download**: Line 88 targets `9.0.113` (removed from Apache CDN).
   Must be updated to `9.0.115`. See `docs/issues/2026-02-17-upgrade-baseline-404-and-drive-mismatch.md`.

2. **C: drive instead of D:**: Playbook `vars` section hardcodes `install_drive: "C:"`
   (lines 11-15), overriding `defaults/main.yml`'s `install_drive: "D:"`. The
   `upgrade-baseline` suite in `.kitchen.yml` never passes `install_drive: "D:"` as
   extra_var, so the whole run uses C:.

**Pending before fixing drive issue**: Confirm whether `windows11-tomcat112` baseline box
was built with C: or D: drive. If C:, the box needs rebuilding before switching to D:.

## Recent Activity
- **Phase 1 & 2 Complete**: Branch reset, knowledge preservation, and strategic planning (including Claude's post-mortem) are finalized and committed.
- **Operational Protocols established**: Formalized "Local-First" and "Defensive Configuration" mandates.
- **upgrade-baseline bugs identified**: 404 (stale version) + C:/D: drive mismatch documented in `docs/issues/`.
