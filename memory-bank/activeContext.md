# Active Context

## Current Focus
- Make upgrade and candidate workflows accept Java and Tomcat versions from `Makefile` targets instead of hardcoded playbook values.
- Keep AWS candidate testing viable with current releases while preserving checksum verification.

## Active Findings
- Local AWS WinRM parity is fixed in `Makefile`; the local path now authorizes and revokes `5985`/`8080`/`9080` around AWS test runs.
- Upgrade-oriented `Makefile` targets now pass Java/Tomcat version overrides through Kitchen into `tests/playbook-upgrade.yml`.
- Live validation passed for `make test-aws-upgrade-candidate` using Java `21 -> 25` and Tomcat `9.0.115 -> 9.0.117` with explicit archive URLs and SHA-512 checksums; the AWS candidate target created the instance, converged successfully, verified the candidate endpoint, and cleaned up the instance plus SG ingress.
- Automatic Tomcat metadata resolution is now implemented in `Makefile`; version-only overrides resolve release URL plus SHA-512 automatically and passed a live AWS validation run.
- A live AWS candidate test proved candidate mode works on cloud instances up to the candidate stage:
  - baseline primary responded on `8080`
  - candidate responded on `9080`
  - Java `25` + Tomcat `9.0.117` installed successfully
- The same live test exposed three remaining gaps:
  - legacy Tomcat versions such as `9.0.115` may require `archive.apache.org`
  - newer Tomcat versions require version-specific SHA-512 checksums
  - AWS promotion still needs a reliable inventory handoff for the follow-up `ansible-playbook` call

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
- Wire a fully supported AWS promotion step so the candidate workflow validates post-promotion primary health.
- Fix workflow triggers so CI runs for PRs to `main` instead of direct pushes to dev branches.
