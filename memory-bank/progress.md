# Progress Tracker

## Azure-Dev Recovery (2026-02-17)

### Phase 1: Branch Reset & Context Preservation
- [x] Backup memory bank and diagnostics.
- [x] Rename stale `azure-dev` to `azure-dev-stale`.
- [x] Reset `azure-dev` from stable `main` (4c27520).

### Phase 2: Post-Mortem & Strategic Planning
- [x] Analyze root causes (Shotgun debugging, Ruby 4.0 spiral, AWS logic pollution).
- [x] Create recovery strategy (`docs/plans/2026-02-17-azure-dev-recovery.md`).
- [x] Update `memory-bank/` (activeContext, progress, key_knowledge, task_state).
- [x] Finalize rebuild plan for automated CI and local validation.

### Phase 3: Technical Fix Stabilization (P0-P1)
- [x] Override WinRM readiness command with `cmd /c exit 0` in `.kitchen.yml`.
- [x] Pin Ruby to 3.3.8 in `.github/actions/setup/action.yml`.
- [x] Validate `kitchen converge default-win11-baseline` locally. (PASSED)
- [x] Validate WinRM connectivity via `kitchen exec`. (PASSED)

### Phase 4: CI/CD Modernization (P2)
- [x] Implement linear 2-job pipeline logic (`lint` -> `integration`) in `ci.yml`.
- [x] Port raw `az` CLI provisioning targets to `Makefile`.
- [x] Implement defensive configuration (`ENV.fetch`) in `.kitchen.yml`.
- [x] Implement timestamped VDI names in `Vagrantfile`.
- [x] Harden Test Kitchen verifier hostname extraction.

### Phase 5: Verification & Cleanup
- [x] Run `make check` locally. (PASSED)
- [ ] Push single clean commit to `azure-dev`.
- [ ] Verify green CI on `azure-dev`.
- [ ] Delete stale/messed branches (`merge-main-into-azure-dev`).

### Deferred / Future
- [ ] Revisit Azure TAP auth when ACG model stabilizes.
