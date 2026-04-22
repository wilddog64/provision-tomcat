# AWS Candidate Promotion Validation

## Objective

Make the AWS candidate workflow validate the full promotion lifecycle, not just candidate readiness, so the supported target proves all of the following in one run:

- baseline service is reachable on `8080`
- candidate service is reachable on `9080`
- promotion executes against the real AWS instance
- primary service is reachable again on `8080` after promotion

## Background

The repository now supports version-driven candidate runs from `Makefile` targets, and automatic Tomcat URL/checksum resolution is implemented. Live AWS tests confirmed:

- EC2 provisioning works
- candidate-mode converge works
- the candidate endpoint on `9080` is reachable

However, the direct promotion handoff still is not part of the supported AWS target. Earlier live testing showed the follow-up `ansible-playbook` invocation skipped because the inventory handoff was not valid for the AWS instance.

## Problem Statement

`make test-aws-upgrade-candidate` currently proves candidate readiness, but it does not yet prove the final cutover path. That leaves an important gap:

- candidate validation passes
- target exits successfully
- but promotion behavior is not actually validated as part of the supported workflow

This means AWS candidate testing is still incomplete compared with the intended zero-downtime methodology.

## Technical Plan

### 1. Define a supported AWS promotion path

- Choose one promotion path and make it first-class in the target:
  - reuse Kitchen-generated inventory if it is reliable, or
  - generate a minimal temporary inventory from current Kitchen state and AWS host data
- Avoid ad hoc manual runtime commands outside the target.
- Keep the promotion invocation deterministic and easy to inspect in logs.

### 2. Validate pre-promotion state explicitly

- Preserve the existing candidate validation on `9080`.
- Ensure the target records the instance hostname/IP and uses it consistently for:
  - WinRM connectivity
  - candidate HTTP validation
  - promotion call
  - post-promotion primary validation

### 3. Validate post-promotion primary health

- After promotion, wait for the primary service to recover on `8080`.
- Fail clearly if candidate validation passed but promotion or primary recovery did not.
- Keep cleanup behavior intact so failed runs still revoke ingress and destroy the instance unless `KEEP_AWS_VM` is set.

### 4. Preserve version-driven behavior

- Continue honoring:
  - `JAVA_OLD_VERSION`
  - `JAVA_NEW_VERSION`
  - `TOMCAT_OLD_VERSION`
  - `TOMCAT_NEW_VERSION`
- Continue honoring manual metadata overrides if provided.
- Continue using automatic Tomcat metadata resolution when only versions are passed.

### 5. Documentation

- Update `README.md` to describe that the AWS candidate target validates both candidate readiness and post-promotion primary health once implemented.
- Update `memory-bank/activeContext.md` and `memory-bank/progress.md` after implementation and live verification.
- Add or update an issue doc if the promotion path exposes new runtime blockers.

## Success Criteria

- `make test-aws-upgrade-candidate` performs a real promotion as part of the supported target.
- The target validates:
  - candidate on `9080`
  - promoted primary on `8080`
- The target continues to support version-only Tomcat inputs with automatic metadata resolution.
- Cleanup still destroys the instance and revokes ingress unless `KEEP_AWS_VM` is set.

## Out of Scope

- Reworking the general candidate design for Vagrant paths.
- Removing checksum enforcement.
- Changing repository-wide default Tomcat or Java versions.

## Implementation Notes

- Keep the change narrowly focused on AWS promotion validation.
- Prefer a single explicit inventory strategy rather than multiple fallback mechanisms.
- Use the existing successful candidate-stage AWS flow as the baseline, then layer promotion on top.

## Status update

- Implemented in `Makefile`: AWS candidate runs now perform a real promotion using a generated WinRM inventory built from Kitchen state.
- The supported target now validates:
  - candidate readiness through Kitchen verify on `9080`
  - post-promotion primary health on `localhost:8080` via WinRM
- Added convenience target: `make test-aws-upgrade-candidate-latest`
- Live validation passed with the easy target.
