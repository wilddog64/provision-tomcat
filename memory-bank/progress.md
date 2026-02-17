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
- [ ] Override WinRM readiness command with `cmd /c exit 0` in `.kitchen.yml`.
- [ ] Validate `kitchen converge default-win11` locally.
- [ ] Validate `make test-win11` (full end-to-end) locally.
- [ ] Pin Ruby 3.3.x in CI to eliminate dependency spiral.

### Phase 4: CI/CD Modernization (P2)
- [ ] Implement linear 2-job pipeline logic (`lint` -> `integration`).
- [ ] Update `ci.yml` to use Setup Action and pin Ruby 3.3.x.
- [ ] Gate Azure job with `if: false` and TODO for TAP-auth stability.
- [ ] Use `always()` post-steps for cleanup.

### Phase 5: Verification & Cleanup
- [ ] Run `make check` locally.
- [ ] Push single clean commit to `azure-dev`.
- [ ] Verify green CI on `azure-dev`.
- [ ] Delete stale/messed branches (`merge-main-into-azure-dev`).

### Deferred / Future
- [ ] Revisit Azure TAP auth when ACG model stabilizes.
- [ ] Port raw `az` CLI provisioning to `Makefile`.
- [ ] Implement timestamped VDI names in `Vagrantfile`.
