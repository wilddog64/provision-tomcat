# Progress Tracker

## Clean-Room Rebuild (2026-02-17)

### Phase 1: Knowledge Preservation & Branch Reset
- [x] Backup memory bank and diagnostics.
- [x] Rename stale `azure-dev` to `azure-dev-stale`.
- [x] Reset `azure-dev` from `main` (4c27520).

### Phase 2: Knowledge Integration & Planning
- [x] Restore diagnostic data and memory bank.
- [x] Document rebuild strategy (`docs/plans/2026-02-17-azure-rebuild-strategy.md`).
- [x] Update `memory-bank/activeContext.md`.
- [ ] Commit initial rebuild state.

### Phase 3: CI/CD Modernization
- [ ] Update `ci.yml` to use Setup Action.
- [ ] Implement linear 3-job pipeline logic.
- [ ] Implement Azure TAP-aware detection.

### Phase 4: Technical Fix Implementation
- [ ] Port raw `az` CLI provisioning to `Makefile`.
- [ ] Apply WinRM "true" fix to `.kitchen.yml`.
- [ ] Implement timestamped VDI names in `Vagrantfile`.

### Phase 5: Verification & Delivery
- [ ] Verify locally via `make check`.
- [ ] Push to `azure-dev` and verify via CI.
