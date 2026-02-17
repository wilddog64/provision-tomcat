# GitHub Actions workflow_run Limitation

## Problem

When using `workflow_run` to chain workflows (e.g., run integration tests only after validation passes), the second workflow doesn't trigger on pull requests from feature branches.

Example configuration that **doesn't work** on PR branches:

```yaml
# integration.yml
on:
  workflow_run:
    workflows: ["Validation"]
    types: [completed]
    branches: [main]
```

## Root Cause

**GitHub Actions uses the workflow file from the default branch (usually `main`) for `workflow_run` triggers, not from the PR branch.**

This means:

1. You create a feature branch and add/modify `integration.yml`
2. You open a PR targeting `main`
3. The Validation workflow runs (triggered by `pull_request`)
4. Integration workflow **does not run** because:
   - GitHub reads `integration.yml` from `main` branch
   - The `main` branch version doesn't have your changes yet
   - Even if it did, `branches: [main]` filter only matches runs on `main`

## Solution

### Option 1: Single Workflow with Multiple Jobs (Recommended)

Combine validation and integration into one workflow file with `needs` dependency:

```yaml
# ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make check

  integration:
    name: Integration Tests
    needs: lint  # Only runs after lint succeeds
    runs-on: [self-hosted, macOS]
    steps:
      - uses: actions/checkout@v4
      - run: make test-upgrade-baseline-win11
```

**Benefits:**
- Works immediately on PRs (no need to merge first)
- `needs: lint` ensures integration only runs after validation passes
- Each job still runs on its own runner (ubuntu-latest vs self-hosted)

### Option 2: Merge to Main First

If you must use separate workflow files:

1. Merge the `workflow_run` changes to `main` first
2. Then PRs will trigger the chained workflow

**Drawback:** Requires merge before testing, which defeats the purpose of PR validation.

### Option 3: Remove Branch Filter (Partial Fix)

Remove `branches: [main]` from `workflow_run`:

```yaml
on:
  workflow_run:
    workflows: ["Validation"]
    types: [completed]
    # No branches filter
```

**Drawback:** Still requires the workflow file to exist on `main` branch.

## Why This Limitation Exists

GitHub designed `workflow_run` for post-merge automation scenarios like:
- Deploy after tests pass on main
- Publish packages after release
- Notify external systems

It was not designed for PR-based CI chains where the workflow file itself is being modified.

## Comparison

| Approach | Works on PR? | Separate Runners? | Complexity |
|----------|--------------|-------------------|------------|
| Single workflow + `needs` | Yes | Yes | Low |
| `workflow_run` | No (until merged) | Yes | Medium |
| Separate workflows, same triggers | Yes | Yes | High (no dependency) |

## Recommendation

Use **Option 1: Single Workflow with Multiple Jobs**. It provides:
- Immediate PR feedback
- Job-level dependencies
- Different runners per job
- Simple configuration

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    # ...

  integration:
    needs: lint
    runs-on: [self-hosted, macOS]
    # ...
```
