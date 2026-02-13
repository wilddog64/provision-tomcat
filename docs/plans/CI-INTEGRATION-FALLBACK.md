# Plan: CI Integration Test Fallback Mechanism

## Objective
Automatically detect if Azure credentials are available in the CI environment. If missing, fall back to running a standard Test Kitchen suite using the Vagrant/VirtualBox driver to ensure integration testing still occurs.

## Context
The `azure-test` job currently fails when `AZURE_CLIENT_ID` and other secrets are missing. This often happens when a developer pushes to a branch without an active Azure sandbox environment. By falling back to a local (Vagrant) test on the self-hosted runner, we maintain a high signal of quality without requiring manual workflow adjustments.

## Strategy

### 1. Detection Phase
- In the `azure-test` job, check for the presence of the `AZURE_CLIENT_ID` secret.
- If the secret is empty, set an environment variable or output indicating that Azure is unavailable.

### 2. Execution Logic
- **If Azure is available:** Proceed with the existing `az login` and `make test-azure-provision-tomcat` logic.
- **If Azure is unavailable:**
    - Log a warning that Azure tests are being skipped due to missing credentials.
    - Fall back to executing `make test-win11` (which uses Test Kitchen with the Vagrant/VirtualBox driver).
    - Ensure the self-hosted runner has the necessary Vagrant/VirtualBox environment (this is assumed as it currently runs the `vagrant-test` job when enabled).

### 3. Workflow Consolidation
- Consider merging the logic into a single `integration-test` job that handles both "Azure-preferred" and "Vagrant-fallback" scenarios.
- This reduces complexity and ensures that at least one form of integration test runs for the `azure-dev` and `main` branches.

## Proposed Changes

### `.github/workflows/ci.yml`
- Update the `azure-test` job (potentially renamed to `integration-test`).
- Add a conditional step to check for secrets.
- Use `if` conditions on steps to toggle between `az login`/`make test-azure-...` and `make test-win11`.

### `Makefile`
- Ensure the `test-win11` target is healthy and correctly resolves binaries (this was addressed in the previous fix).

## Verification Plan
1.  **Azure Available:** Trigger a run where secrets are present (manually or via a sandbox) and verify Azure tests run.
2.  **Azure Missing:** Trigger a run on `azure-dev` without secrets and verify that it successfully falls back to `make test-win11` on the self-hosted runner.
