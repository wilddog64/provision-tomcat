# CI/CD Security Architecture

**Date:** 2026-02-04
**Scope:** Self-Hosted macOS Runner Security

This document outlines the security measures implemented in our GitHub Actions workflow (`integration.yml`) to safely run integration tests on a self-hosted runner.

## 1. Execution Control (Fork Protection)

Running code from untrusted forks on a self-hosted runner is a critical security risk. To mitigate this, we enforce strict execution guards at the job level.

**Implementation:**
The `kitchen-test` job includes the following condition:

```yaml
jobs:
  kitchen-test:
    # Security: Only run on trusted PRs/pushes (No Forks)
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
```

**Effect:**
- **Pushes:** Runs only on pushes to branches within the `wilddog64/provision-tomcat` repository (restricted to maintainers).
- **Pull Requests:** Runs **ONLY** if the PR originates from the same repository (e.g., a feature branch). PRs from forks (e.g., `contributor/provision-tomcat`) are blocked immediately and will not execute any code on the runner.

## 2. SSH Key Management (Dependency Access)

This project depends on private repositories (e.g., `provision-windows-security`). We use **SSH Deploy Keys** instead of Personal Access Tokens (PATs) for least-privilege access.

**Challenge:**
GitHub rejects authentication if the SSH agent offers a key that doesn't have access to the specific repository being cloned, even if a valid key is available later in the list ("Ambiguous Key" issue).

**Solution: SSH Config Aliases**
We dynamically generate an `~/.ssh/comments` config during the build to map specific keys to fake hostnames:

```ssh
Host windows-base-repo
  HostName github.com
  IdentityFile ~/.ssh/id_windows_base
  IdentitiesOnly yes

Host provision-security-repo
  HostName github.com
  IdentityFile ~/.ssh/id_provision_security
  IdentitiesOnly yes
```

We then clone using these aliases:
```bash
git clone windows-base-repo:wilddog64/windows-base.git roles/windows-base
```

**Security Benefits:**
- **Isolation:** Each dependency uses its own specific read-only key.
- **No PATs:** Avoids using broad-scope Personal Access Tokens that could expose the entire user account.
- **Ephemeral:** Keys are injected from GitHub Secrets only for the duration of the job and cleaned up when the runner workspace is cleared.

## 3. Environment Isolation

Self-hosted runners persist state between runs, making them vulnerable to pollution or conflict.

**Measures:**
- **Vagrant Wrapper:** We wrap the `vagrant` binary with `env -i` to strip all environment variables (especially `BUNDLE_*` and `RUBYOPT`) before execution. This prevents malicious or accidental environment leakage from affecting the host system or the Vagrant process.
- **Local Paths:**
  - Ruby gems are installed to `vendor/bundle` (local to workspace).
  - Python packages are installed to `.venv` (local to workspace).
  - This prevents conflicts with the host's global `rbenv` or `brew` installed packages.

## 4. Resource Cleanup

To prevent "state bleeding" between runs (e.g., a malicious PR leaving a VM running to spy on the next job), we enforce aggressive cleanup.

**Implementation:**
- **Pre-flight:** Before checking out code, the workflow scans for and destroys any stale VirtualBox VMs matching the project pattern.
- **Post-flight:** A specific cleanup step runs `if: always()` at the end of the job to ensure all VMs are powered off and unregistered, even if the test crashes.

```yaml
      - name: Post-Test Cleanup
        if: always()
        run: |
          VBoxManage controlvm "$VM" poweroff || true
          VBoxManage unregistervm "$VM" --delete || true
```

## 5. Runner Registration

The runner is registered at the **User Level** (`wilddog64`) rather than the Repository Level.

**Reason:**
- Allows a single trusted runner to handle CI for multiple private and public repositories owned by the user.
- Combined with the **Fork Protection** (Section 1), this maintains security while maximizing resource utilization.
