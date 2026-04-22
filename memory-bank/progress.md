# Progress Tracker

## Recently Completed
- [x] Fixed AWS Kitchen region drift and documented the result in `docs/issues/2026-04-21-kitchen-aws-region-mismatch.md`.
- [x] Implemented local AWS ingress parity in `Makefile` for `test-aws-provision-tomcat` and `test-aws-upgrade-candidate`.
- [x] Captured local WinRM blocker findings in `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`.
- [x] Ran a live AWS candidate test with newer versions and documented the findings in `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`.
- [x] Wrote the current implementation spec in `docs/plans/2026-04-22-configurable-upgrade-version-targets.md`.

## In Progress
- [ ] Implement configurable Java/Tomcat upgrade inputs for candidate workflows.
- [ ] Add supported URL/checksum overrides for archived or newer Tomcat releases.
- [ ] Complete a fully supported AWS promotion step for the candidate workflow.

## Historical Notes
- Earlier CI hardening, security roadmap, and AWS stabilization planning have been moved to `docs/plans/archive/` and related issue docs.
- The repository already includes completed fixes for checksum enforcement, CI fork protection, runner-IP-scoped AWS ingress, and local AWS ingress parity.
