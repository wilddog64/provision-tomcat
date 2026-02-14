# Progress Tracker

## Completed
- [x] Initialized memory bank structure under `memory-bank/`.
- [x] Created `projectbrief.md` with repository purpose, scope, and operational outcomes.
- [x] Created `systemPatterns.md` documenting installation, upgrade, candidate, verification, and security patterns.
- [x] Created `techContext.md` documenting stack, runtime variables, test channels, and constraints.
- [x] Created `activeContext.md` with current state, decision rationale ("why"), and handoff notes.

## Pending TODOs
- [x] AWS Sandbox Stabilization:
    - [x] Refine `ec2` driver and WinRM transport in `.kitchen.yml`.
    - [x] Update `aws_integration` job in `ci.yml` to use self-hosted runner and venv.
    - [x] Implement `test-aws-provision-tomcat` and `test-aws-upgrade-candidate` in `Makefile`.
    - [x] Verify dynamic session detection (`aws sts get-caller-identity`) in CI.
    - [x] Implement Dynamic Secret Sync via `make sync-secrets` and `.envrc`.
    - [x] Implement Conditional Vagrant Fallback.
- [ ] Expand `systemPatterns.md` with concrete k3s/ArgoCD implementation details if/when this repository adds those assets.
- [ ] Add explicit shopping-cart integration/API contract notes if this role becomes coupled to e-commerce service rollout workflows.
- [ ] Keep `activeContext.md` and this file synchronized after every future code/infrastructure/test update.

## Next Suggested Operator Checks
- [ ] Optional: run `make check` to verify lint/syntax health after broader repo changes.
- [ ] Optional: run targeted Kitchen suite for current change scope before release.- [x] Documented AWS-specific integration hurdles and resolutions in `docs/issues/2026-02-14-aws-integration-hurdles.md`.
- [x] Standardized collection installation in CI using explicit Galaxy commands.
- [x] Implemented dynamic hostname injection for Ansible via `ANSIBLE_HOST_OVERRIDE`.
