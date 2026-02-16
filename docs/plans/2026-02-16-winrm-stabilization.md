# WinRM Stabilization Plan (2026-02-16)

## 1. Problem Statement
The Vagrant fallback for Windows integration tests is failing during the execution of the `windows-base` role with the following error:
`xml.etree.ElementTree.ParseError: no element found: line 1, column 0`

This occurs during tasks that involve significant file system metadata operations (`win_file`, `win_acl`). The error indicates that the WinRM service on the guest is likely crashing or returning an empty response because it has exceeded a resource quota.

## 2. Technical Root Cause Analysis
Default Windows WinRM configurations often have restrictive quotas:
- **MaxMemoryPerShellMB**: Default is usually 512MB. Complex Ansible modules can easily exceed this when calculating ACLs or traversing directories.
- **MaxEnvelopeSizekb**: Even at 16384 (our current setting), extremely large metadata responses can still be truncated if not paired with sufficient shell memory.
- **MaxConcurrentOperationsPerUser**: Can lead to race conditions or dropped connections if hit during rapid task execution.

## 3. Proposed Fixes

### Phase 1: Guest-Side Quota Hardening
Update the `Vagrantfile` to apply the following PowerShell tuning:
- Increase `MaxMemoryPerShellMB` from 512 to **2048**.
- Increase `MaxConcurrentOperationsPerUser` to **100**.
- Maintain `MaxEnvelopeSizekb` at **16384**.

### Phase 2: Ansible Configuration Refinement
- Ensure `pipelining = False` is strictly enforced for WinRM (already implemented).
- Verify `ansible_winrm_operation_timeout_sec` remains high (540s).

### Phase 3: Playbook Level Retries
- If quota hardening fails, implement `until` loops with `retries` on the specific tasks in `windows-base` that are known to be unstable.

## 4. Expected Outcome
By providing the WinRM shell with 2GB of dedicated memory, the modules should be able to process large XML responses without service interruption, eliminating the `ParseError`.
