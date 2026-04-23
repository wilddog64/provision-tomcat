# Active Context

## Current Focus
- Keep AWS candidate testing viable with current releases while preserving checksum verification.
- Align CI policy with the intended branch model so CI runs for PRs to `main`, not pushes to dev branches.

## Active Findings
- Local AWS WinRM parity is fixed in `Makefile`; the local path now authorizes and revokes `5985`/`8080`/`9080` around AWS test runs.
- Upgrade-oriented `Makefile` targets now pass Java/Tomcat version overrides through Kitchen into `tests/playbook-upgrade.yml`.
- Automatic Tomcat metadata resolution is now implemented in `Makefile`; version-only overrides resolve release URL plus SHA-512 automatically.
- AWS candidate promotion validation is now implemented in the supported target:
  - candidate is verified on `9080`
  - promotion runs against the real AWS instance
  - promoted primary is validated on `localhost:8080` via WinRM
- Easy validation path is available through `make test-aws-upgrade-candidate-latest`.
- `test-aws-upgrade-candidate` now depends on `sync-aws` so the local credential refresh happens before the AWS candidate run.
- CI workflow policy is now aligned in code: CI runs for PRs to `main` and manual dispatches, not direct dev-branch pushes.
- Repository branch policy is now verified live: `main` remains protected and `aws-dev` is unprotected.
- The AWS candidate promotion-helper `Error 127` fix is now delivered to `origin/aws-dev`.
- Local repo-native proof collection is currently blocked by missing Bundler `4.0.6` / local permission issues when running `make syntax`.
- A fresh AWS candidate run now shows a new pre-converge failure: WinRM never becomes reachable and cleanup reports the EC2 instance no longer exists.

## Active References
- Spec: `docs/plans/2026-04-22-configurable-upgrade-version-targets.md`
- Promotion spec: `docs/plans/2026-04-22-aws-candidate-promotion-validation.md`
- AWS latest-version live findings: `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`
- Historical failed promotion helper run: `docs/issues/2026-04-22-aws-candidate-promotion-helper-error-127.md`
- Delivery-state bug for that fix: `docs/issues/2026-04-23-aws-candidate-promotion-fix-not-delivered-to-branch.md`
- Validation blocker after delivery: `docs/issues/2026-04-23-local-validation-blocked-by-missing-bundler-4.0.6.md`
- New AWS WinRM timeout blocker: `docs/issues/2026-04-23-aws-candidate-winrm-timeout-before-converge.md`
- Local WinRM parity blocker/fix: `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`
- Checksum automation bug: `docs/issues/2026-04-22-tomcat-checksum-resolution-blocks-version-override-automation.md`
- CI policy bug: `docs/issues/2026-04-22-ci-policy-runs-on-dev-branches-instead-of-prs-to-main.md`

## Current State Snapshot
- Current working branch: `aws-dev`
- Local branch is aligned with `origin/aws-dev`.
- `aws-dev` is unprotected; `main` remains the protected merge target with required PR review and `lint`
- Repository default install path still pins Tomcat `9.0.115`
- Upgrade test playbook still hardcodes Tomcat `9.0.112 -> 9.0.113` and Java `17 -> 21`
- Delivery record: AWS candidate promotion fix delivered in commit `457d2e0`; PR URL: none (per workflow, no PR created by this agent)

## Next Actions
- Investigate the new AWS pre-converge WinRM timeout with AWS-side instance diagnostics before modifying upgrade logic.
