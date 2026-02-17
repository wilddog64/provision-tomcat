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

## Infrastructure Constraints
- **Copilot Firewall**: The agent is blocked by several Azure-related domains (`management.azure.com`, `login.microsoftonline.com`).
- **ACG TAP Auth**: Temporary Access Pass (TAP) has limited TTL and doesn't support unattended renewal. Azure CI is currently deferred until the credential model stabilizes.
