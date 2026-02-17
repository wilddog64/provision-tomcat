# Plan: Azure-Dev Branch Recovery (2026-02-17)

## Background & Post-Mortem

The `azure-dev` branch accumulated ~25+ commits that created a cascading failure:

### Root Causes
1. **Shotgun debugging of WinRM "true" error** — 7+ individual commits tried different fixes (`install_command`, `shell_type`, gem pins) without reverting failed attempts. Each left residue.
2. **Ruby 4.0 compatibility spiral** — Self-hosted runner's Ruby 4.0 triggered a chain reaction: `thor` pin -> `benchmark` gem -> `kitchen-azure` upgrade/removal -> `setup-ruby` attempts.
3. **AWS logic pollution** — `merge-main-into-azure-dev` branch introduced AWS-specific CI logic into an Azure-focused branch, creating redundant job overlaps.
4. **Azure ACG platform shift** — Mid-development move from Service Principal to TAP-only auth invalidated the CI authentication approach entirely.

### Key Lesson
**Debug locally, commit once, push verified.** Trial-and-error debugging through CI commits is what destroyed the branch.

---

## Recovery Strategy: Prioritized Phases

### P0: Fix WinRM "true" Error (Highest Value Unblock)

**Root Cause**: `kitchen-ansiblepush` sends POSIX `true` as a readiness check to a PowerShell target. This is a shell mismatch, NOT a transport issue.

**Steps**:
1. Revert ALL debugging leftovers from the stale branch to a clean baseline:
   - `.kitchen.yml:20`: Remove `install_command: ''`
   - `.kitchen.yml:31`: Remove `ansible_winrm_shell_type: cmd`
   - `Gemfile:5`: Unpin `test-kitchen` (remove `~> 3.1.0`)
   - `requirements.txt:1`: Unpin `pywinrm` (remove `==0.4.1`)
2. Override the readiness command in `.kitchen.yml` with `cmd /c exit 0`.
3. Validate locally:
   - `bundle install && pip install -r requirements.txt`
   - `bundle exec kitchen converge default-win11`
   - `make test-win11` (full end-to-end)
4. Only proceed to P1 after local validation passes.

**Note**: Since we reset from `main`, the debugging leftovers from the stale branch are NOT present. Step 1 is a safeguard — verify the clean state, then apply only the targeted `cmd /c exit 0` fix.

### P1: Pin Ruby 3.3.x in CI

**Problem**: Ruby 4.0 on the self-hosted runner causes cascading gem compatibility issues.

**Steps**:
1. Add `ruby/setup-ruby@v1` with `ruby-version: '3.3'` to CI jobs, OR
2. Configure `rbenv` in CI setup to use Ruby 3.3.x.
3. Verify `bundle install` succeeds with locked Ruby version.

**Decision Point**: If `ruby/setup-ruby` has permission issues on the M2 runner (as previously noted), fall back to rbenv. Test locally first.

### P2: Clean Vagrant-Only CI Pipeline

**Architecture**: 2-job linear pipeline (not 3):

```
lint -> integration (Vagrant-only)
```

**Job: `lint`**
- ansible-lint, yamllint, ansible-playbook --syntax-check
- Ruby 3.3.x pinned

**Job: `integration`**
- Vagrant Test Kitchen: `kitchen test default-win11`
- Cleanup via `always()` post-step (not a separate job)
- Triggered on push to `azure-dev`, PRs to `main`
- Fork protection guard

**Azure**: Gated with `if: false` and `# TODO: Re-enable when ACG TAP model stabilizes`

### P3: Verification & Push

1. Run `make check` locally — must pass.
2. Commit all changes as a **single clean commit**.
3. Push to `azure-dev`.
4. Verify CI green.

### P4: Branch Cleanup

| Branch | Action | Reason |
|--------|--------|--------|
| `merge-main-into-azure-dev` | Delete | Caused AWS logic pollution |
| `copilot/sub-pr-13-again` | Verify stale, then delete | Likely orphaned |
| `azure-dev-stale` | Keep until rebuild verified, then delete | Reference backup |
| `vagrant-dev` | Assess for portable knowledge, then delete | Consolidate into azure-dev |

### Deferred (Not in Scope)

| Item | Reason |
|------|--------|
| Azure TAP auth in CI | ACG credential model unstable; revisit when stabilized |
| Raw `az` CLI in Makefile | Depends on Azure auth resolution |
| Timestamped VDI names | Nice-to-have, not blocking |
| Merge PR #20/PR #25 | Separate workflow |

---

## Success Criteria

- [ ] `make test-win11` passes locally (WinRM "true" error resolved)
- [ ] CI pipeline runs green on `azure-dev` push
- [ ] No debugging residue in committed code
- [ ] Stale branches cleaned up
- [ ] Memory bank reflects current state accurately
