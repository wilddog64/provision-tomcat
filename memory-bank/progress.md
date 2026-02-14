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

## In Progress
- [ ] Merge `aws-dev` into `main`.
- [ ] Re-enable automatic CI triggers for AWS integration tests.

## Future / Pending
- [ ] Expand `systemPatterns.md` if k3s/ArgoCD scope is added.
- [ ] Document Shopping Cart microservice API contracts if integration expands.
