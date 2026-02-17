# Azure Sandbox Auth Failure — Run #22049025221 (2026-02-16)

## Summary

Workflow dispatch on branch `merge-main-into-azure-dev` failed to authenticate with
the ACG Azure sandbox. The Azure integration test fell back to Vagrant, which also
failed due to persistent WinRM XML parsing errors.

**Run**: https://github.com/wilddog64/provision-tomcat/actions/runs/22049025221/job/63703266686
**Branch**: `merge-main-into-azure-dev`
**Trigger**: `workflow_dispatch` (manual)
**Outcome**: Job failed — both Azure test and Vagrant fallback failed.

---

## Root Cause Chain

### 1. No Service Principal Credentials in GitHub Secrets

The `Detect Azure Availability` step expanded `${{ secrets.AZURE_CLIENT_ID }}` to an
empty string (`if [ -n "" ]`), confirming that no Azure Service Principal (SP)
credentials are configured in the repository's GitHub Secrets.

**Impact**: The workflow cannot use `azure/login@v2` with SP-based authentication.
It falls through to the `elif az account show` branch, relying on the self-hosted
runner's local Azure CLI session (`AZURE_CONFIG_DIR: /Users/cliang/.azure`).

### 2. Stale Subscription ID in GitHub Secrets

The `Resolve Azure Metadata` step attempted to set the subscription using the
`AZURE_SUBSCRIPTION_ID` from GitHub Secrets. This subscription no longer exists:

```
ERROR: The subscription of '***' doesn't exist in cloud 'AzureCloud'.
Warning: Failed to set subscription ***
```

The stored subscription ID belongs to a previously destroyed ACG sandbox. Each new
ACG sandbox gets a fresh subscription, but the GitHub Secret was never refreshed.

### 3. AADSTS130507 — Access Pass Verification Failure

When `make test-azure-provision-tomcat` ran, the first `az` management API call
(likely `az group show` to discover the resource group location) returned:

```
ERROR: AADSTS130507: An access pass could not be found or verified for the user.
Trace ID: b83e502a-f4f5-46fd-b25d-d9b111496a00
Correlation ID: ea92fb59-893e-43ea-90b6-21abf6890a10
Timestamp: 2026-02-16 03:25:17Z
```

Azure's remediation suggestion:
```
az logout
az login --tenant "84f1e4ea-8554-43e1-8709-f0b8589ea118" --scope "https://management.core.windows.net//.default"
```

**Key insight**: The local `az account show` passes (SESSION_MODE=true), so
the workflow believes Azure is available. But the actual management API tokens are
expired or scoped incorrectly. The ACG sandbox session uses a "Temporary Access Pass"
authentication method that has a limited TTL and does not support unattended renewal.

### 4. Vagrant Fallback Also Failed (WinRM ParseError)

After the Azure test failed (`continue-on-error: true`), the Vagrant fallback
triggered. The VM booted successfully and WinRM connected, but provisioning failed
at the `windows-base` role:

```
TASK [windows-base : Ensure folders exist for service account permissions]
fatal: [default]: FAILED! => {"msg": "Unexpected failure during module execution: no element found: line 1, column 0"}

TASK [windows-base : Set ReadAndExecute permissions for service account]
fatal: [default]: FAILED! => {"msg": "Unexpected failure during module execution: no element found: line 1, column 0"}
```

**PLAY RECAP**: `ok=9 changed=1 unreachable=0 failed=1 skipped=1 rescued=0 ignored=2`

This is the same `xml.etree.ElementTree.ParseError` documented in
`2026-02-16-acg-sandbox-permission-shift.md`. Despite WinRM tuning
(MaxEnvelopeSizekb=16384, increased timeouts), certain `windows-base` tasks
that manipulate filesystem permissions still trigger truncated WinRM responses.

---

## CI Workflow Logic Bugs Found

### Bug A: Dead Code in `azure_integration` Job Condition (ci.yml:294)

```yaml
(github.event_name == 'pull_request' && github.event_name == 'workflow_dispatch' && github.head_ref == 'azure-dev')
```

`event_name` cannot be both `pull_request` AND `workflow_dispatch` simultaneously.
This sub-condition is **always false** (dead code). It means PRs targeting or
originating from `azure-dev` will never trigger the Azure integration job via this
path — only the `workflow_dispatch` and `push` paths work.

**Likely intended**:
```yaml
(github.event_name == 'pull_request' && github.head_ref == 'azure-dev')
```

### Bug B: Same Dead Code in `vagrant_integration` Job Condition (ci.yml:427)

```yaml
(github.event_name == 'pull_request' && github.event_name == 'workflow_dispatch' && (github.ref_name == 'vagrant-dev' || inputs.environment == 'vagrant'))
```

Same impossible `&&` condition. PRs from `vagrant-dev` or with `vagrant` environment
input will never match this branch.

**Likely intended**:
```yaml
(github.event_name == 'pull_request' && github.head_ref == 'vagrant-dev') ||
(github.event_name == 'workflow_dispatch' && inputs.environment == 'vagrant')
```

### Bug C: Branch Name Mismatch for Non-`azure-dev` Branches

The `azure_integration` job only runs for `workflow_dispatch` when
`github.ref_name == 'azure-dev'` or `inputs.environment == 'azure'`. The branch
`merge-main-into-azure-dev` does NOT match `azure-dev`, so the user must have
explicitly selected `environment: azure` to trigger this job. This is correct
behavior but worth noting — branches that are _not_ named exactly `azure-dev` require
explicit environment selection.

---

## Environment Details

| Parameter | Value |
|---|---|
| Runner | `m2-air` (self-hosted, macOS ARM64) |
| Runner version | 2.331.0 |
| AZURE_CONFIG_DIR | `/Users/cliang/.azure` |
| Tenant ID (from error) | `84f1e4ea-8554-43e1-8709-f0b8589ea118` |
| Auth mode | Session-based (`az account show` on runner) |
| SP credentials | Not configured (empty `AZURE_CLIENT_ID`) |
| Subscription ID | Stale (from expired sandbox) |

---

## Recommendations (No Code Changes)

1. **Refresh ACG Sandbox Session**: Create a new ACG sandbox and run
   `make sync-secrets` (or equivalent) to push fresh `AZURE_SUBSCRIPTION_ID`,
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_CLIENT_SECRET` to GitHub Secrets.
   If ACG no longer provides SP credentials, document this as a permanent constraint.

2. **Verify ACG Access Pass TTL**: The `AADSTS130507` error suggests the Temporary
   Access Pass (TAP) has expired. Investigate whether ACG sandboxes now use TAP
   exclusively and what the TTL is. If TAP is short-lived, CI must be run immediately
   after sandbox creation.

3. **Fix Dead Code in Job Conditions**: The `&&` between `pull_request` and
   `workflow_dispatch` event names in `azure_integration` (line 294) and
   `vagrant_integration` (line 427) should be corrected.

4. **Investigate WinRM ParseError in `windows-base`**: The `xml.etree.ElementTree.ParseError`
   in the Vagrant fallback is a separate issue from Azure auth. It may require
   increasing `MaxEnvelopeSizekb` further, retrying failed tasks, or examining
   the specific PowerShell operations in `windows-base` that produce oversized
   responses.

5. **Improve Azure Availability Detection**: The current `az account show` check is
   too lenient — it confirms a cached session exists but not that management API
   calls will succeed. Consider adding a lightweight management API probe (e.g.,
   `az group list --query "length(@)"`) to the detection step.

---

## Related Documents

- `docs/issues/2026-02-16-acg-sandbox-permission-shift.md` — Original ACG shift doc
- `memory-bank/activeContext.md` — Session context
- `.github/workflows/ci.yml` — Workflow definitions (lines 286-415)
