# AWS Sandbox Stabilization Plan

## Objective
Achieve parity with the Azure integration testing pipeline by stabilizing the AWS Test Kitchen drivers, implementing dynamic session-based authentication in CI, and refining the associated `Makefile` targets.

## Background
The Azure integration pipeline was successfully stabilized by:
1.  Leveraging active CLI sessions on self-hosted runners (`az account show`).
2.  Implementing persistent role management via local symlinks.
3.  Resolving macOS-specific `fork()` safety crashes with `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`.
4.  Using isolated Python virtual environments for Ansible execution.
5.  Refining CI triggers to prevent cross-environment test noise.

AWS tests currently rely on brittle Kitchen configurations and lack the same level of CI integration.

## Technical Plan

### 1. Infrastructure Stabilization (`.kitchen.yml`)
- **Transport Tuning**: [x] Retain `:negotiate` for WinRM transport on AWS (`:basic` was attempted but failed; see `docs/issues/2026-02-14-aws-integration-hurdles.md#1`).
- **Resource Optimization**: Evaluate `instance_type` (currently `t3.micro`/`t3.medium`). Standardize on a size that balances cost and Windows boot/provision speed.
- **Security Group Management**: Parameterize `security_group_ids` and `subnet_id` via environment variables (similar to Azure resource groups) to support rotating sandboxes. See `docs/issues/2026-02-14-aws-infrastructure-drift.md` for the Hybrid Zero-Touch Sync strategy.

### 2. CI/CD Integration (`.github/workflows/ci.yml`)
- **Runner Assignment**: Update the `aws_integration` job to run on the `[self-hosted, macOS, ARM64]` runner.
- **Portability Fixes**:
    - [x] **Authentication**: Use `aws-actions/configure-aws-credentials` with `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`.
    - [x] **Role Management**: Replaced local symlinks with `actions/checkout` using `ssh-key` (via `DEPLOY_KEY` secrets).
- **Dynamic Secret Synchronization**: 
    - [x] Implement `make sync-secrets` to push local environment variables (from `.envrc`) to GitHub Secrets.
    - [x] Support rotating sandboxes by dynamically updating credentials via the `gh` CLI.
    - [x] Automated `Zero-Touch Sync` via `.envrc` with live connectivity checks.
- **Conditional Vagrant Fallback**:
    - [x] Restructure workflow to detect AWS availability.
    - [x] Trigger `vagrant_integration` only if the AWS sandbox is inaccessible.
- **Environment Stabilization**:
    - [x] Implement the `python3 -m venv` strategy for all jobs.
    - [x] Set `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`.
- **Trigger Refinement**: [x] Ensure AWS integration only runs on Pull Requests from `aws-dev`.

### 3. Tooling Improvements (`Makefile`)
- **New Targets**: Implement `test-aws-provision-tomcat` and `test-aws-upgrade-candidate` to match Azure's functional targets.
- **Connectivity Checks**: Add `win_ping` verification steps before running full playbooks.
- **Dynamic Metadata**: Resolve AWS Account ID and Region dynamically from the environment.

### 4. Documentation
- [x] Document AWS-specific regressions and resolutions in `docs/issues/` (see `2026-02-14-aws-integration-hurdles.md`).
- [ ] Update `memory-bank/` to reflect AWS stabilization status.

### 5. Related Plans
- `docs/plans/archive/2026-02-14-controlled-ci-execution.md` - CI trigger optimization (path filtering, draft PRs)
- `docs/issues/2026-02-14-aws-infrastructure-drift.md` - Dynamic resource ID discovery strategy

## Success Criteria
- [ ] AWS integration tests pass on the self-hosted macOS runner.
- [ ] No manual secret rotation required for rotating AWS sandboxes.
- [ ] Playbook execution is stable without "worker dead state" errors.
- [ ] Documentation is complete and synced with the implementation.
