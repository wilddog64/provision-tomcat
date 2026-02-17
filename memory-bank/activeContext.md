# Active Context

## Current Session Objective: Clean-Room Azure-Dev Recovery
We are executing a prioritized recovery of the `azure-dev` branch, resetting it to a stable foundation based on `main` (4c27520) and applying targeted, locally-validated fixes to resolve the WinRM "true" error and CI environment instability.

## The Strategy: Clean-Room Rebuild & Recovery (2026-02-17)
Following a post-mortem of the "messed up" merge attempt, we have adopted a "Vagrant-First" stabilization approach:
1.  **Branch Reset**: `azure-dev` is now a clean branch from `main`. The unstable history is preserved in `azure-dev-stale`.
2.  **Ruby Stabilization**: Pinning CI to Ruby 3.3.x to eliminate the Ruby 4.0 dependency spiral found on the self-hosted runner.
3.  **Vagrant-Only CI**: Establishing a linear 2-job pipeline (`lint` -> `integration`). Azure tests are "parked" with `if: false` until the ACG TAP-shift model is stabilized locally.
4.  **Local Validation Protocol**: All technical fixes (WinRM "true" override, VDI naming) must be verified locally before a single clean commit is pushed.

## Current Technical Hurdle: WinRM 'true' Error
- **Issue**: `kitchen-ansiblepush` sends POSIX `true` to Windows guests as a readiness check, causing PowerShell crashes.
- **Remediation**: Overriding the readiness command in `.kitchen.yml` with `cmd /c exit 0`.

## Current Technical Hurdle: Ruby 4.0 Dependency Spiral
- **Issue**: The M2 runner's default Ruby 4.0.0 triggers cascading gem compatibility issues.
- **Remediation**: Pinning CI jobs to Ruby 3.3.x via `rbenv` or the setup-ruby action.

## Recent Activity
- **Phase 1 Complete**: Backed up knowledge and reset `azure-dev` branch from `main`.
- **Phase 2 Complete**: Integrated Claude's post-mortem analysis and finalized the recovery plan in `docs/plans/2026-02-17-azure-dev-recovery.md`.
- **Phase 2 Complete**: Updated memory bank with the refined "Vagrant-First" strategy.
