# Task State

## Current Recovery Operation: Clean-Room Rebuild
Focus: Stabilizing `azure-dev` branch via local-first validation and technical fix application.

### Phase 3: Technical Fix Stabilization [IN PROGRESS]
- **WinRM "true" Fix**: Applied to `.kitchen.yml` (`ready_command`).
- **Ruby Pinning**: Applied to `.github/actions/setup/action.yml` and `ci.yml`.
- **Local Validation**: `make check` passed. `kitchen converge` in progress (downloading box).

### Phase 4: CI/CD Modernization [IN PROGRESS]
- **Linearized Pipeline**: 2-job flow implemented in `ci.yml`.
- **Azure Targets**: Ported raw `az` CLI targets to `Makefile`.
- **Stability**: Timestamped VDI names implemented in `Vagrantfile`.

### Pending
- [ ] Final verification of `kitchen converge`.
- [ ] Single clean commit and push.
- [ ] Branch cleanup.

## Blocker Tracking
- [x] WinRM "true" error (Fix implemented, pending verification).
- [x] Ruby 4.0 dependency spiral (Fix implemented via pinning).
- [ ] Azure TAP model (Deferred to local stabilization first).
- [ ] **upgrade-baseline-win11 — 404 + drive mismatch** (see docs/issues/2026-02-17-upgrade-baseline-404-and-drive-mismatch.md):
    - Fix 1: update 9.0.113 → 9.0.115 in `tests/playbook-upgrade.yml` line 88
    - Fix 2: resolve `install_drive: "C:"` playbook default vs D: role default
    - Prerequisite: confirm `windows11-tomcat112` box drive before fixing drive issue
