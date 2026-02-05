# CI Robustness Fixes: Vagrant, Bundler, and Ansible Discovery

**Date:** 2026-02-04
**Status:** Fixed
**Severity:** Blocker for CI on Self-Hosted Runners

## Context
When migrating CI to a self-hosted macOS runner (running natively on Apple Silicon), we encountered a cascade of environment conflicts between Ruby (Bundler), Python (Ansible), and Vagrant.

## Issue 1: Vagrant Crashes inside Bundler Environment

### Symptom
Running `bundle exec kitchen list` or `create` resulted in:
```
bundler/definition.rb:702:in `materialize': Could not find test-kitchen-4.0.0... in locally installed gems (Bundler::GemNotFound)
```
This happened because `kitchen-vagrant` shells out to `vagrant`. Vagrant (written in Ruby) inherited the `BUNDLE_GEMFILE` and `RUBYOPT` environment variables from the parent process (`bundle exec kitchen`). Vagrant's embedded Ruby then tried to load the gems specified in our Gemfile, failed (version mismatch or path mismatch), and crashed.

### Solution
We implemented a robust wrapper script for Vagrant that sanitizes the environment before execution. Using `unset` was insufficient; we moved to `env -i` (whitelist approach) as documented in `provision-jenkins`.

**Fix:** Create a wrapper in `~/.local/bin/vagrant` during CI:
```bash
#!/bin/bash
ENV_ARGS=(
  HOME="$HOME"
  PATH="/opt/vagrant/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  TERM="${TERM:-dumb}"
  LANG="${LANG:-en_US.UTF-8}"
  USER="$USER"
  SHELL="$SHELL"
  TMPDIR="${TMPDIR:-/tmp}"
)
[[ -n "${SSH_AUTH_SOCK:-}" ]] && ENV_ARGS+=( SSH_AUTH_SOCK="$SSH_AUTH_SOCK" )
exec /usr/bin/env -i "${ENV_ARGS[@]}" /usr/local/bin/vagrant "$@"
```

## Issue 2: Ansible Playbook "Command Not Found"

### Symptom
Kitchen failed during the converge step with:
```
sh: --extra-vars=...: command not found
```
This indicated that `kitchen-ansiblepush` could not find the `ansible-playbook` executable, resulting in an empty command string prefix.

### Root Cause
The `.kitchen.yml` configuration used an ERB template designed for local development with `direnv`:
```yaml
ansible_playbook_bin: <%= Dir.glob("#{Dir.pwd}/.direnv/python-*/bin/ansible-playbook").first %>
```
In CI, we use a standard Python `venv` (`.venv`), so `.direnv` does not exist. The Ruby code evaluated to `nil`, breaking the provisioner.

### Solution
We implemented a Python script in the CI workflow to dynamically patch `.kitchen.yml` (and `.kitchen-win.yml`) before running tests. It replaces the broken ERB line with the absolute path to the `ansible-playbook` binary in the CI's virtual environment.

## Issue 3: Stale VMs causing Port Conflicts

### Symptom
If a CI run crashed or was cancelled mid-test, the VirtualBox VM was left running. Subsequent runs failed to bind to port 25985/5985 (WinRM) or failed to create the VM because the name was already taken.

### Solution
We added **Pre-flight** and **Post-flight** cleanup steps to the workflow.
*   **Pre-flight:** Before checking out code, we scan for any VMs matching the project pattern (`kitchen-provision-tomcat...`), forcefully power them off, and unregister them.
*   **Post-flight:** Using `if: always()`, we ensure cleanup happens even if the test fails.

## Issue 4: Ansible Galaxy Authentication for Private Repos

### Symptom
`ansible-galaxy install` failed for private repositories because it defaulted to HTTPS, which requires interactive password auth in CI.

### Solution
1.  Updated `requirements.yml` to use SSH URLs (`git@github.com:...`).
2.  Configured SSH Aliases (`Host windows-base-repo`) in `~/.ssh/config` to map to specific Deploy Keys.
3.  Manually checked out roles in CI to ensure keys are used correctly, skipping the redundant `make deps` step in the workflow to avoid key ambiguity issues with standard GitHub URLs.

## Summary of Fixes
- **Isolation:** Use `bundle config set --local path` and `python -m venv` to isolate CI tools.
- **Wrappers:** Wrap system binaries (Vagrant) to protect them from Bundler.
- **Injection:** Dynamic config patching is more reliable than static ERB templates for paths.
- **Cleanup:** Aggressive VM cleanup ensures test reproducibility.
