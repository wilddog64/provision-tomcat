# Active Context

## Current Focus
- Make upgrade and candidate workflows accept Java and Tomcat versions from `Makefile` targets instead of hardcoded playbook values.
- Keep AWS candidate testing viable with current releases while preserving checksum verification.

## Active Findings
- Local AWS WinRM parity is fixed in `Makefile`; the local path now authorizes and revokes `5985`/`8080`/`9080` around AWS test runs.
- Upgrade-oriented `Makefile` targets now pass Java/Tomcat version overrides through Kitchen into `tests/playbook-upgrade.yml`.
- Live validation passed for `make test-aws-upgrade-candidate` using Java `21 -> 25` and Tomcat `9.0.115 -> 9.0.117` with explicit archive URLs and SHA-512 checksums; the AWS candidate target created the instance, converged successfully, verified the candidate endpoint, and cleaned up the instance plus SG ingress.
- The remaining Tomcat automation blocker is now treated as a bug: version overrides still require manual URL/checksum metadata, which prevents fully automatic CI/deployment flows for arbitrary Tomcat versions.
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
- AWS latest-version live findings: `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`
- Local WinRM parity blocker/fix: `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`
- Checksum automation bug: `docs/issues/2026-04-22-tomcat-checksum-resolution-blocks-version-override-automation.md`

## Current State Snapshot
- Current working branch: `aws-dev`
- Local branch is ahead of `origin/aws-dev`
- `origin/aws-dev` is protected and expects pull-request flow plus the `lint` status check
- Repository default install path still pins Tomcat `9.0.115`
- Upgrade test playbook still hardcodes Tomcat `9.0.112 -> 9.0.113` and Java `17 -> 21`

## Next Actions
- Implement automatic Tomcat URL/checksum resolution for version overrides.
- Wire a fully supported AWS promotion step so the candidate workflow validates post-promotion primary health.
