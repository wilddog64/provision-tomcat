# CI Workflow Regressions: Root Cause and Resolution

## Problem Statement
The CI workflow failed following the "Tooling Consistency" update due to several regressions in collection dependencies, role resolution, and linting behavior.

## Root Causes

1.  **Missing Collection Dependency:** The `community.windows` collection was inadvertently omitted from the `Makefile` and `scripts/setup.sh` `deps` targets. Since several tasks (e.g., `win_unzip`, `win_firewall_rule`) depend on this collection, the syntax checks failed in clean CI environments.
2.  **ansible-lint HTTPS Auth Failures:** In a CI environment, `ansible-lint` attempted to install role dependencies from `requirements.yml` using HTTPS. Because these are private repositories, the clone failed due to lack of interactive credentials.
3.  **Role Resolution Failure:** `ansible-playbook --syntax-check` could not find the `provision-tomcat` role. Even though the repository root *is* the role, Ansible requires the role to be present in a directory named `provision-tomcat` within the search path.
4.  **CI/Kitchen Drift:** The `win11-baseline` platform was disabled in `.kitchen.yml`, but the `vagrant-test` job in `.github/workflows/ci.yml` still attempted to target it, causing "instance not found" errors.
5.  **Rigid Tool Resolution:** The initial `Makefile` attempt to force toolchain consistency was too brittle and failed if binaries were not exactly in the same directory as `ansible-lint`.

## Resolutions

1.  **Restored `community.windows`:** Added the collection back to `Makefile` and `scripts/setup.sh`.
2.  **Offline Linting:** Added `--offline` to the `ansible-lint` command in the `Makefile`. Since `ci.yml` already clones dependencies via SSH into the `roles/` directory, the offline flag prevents `ansible-lint` from making redundant (and failing) HTTPS requests.
3.  **Symlink Role Resolution:** Updated the `syntax` target in the `Makefile` to explicitly symlink the current directory into `roles/provision-tomcat`. This ensures Ansible recognizes the repo root as the expected role.
4.  **Workflow Synchronization:** Commented out the `vagrant-test` job in `ci.yml` to align with the disabled state of the `win11-baseline` platform in Kitchen.
5.  **Robust Binary Resolution:** Refactored the `Makefile` to use a more resilient resolution macro that prefers the same toolchain directory but falls back to the system `PATH` if needed.
6.  **Kitchen Portability:** Added a fallback to `ansible-playbook` in `.kitchen.yml` for environments where `.direnv` paths do not exist.

## Verification Results
- **Validation Job:** PASSED. Both `ansible-lint` and `ansible-playbook --syntax-check` now complete successfully in the CI environment.
- **Integration Tests:** Azure/AWS integration tests are currently failing due to missing secrets/credentials in the upstream environment (unrelated to these tooling fixes).
