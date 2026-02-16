# Active Context

## Current Session Objective
Investigate and resolve Azure authentication failures in CI, suspected to be caused by ACG sandbox permission changes. Stabilize the Vagrant fallback mechanism for integration testing.

## Current Technical Hurdle: Azure Login Failure
- **Issue**: `AADSTS130507: An access pass could not be found or verified for the user.`
- **Hypothesis**: ACG has shifted from a Service Principal (Client ID/Secret) model to a User Account model. This prevents `az login` via SP and restricts session-based access in CI runners.
- **Diagnostics**: Added `az account show` and metadata resolution steps to `ci.yml` to pinpoint where the token becomes invalid.

## Vagrant Fallback Stabilization (Verified)
- **Transport**: Reverted to **WinRM** as the standard Windows transport (reversing a temporary SSH experiment).
- **Stability Tunings**:
  - Increased `MaxEnvelopeSizekb` to 16384 on the guest VM to prevent XML parsing errors (`xml.etree.ElementTree.ParseError`).
  - Increased WinRM read/operation timeouts in `Vagrantfile` and `ansible.cfg`.
  - Added a 10-second stabilization pause in `tests/playbook.yml` after the connection check.
  - Set `ansible_become_method: runas` globally in `Vagrantfile` for Windows compatibility.
- **Resource Management**:
  - Implemented unique disk naming in `Vagrantfile` to prevent VirtualBox `VERR_ALREADY_EXISTS` collisions.
  - Added `VBoxManage closemedium` cleanup to ensure stale disks are unregistered.
  - Added a mandatory `Vagrant Cleanup` job in `ci.yml` using `make vagrant-destroy`.

## Current State Snapshot
- **Branch**: `merge-main-into-azure-dev` (Working on PR #20).
- **Status**: Azure integration is currently failing due to ACG auth issues; Vagrant fallback is robustly configured but encountering resource/OS-specific bottlenecks on the local runner.
- **Documentation**: Updated `docs/issues/` with the ACG sandbox shift findings.

## Immediate Next Actions
- Verify ACG sandbox permission changes with the user.
- Finalize documentation of the ACG shift in `docs/issues/`.
- Tag `@copilot` for code review on the transport revert and stability tunings.
- Push the latest state to `merge-main-into-azure-dev`.

## Recent Activity
1.  **Reverted SSH Experiment**: Restored WinRM as the primary transport for Windows provisioning.
2.  **Hardened WinRM**: Increased envelope size and timeouts to mitigate "no element found" errors on macOS hosts.
3.  **Unique Resource IDs**: Switched to timestamped VDI names in Vagrant to support concurrent or rapid-succession CI runs.
4.  **Consolidated Azure Logic**: Simplified the `azure_integration` job in `ci.yml` to handle both SP and Session modes more gracefully.
