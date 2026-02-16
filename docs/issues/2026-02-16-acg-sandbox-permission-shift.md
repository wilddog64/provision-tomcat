# ACG Sandbox Permission Shift and Azure Auth Failure (2026-02-16)

## 1. Issue: Azure Login Failure in CI (AADSTS130507)

### Problem
Integration tests targeting Azure began failing with authentication errors in CI:
`ERROR: AADSTS130507: An access pass could not be found or verified for the user.`

Additionally, when creating fresh sandboxes in ACG (A Cloud Guru), Service Principal credentials (Client ID and Client Secret) were no longer being provided.

### Hypothesis
ACG has shifted its sandbox model from a **Service Principal** (automated) approach to a **User Account** (interactive) approach. This shift removes the ability to use `az login --service-principal` and restricts session tokens to interactive scopes that do not necessarily persist or validate correctly in automated CI runner environments.

### Mitigations Attempted
1.  **Session Mode**: Attempted to use the existing local `az` session on the self-hosted runner by mapping `AZURE_CONFIG_DIR`. This still failed with `AADSTS130507`, indicating the token scope or activation was insufficient for the automated task.
2.  **Diagnostics**: Added explicit `az account show` and metadata discovery steps to `ci.yml` to identify the failing scope.

## 2. Solution: Robust Vagrant Fallback

Because the Azure sandbox is currently unreliable for automated CI, the **Vagrant Fallback** was hardened to ensure testing continuity.

### Problem: WinRM Instability on macOS Host
During fallback tests on the local M2-Air runner, provisioning would frequently fail with:
`xml.etree.ElementTree.ParseError: no element found: line 1, column 0`

This was caused by truncated WinRM responses or communication timeouts when the host (macOS) struggled to parse large XML chunks from the guest (Windows).

### Solution: WinRM Hardening and Resource Isolation
1.  **WinRM Tuning**: Increased `MaxEnvelopeSizekb` to `16384` on the guest VM to allow larger XML responses.
2.  **Increased Timeouts**: Raised WinRM read and operation timeouts to `600s` / `540s` across `Vagrantfile`, `ansible.cfg`, and `ci.yml`.
3.  **Stabilization Pause**: Added a `10s` stabilization pause in the playbook after the connection check to ensure the WinRM service is fully ready.
4.  **Resource Isolation**:
    - Switched to timestamped VDI names (`data_disk_#{Time.now.to_i}.vdi`) to prevent `VERR_ALREADY_EXISTS` collisions.
    - Added mandatory `VBoxManage closemedium` cleanup steps.
5.  **Standardized Transport**: Reverted an experimental switch to SSH, standardizing on **WinRM** but with the above stability tunings applied.

## Related Documents
- `memory-bank/activeContext.md`
- `Vagrantfile`
- `ansible.cfg`
- `.github/workflows/ci.yml`
- `tests/playbook.yml`
