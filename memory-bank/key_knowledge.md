# Key Knowledge

## Branch Recovery & Hygiene (2026-02-17)

### Post-Mortem Findings: `azure-dev` Failure
The `azure-dev` branch accumulated significant technical debt that led to a cascading failure:
1. **Shotgun Debugging**: Rapid-fire commits of individual debug attempts without reverting failed ones left residue and corrupted the branch.
2. **Ruby 4.0 Dependency Spiral**: The M2 runner's Ruby 4.0 triggered a chain of incompatible gem updates (`thor`, `benchmark`, `kitchen-azure`), causing CI failures that were misdiagnosed.
3. **AWS Logic Pollution**: Merging `main` into `azure-dev` introduced AWS-specific CI jobs and redundancies, complicating the pipeline.
4. **ACG Platform Shift**: The move from Service Principal to TAP-only auth invalidated the existing Azure CI approach.

### Key Lesson Learned
**Debug locally, commit once, push verified.** Automated CI should not be used for trial-and-error debugging.

## Technical Stabilizations

### WinRM 'true' Error - Root Cause
The error `"The term 'true' is not recognized as the name of a cmdlet"` is a **shell mismatch**, not a transport issue.
- **Problem**: `kitchen-ansiblepush` sends the POSIX `true` command as a readiness check to a PowerShell target.
- **Fix**: Override the readiness command in `.kitchen.yml` with `cmd /c exit 0`.

### Ruby Environment Management
- **M2 Runner Constraint**: Ruby 4.0.0 defaults can cause cascading dependency issues with `test-kitchen`.
- **Solution**: Pin CI jobs to Ruby 3.3.x using `rbenv` or the `setup-ruby` action.

### Vagrant & VirtualBox Resilience
- **VDI Management**: Unique disk naming (`data_disk_#{timestamp}.vdi`) and `VBoxManage closemedium` are essential to prevent `VERR_ALREADY_EXISTS` collisions on self-hosted runners.
- **Resource Contention**: Parallel Vagrant runs on the same runner can lead to WinRM `ParseError` (XML truncation). Linearized CI jobs are required for stability.

## Tomcat Version Lifecycle (Apache CDN)

Apache's CDN (`dlcdn.apache.org`) only hosts the **current** patch release per minor line.
Older patch versions (e.g. 9.0.113) are removed when superseded. Any hardcoded version
string in test playbooks (`playbook-upgrade.yml`) must be kept in sync with the latest
available release; stale versions produce 404 errors.

**Current known-good versions (2026-02-17):**
- Step 1 (baseline): `9.0.112` (pre-baked in `windows11-tomcat112` Vagrant box)
- Step 2 (upgrade target): `9.0.115` (checksum in `defaults/main.yml` ✓)

## install_drive Precedence Trap

`tests/playbook-upgrade.yml` declares `install_drive: "C:"` in its `vars:` block.
Ansible playbook vars outrank role `defaults/`, so this silently overrides
`defaults/main.yml`'s `install_drive: "D:"`. Any suite that needs D: must pass
`install_drive: "D:"` as an `extra_var` in `.kitchen.yml` to override the playbook var.

Platforms without an attached second disk (`win11`, `win11-baseline`) cannot use D:
unless the box was built with a D: partition pre-configured.

## Operational Reference Values

### WinRM Transport Tuning (Hard-Won)
These values are required to prevent `ParseError` (XML truncation) triggered by the `windows-base` role:
- `MaxEnvelopeSizekb: 16384`
- `ansible_winrm_read_timeout_sec: 600`
- `pipelining: False`
- `MaxMemoryPerShellMB: 2048`
- `MaxConcurrentOperationsPerUser: 100`

### Kitchen ENV Hardening
`.kitchen.yml` must use `ENV[...]` or `ENV.fetch` with defaults to avoid `KeyError` when cloud secrets are missing during local runs.

### Runner Name Discrepancy
GitHub API refers to the self-hosted runner as `m2-air` (id: 21), despite the physical machine reporting as `m4-air.local`. This affects any runner-targeting logic or debugging.

## Infrastructure Constraints
- **Copilot Firewall**: The agent is blocked by several Azure-related domains (`management.azure.com`, `login.microsoftonline.com`).
- **ACG TAP Auth**: Temporary Access Pass (TAP) has limited TTL and doesn't support unattended renewal. Azure CI is currently deferred until the credential model stabilizes.
