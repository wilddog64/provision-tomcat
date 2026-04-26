# Progress Tracker

## Recently Completed
- [x] Fixed AWS Kitchen region drift and documented the result in `docs/issues/2026-04-21-kitchen-aws-region-mismatch.md`.
- [x] Implemented local AWS ingress parity in `Makefile` for `test-aws-provision-tomcat` and `test-aws-upgrade-candidate`.
- [x] Captured local WinRM blocker findings in `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`.
- [x] Ran a live AWS candidate test with newer versions and documented the findings in `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`.
- [x] Wrote the current implementation spec in `docs/plans/2026-04-22-configurable-upgrade-version-targets.md`.
- [x] Wrote the AWS promotion-validation spec in `docs/plans/2026-04-22-aws-candidate-promotion-validation.md`.
- [x] Refreshed `README.md` to point at current docs and version examples.
- [x] Implemented configurable Java/Tomcat upgrade inputs for candidate workflows.
- [x] Live-validated `make test-aws-upgrade-candidate` with Makefile-provided version, URL, and checksum overrides.
- [x] Documented checksum-resolution blocker in `docs/issues/2026-04-22-tomcat-checksum-resolution-blocks-version-override-automation.md`.
- [x] Implemented automatic Tomcat URL/checksum resolution for version overrides.
- [x] Documented CI trigger / branch-policy mismatch in `docs/issues/2026-04-22-ci-policy-runs-on-dev-branches-instead-of-prs-to-main.md`.
- [x] Implemented AWS candidate promotion validation in the supported target.
- [x] Added easy validation target `make test-aws-upgrade-candidate-latest`.
- [x] Live-validated the full promote-and-verify AWS path with `make test-aws-upgrade-candidate-latest`.
- [x] Made `test-aws-upgrade-candidate` depend on `sync-aws`.
- [x] Restricted CI triggers to PRs targeting `main` plus manual dispatch.
- [x] Re-ran `make test-aws-upgrade-candidate-latest` successfully after the latest fixes (log: `scratch/live-test-aws-upgrade-candidate-latest-now-20260422-181629.log`).
- [x] Documented the initial AWS promotion-helper `Error 127` failure in `docs/issues/2026-04-22-aws-candidate-promotion-helper-error-127.md`.
- [x] Verified repository branch protection is scoped to `main`; `aws-dev` is unprotected.
- [x] Documented that the AWS candidate promotion-helper fix is still undelivered from an operator perspective because the validated local commit stack has not been pushed.
- [x] Delivered the validated AWS candidate promotion-helper fix stack to `origin/aws-dev` (push includes `457d2e0`).
- [x] Documented the post-delivery local validation blocker in `docs/issues/2026-04-23-local-validation-blocked-by-missing-bundler-4.0.6.md`.
- [x] AWS candidate promotion fix was delivered in commit `457d2e0`; PR URL: none (per workflow, no PR created by this agent).
- [x] Documented the new AWS candidate pre-converge WinRM timeout / missing-instance failure in `docs/issues/2026-04-23-aws-candidate-winrm-timeout-before-converge.md`.

## In Progress
- [ ] **Provider plugin refactor** — PLANNED. Spec: `docs/plans/2026-04-26-provider-plugin-makefile-refactor.md`. Phase 1: extract AWS defines → `scripts/providers/aws/`; add Azure stubs. Phase 2/3: Azure and GCP implementation (separate tasks).
- [ ] **lib-acg GitHub Secrets sync integration** — GATED on lib-acg `feat/phase5-ci-setup` merge. Move `ansible/bin/sync-aws-secrets` into lib-acg as `acg_sync_github_secrets`; provision-tomcat `sync-aws` sources lib-acg. Spec: `docs/plans/2026-04-26-lib-acg-github-secrets-sync-integration.md`.
- [ ] Restore Bundler `4.0.6` / local validation environment if repo-native `make syntax` proof is still required.
- [ ] Investigate the AWS candidate pre-converge WinRM timeout with AWS-side instance diagnostics.

## Historical Notes
- Earlier CI hardening, security roadmap, and AWS stabilization planning have been moved to `docs/plans/archive/` and related issue docs.
- The repository already includes completed fixes for checksum enforcement, CI fork protection, runner-IP-scoped AWS ingress, and local AWS ingress parity.
- Older undated CI/GitHub troubleshooting notes have been moved to `docs/issues/archive/` so `docs/issues/` stays focused on active operator-facing references.
