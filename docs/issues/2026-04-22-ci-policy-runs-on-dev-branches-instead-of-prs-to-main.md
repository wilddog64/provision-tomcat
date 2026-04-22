# CI policy runs on dev branches instead of PRs to `main`

## What was observed

- The repository workflow currently triggers on direct pushes to development branches.
- The repository workflow also triggers on pull requests targeting development branches.
- The intended policy is:
  - `main` remains protected
  - development branches such as `aws-dev` are used for active work
  - CI should run when a PR is created or updated for merge into `main`

## Actual workflow configuration

Current `.github/workflows/ci.yml` trigger block:

```yaml
on:
  push:
    branches: [main, azure-dev, aws-dev, vagrant-dev]
  pull_request:
    branches: [main, azure-dev, aws-dev, vagrant-dev]
    types: [opened, synchronize, reopened, ready_for_review]
```

## Root cause

- Workflow triggers are still configured around environment branches rather than the desired merge-to-`main` review flow.
- This causes CI noise on branch pushes and PRs that are not part of the final merge path.
- The current trigger configuration is inconsistent with the intended branch policy.

## Why this is a bug

- Developers should be able to iterate on `aws-dev` without automatically running CI on every push.
- CI resources should be focused on PRs that are actually intended for merge into `main`.
- Protecting only `main` while still running `push` CI on `aws-dev` preserves the cost/noise problem without giving the intended policy benefit.

## Recommended follow-up

- Remove or narrow the `push` trigger so branch pushes to development branches do not run CI.
- Restrict `pull_request.branches` to `main`.
- Keep or refine `ready_for_review` / draft gating so heavy jobs run only when the PR is intended for merge.
- Leave `main` protected.

## Related

- Current workflow: `.github/workflows/ci.yml`
