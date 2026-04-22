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
- Remaining branch-policy work is repository configuration: confirm that `main` stays protected while dev branches remain unprotected.

## Active References
- Spec: `docs/plans/2026-04-22-configurable-upgrade-version-targets.md`
- Promotion spec: `docs/plans/2026-04-22-aws-candidate-promotion-validation.md`
- AWS latest-version live findings: `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`
- Local WinRM parity blocker/fix: `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`
- Checksum automation bug: `docs/issues/2026-04-22-tomcat-checksum-resolution-blocks-version-override-automation.md`
- CI policy bug: `docs/issues/2026-04-22-ci-policy-runs-on-dev-branches-instead-of-prs-to-main.md`

## Current State Snapshot
- Current working branch: `aws-dev`
- Local branch is ahead of `origin/aws-dev`
- `aws-dev` is no longer protected; `main` should remain the protected merge target
- Repository default install path still pins Tomcat `9.0.115`
- Upgrade test playbook still hardcodes Tomcat `9.0.112 -> 9.0.113` and Java `17 -> 21`

## Next Actions
- Verify repository protection remains on `main` only.
