# Configurable Upgrade Version Targets

## Objective

Allow upgrade and candidate workflows to accept Java and Tomcat versions from `Makefile` targets instead of relying on hardcoded values in `tests/playbook-upgrade.yml` and ad hoc temporary Kitchen overrides.

## Background

The repository currently mixes three version sources:

- `defaults/main.yml` pins the normal install path to Tomcat `9.0.115`.
- `tests/playbook-upgrade.yml` hardcodes upgrade step versions as Tomcat `9.0.112 -> 9.0.113` and Java `17 -> 21`.
- `Makefile` defines `JAVA_NEW_VERSION` and `TOMCAT_NEW_VERSION`, but the AWS and candidate workflows do not cleanly feed those values into the playbook.

During the live AWS candidate test with newer releases, the workflow only succeeded by generating temporary Kitchen YAML overrides at runtime. That proved the candidate pattern works on AWS up to candidate validation, but also exposed that version selection, archive URLs, checksums, and promotion orchestration are not first-class inputs yet.

## Problem Statement

We need a supported way to run commands like these without editing YAML by hand:

```bash
make test-upgrade-candidate-win11 \
  JAVA_OLD_VERSION=21 JAVA_NEW_VERSION=25 \
  TOMCAT_OLD_VERSION=9.0.115 TOMCAT_NEW_VERSION=9.0.117

make test-aws-upgrade-candidate \
  JAVA_OLD_VERSION=21 JAVA_NEW_VERSION=25 \
  TOMCAT_OLD_VERSION=9.0.115 TOMCAT_NEW_VERSION=9.0.117
```

## Technical Plan

### 1. Parameterize upgrade versions in `tests/playbook-upgrade.yml`

- Replace hardcoded version selection with explicit variables:
  - `upgrade_java_old_version`
  - `upgrade_java_new_version`
  - `upgrade_tomcat_old_version`
  - `upgrade_tomcat_new_version`
- Default those variables to the current legacy behavior (`17 -> 21`, `9.0.112 -> 9.0.113`) so existing callers still work.
- Derive `jdk_version` and `tomcat_version` from `upgrade_step` using those variables rather than embedded literals.

### 2. Pass versions from `Makefile`

- Update the upgrade helper targets to pass the new version variables into Kitchen or Ansible.
- Keep the existing `JAVA_NEW_VERSION` / `TOMCAT_NEW_VERSION` interface, and add the matching `JAVA_OLD_VERSION` / `TOMCAT_OLD_VERSION` path consistently across candidate and non-candidate targets.
- Ensure the AWS targets and Win11/Vagrant targets use the same variable contract.

### 3. Handle Tomcat URL + checksum drift

- Add a supported way to override `tomcat_download_url` and `tomcat_checksum` when testing versions that are no longer on `dlcdn.apache.org`.
- Prefer a deterministic mapping strategy rather than manual one-off edits.
- Preserve checksum verification; do not weaken the security gate.

### 4. Normalize AWS candidate promotion

- Move AWS candidate promotion into a supported target or verifier flow instead of relying on temporary generated Kitchen files.
- Ensure promotion has a valid inventory source for the AWS instance.
- Confirm the full lifecycle works in order:
  - baseline primary on `8080`
  - candidate on `9080`
  - promotion
  - primary healthy again on `8080`

### 5. Documentation

- Update issue docs with the latest-version live test findings.
- Update `memory-bank/activeContext.md` and `memory-bank/progress.md` when implementation lands.
- Document the target syntax for custom version runs in `README.md` or the testing docs if the interface becomes user-facing.

## Success Criteria

- `Makefile` targets accept old/new Java and Tomcat versions without manual YAML editing.
- Upgrade tests continue to work with the current default version pair.
- Candidate workflows can be exercised with newer versions such as Java `25` and Tomcat `9.0.117`.
- Archive-hosted Tomcat versions remain compatible with checksum enforcement.
- AWS candidate runs validate both candidate reachability and post-promotion primary reachability.

## Out of Scope

- Changing the repository-wide default install version in `defaults/main.yml`.
- Removing checksum enforcement.
- Refactoring unrelated Kitchen platforms or verifier structure.

## Implementation Notes

- Keep the change surgical: variable wiring first, behavioral refactors second.
- Prefer one shared version contract across Vagrant and AWS paths.
- Use the live findings in `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md` as the acceptance baseline.
