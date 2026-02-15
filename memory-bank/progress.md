# Progress Tracker

## Completed
- [x] Initialized memory bank structure under `memory-bank/`.
- [x] Created documentation suite (`projectbrief.md`, `systemPatterns.md`, `techContext.md`, `activeContext.md`).
- [x] Stabilized AWS integration pipeline:
    - [x] Resolved AZ compatibility issue by switching to `t2.medium` for legacy `us-east-1e`.
    - [x] Programmatically authorize SG ingress in CI for `5985` and `8080`.
    - [x] Hardened CI with `aws-actions/configure-aws-credentials@v4`.
    - [x] Fixed verifier to use dynamic hostname from Kitchen state.
    - [x] Verified full end-to-end Tomcat provisioning on `aws-dev`.
- [x] Standardized collection installation in CI using explicit Galaxy commands.
- [x] Implemented dynamic hostname injection for Ansible via `ANSIBLE_HOST_OVERRIDE`.
- [x] Fixed `Makefile` and `ci.yml` regressions:
    - [x] Restored `community.windows` to `deps`.
    - [x] Implemented offline linting.
    - [x] Added role resolution symlinking to `syntax` target.
    - [x] Modernized `ansible.cfg` callback and connection settings.
- [x] Implemented AWS D: drive support (disk initialization + redirected test targets).
- [x] Synchronized AWS sandbox credentials to GitHub (refreshed session).
- [x] Renamed CI validation job to `lint` for branch protection compliance.
- [x] Defended architectural choices in PR #6 review with Codex.
- [x] Implemented CI path filtering to exclude `docs/` and `memory-bank/` from triggering workflows.
- [x] Created `docs/issues/2026-02-14-aws-integration-hurdles.md` documenting resolved AWS issues.
- [x] Created `docs/issues/2026-02-14-aws-infrastructure-drift.md` detailing Hybrid Zero-Touch Sync strategy.
- [x] Created `docs/plans/2026-02-14-controlled-ci-execution.md` for CI optimization.
- [x] Implement Hybrid Zero-Touch Sync for AWS resource ID discovery (see `docs/issues/2026-02-14-aws-infrastructure-drift.md`).
- [x] Implement Draft PR conditional CI execution (see `docs/plans/2026-02-14-controlled-ci-execution.md`).
- [x] Fix CI stdout pollution in `Makefile` to support `eval` in workflows.
- [x] Fix hardcoded absolute path in `.kitchen.yml` for environment portability.
- [x] Initial role scaffold for Windows Tomcat installation.
- [x] Side-by-side candidate upgrade pattern.
- [x] Test Kitchen orchestration for Vagrant and AWS.
- [x] **[SECURITY] Security Hardening Roadmap (Phase 1)**
  - [x] Add checksum verification to Tomcat download (HIGH-1).
  - [x] Restrict AWS SG ingress to runner IP + add revoke in cleanup (HIGH-2 + LOW-1).
  - [x] Add fork protection to ci.yml (HIGH-3).
  - [x] Address feedback: include manual triggers in guards and reuse runner IP.
- [x] **[SECURITY] Security Hardening Roadmap (Phase 2)**
  - [x] Add `no_log: true` to password-handling tasks (HIGH-5).
  - [x] Bind shutdown port to localhost (MED-4).
  - [x] Add security warning against `LocalSystem` default (MED-5).
  - [x] Note: WinRM HTTPS (HIGH-4) deferred due to AMI connectivity issues.
  - [x] Code Review: Confirmed all objectives met by `@copilot`.
- [x] **[SECURITY] Security Hardening Roadmap (Phase 3)**
  - [x] Replace `eval` with safer parsing in CI (MED-6).
  - [x] Externalize hardcoded test passwords to variables (MED-2).
  - [x] Avoid private SSL API usage in lookup plugins (LOW-2).
  - [x] Remove stale AWS resource ID fallbacks from Makefile (LOW-3).

## In Progress
- [ ] Merge PR #16 (Phase 3 security hardening) to `aws-dev`.
- [ ] Finalize merge of `aws-dev` to `main`.

## Future / Pending
- [ ] Expand `systemPatterns.md` if k3s/ArgoCD scope is added.
- [ ] Document Shopping Cart microservice API contracts if integration expands.
- [ ] **[SECURITY]** Remediate Phase 2 & 3 roadmap items:
  - [ ] Enable WinRM HTTPS for AWS platforms (HIGH-4)
  - [ ] Add `no_log: true` to password-handling tasks (HIGH-5)
  - [ ] Restrict CredSSP delegation from wildcard (MED-1)
  - [ ] Replace hardcoded test passwords (MED-2)
  - [ ] Audit GH_PAT scope / migrate to deploy key (MED-3)
  - [ ] Bind shutdown port to localhost (MED-4)
  - [ ] Change default service account from LocalSystem (MED-5)
  - [ ] Replace eval with safer parsing in CI (MED-6)
