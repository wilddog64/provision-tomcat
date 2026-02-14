# Plan: Controlled CI Execution (2026-02-14)

## Problem Statement

Currently, the GitHub Actions CI workflow is configured to run on every `push` or `pull_request` event to development branches (e.g., `aws-dev`) and `main`. This results in:
-   **Unnecessary CI runs**: Workflows trigger even when only documentation (`docs/`) or internal memory bank (`memory-bank/`) files are modified, which do not impact code functionality.
-   **Resource Consumption**: Wasted CI minutes and computational resources.
-   **Noise**: Increased activity in GitHub Actions logs during discussion or documentation phases, potentially obscuring important code-related CI results.
-   **Disruption to Discussion**: CI runs can be distracting or perceived as blocking during periods intended for review and collaboration.

## Goal

Optimize CI workflow triggers to run only when functionally relevant code changes are introduced, thereby conserving resources, reducing noise, and supporting a more focused discussion and development flow.

## Proposed Solutions

We will implement a two-pronged approach:

### 1. Path Filtering in `ci.yml`

Modify the `on: push` and `on: pull_request` triggers in `.github/workflows/ci.yml` to include `paths:` filters.

**Mechanism**:
-   Specify inclusion patterns for code, configuration, and test files that *should* trigger CI.
-   Specify exclusion patterns for documentation (`docs/**`) and memory bank (`memory-bank/**`) files that *should not* trigger CI if they are the *only* files changed.

**Example `ci.yml` snippet modification:**
```yaml
on:
  push:
    branches: [main, azure-dev, aws-dev, vagrant-dev]
    paths:
      - '**.yml'
      - '**.yaml'
      - '**.sh'
      - '**.py'
      - '**.rb'
      - 'Makefile'
      - 'tasks/**'
      - 'defaults/**'
      - 'vars/**'
      - 'roles/**'
      - 'tests/**'
      - '!docs/**'
      - '!memory-bank/**'
  pull_request:
    branches: [main, azure-dev, aws-dev, vagrant-dev]
    paths:
      - '**.yml'
      - '**.yaml'
      - '**.sh'
      - '**.py'
      - '**.rb'
      - 'Makefile'
      - 'tasks/**'
      - 'defaults/**'
      - 'vars/**'
      - 'roles/**'
      - 'tests/**'
      - '!docs/**'
      - '!memory-bank/**'
```
**Benefit**: Prevents CI runs for commits that only touch documentation or internal process files, directly addressing unnecessary resource consumption and noise.

### 2. Utilizing Draft Pull Requests

Encourage the use of GitHub's Draft Pull Request feature for early-stage development and discussion.

**Mechanism**:
-   When creating a new PR (via UI or `gh pr create --draft`), set it as a "Draft".
-   While Draft PRs still trigger workflows, jobs within the workflow can be made conditional to either:
    -   Run a "light" version of CI (e.g., only linting/syntax checks).
    -   Completely skip computationally intensive jobs (like integration tests) until the PR is marked "Ready for Review".
    -   This requires adding `if: github.event.pull_request.draft == false` to relevant jobs in `ci.yml`.

**Benefit**: Provides a clear signal for the PR's readiness for full CI validation, allowing developers to iterate on changes and gather early feedback without waiting for long-running tests.

## Impact on Architectural Patterns

-   **Test Orchestration Pattern**: Enhances control over when orchestrated tests run, making the process more efficient.
-   **Required Cross-Agent Documentation Pattern**: Supports discussion and documentation updates without triggering costly validation checks, ensuring the memory bank and issue logs can be updated fluidly.
-   **Environment Consistency**: Ensures CI resources are focused on validating code changes that directly impact the environment.

## Conclusion

Implementing path filtering and leveraging Draft PRs will lead to a more efficient, less noisy, and more cost-effective CI process, aligning with best practices for managing workflows in active development environments.