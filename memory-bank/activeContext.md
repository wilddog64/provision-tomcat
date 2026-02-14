# Active Context

## Current Session Objective
Address CI fragility due to ephemeral AWS sandbox resource ID changes, implementing a "Hybrid Zero-Touch Sync" strategy.

## Recent AWS Integration Update
- **New Critical Error**: Encountered `The subnet ID 'subnet-0bf736b950e25a150' does not exist in the specified region us-east-1.`
- **Root Cause**: The underlying AWS sandbox environment (specifically resource IDs like `subnet_id`) has changed or been recreated.
- **Distinction: Credentials vs. Resource IDs**:
    - `make sync-aws` refreshes **AWS credentials** (Access Key, Secret Key, Session Token) in GitHub Secrets. This is a manual step required when the sandbox's OAuth keys change.
    - The current error is about **infrastructure resource IDs** (like subnet ID) hardcoded in `.kitchen.yml`. `make sync-aws` does NOT update these resource IDs.
- **CI Fragility**: Hardcoding ephemeral resource IDs makes the CI process fragile, as changes in the sandbox infrastructure will break the tests.

## Solution: Hybrid Zero-Touch Sync Strategy
Adopted a "Hybrid Zero-Touch Sync" approach as a new architectural pattern to mitigate CI fragility in ephemeral AWS sandboxes:
1.  **Manual Credential Sync**: `make sync-aws` will remain a manual initial step performed locally by the user to refresh OAuth/session tokens and push them to GitHub Secrets. This acknowledges the hard constraint of dynamic credential updates on sandbox recreation.
2.  **Automatic Resource Discovery**: After successful manual credential sync, subsequent local `make` targets for AWS integration will dynamically discover resource IDs (subnet, security group, AMI) from the live sandbox using AWS APIs. These discovered IDs will then be used for the test run.
This approach balances security (explicit credential refresh) with automation (resource ID discovery), mitigating CI fragility due to infrastructure drift.

## Current State Snapshot
- AWS Integration pipeline is fully stabilized and verified on the `aws-dev` branch (based on previous, now outdated, sandbox resources).
- Created PR #6 to merge AWS stabilization into `main`.
- **Sandbox Status**: AWS sandbox session was extended by the user after expiration, leading to new resource IDs. Local `make sync-aws` was performed for credentials.
- Established "Zero-Touch Sync" via `.envrc` for rotating sandbox credentials.
- Achieved CI portability using `DEPLOY_KEY` secrets for all private roles.

## What Was Done
1. **Applied Fixes:** Restored missing collection to `deps` targets, implemented offline linting, and added symlink-based role resolution in `Makefile`.
2. **Refined CI Triggers:** Added manual `environment` selection to `workflow_dispatch`. Fixed logic for `vagrant_integration` to correctly handle branch-based execution vs. fallback on `main`.
3. **Implemented D: Drive Support for AWS:** Updated `tests/playbook.yml` with a `pre_task` to initialize and format raw disks (EBS volumes) as D: drive.
4. **Hardened CI Cleanup:** Implemented `if: always()` mandatory cleanup steps in `ci.yml` to force `kitchen destroy` regardless of job outcome.
5. **Fixed Connectivity Check Order:** Reordered `Makefile` targets to run `win_ping` AFTER `converge` to ensure the generated inventory is available.
6. **Status Check Rename**: Renamed the CI validation job to `lint` to satisfy mandatory branch protection rules for `main`.

## Why These Decisions Made
- **Why t2.medium in us-east-1e:** Physical hardware constraints in the legacy zone prevented `t3` usage. Architectural integrity prioritized functional compatibility in the user's specific sandbox environment.
- **Why Programmatic Ingress Authorization:** Programmatically opening ports `5985` and `8080` in CI ensures that the integration tests are self-healing even if the underlying sandbox security groups are reset to a restrictive state.
- **Why official AWS Credential Action:** Replaced manual credential injection with `aws-actions/configure-aws-credentials` to handle temporary sessions and empty tokens more gracefully, aligning with GitHub Actions best practices.
- **Why Dynamic Hostname Verifier:** Decouples the verification logic from the assumption of `localhost`, allowing Test Kitchen to reach AWS public IPs or Vagrant local IPs using the same suite definition.

## Immediate Next Actions
- Refresh AWS credentials in GitHub Secrets (if not already handled by user).
- Monitor CI run for PR #6 once triggered again.
- Finalize administrative merge to `main`.

## Risks / Follow-ups
- **AZ Drift**: If the sandbox allocation moves to a non-legacy AZ, `t2` instances may be less efficient than `t3`. Recommend periodic review of instance types against AZ capabilities.
- **Cleanup Persistence**: While `if: always()` is implemented, manual monitoring of the AWS console is still advised during active development to ensure no orphaned resources remain due to workflow cancellation limits.

## New Plan: Controlled CI Execution
- **Problem**: Unnecessary CI workflow runs trigger during discussion or documentation updates, wasting resources and creating noise.
- **Solution**: Implement path filtering in `ci.yml` to prevent triggers on changes to `docs/` or `memory-bank/`. Utilize Draft PRs to signal when a PR is not yet ready for full CI.
