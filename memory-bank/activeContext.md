# Active Context

## Current Session Objective
Stabilize the CI workflow, including resolving persistent WinRM issues blocking Vagrant tests, and investigate/address Azure authentication failures.

## Current Technical Hurdle: Azure Login Failure (Confirmed 2026-02-16)
- **Issue**: `AADSTS130507: An access pass could not be found or verified for the user.`
- **Confirmed Root Cause (Run #22049025221)**:
  1. **No SP Credentials**: `AZURE_CLIENT_ID` is empty in GitHub Secrets — ACG no longer provides Service Principal credentials.
  2. **Stale Subscription**: `AZURE_SUBSCRIPTION_ID` in GitHub Secrets belongs to a destroyed sandbox. `az account set` fails with "subscription doesn't exist in cloud 'AzureCloud'".
  3. **Session-mode false positive**: `az account show` succeeds on the self-hosted runner (cached local session), so `AZURE_AVAILABLE=true` is set. But actual management API calls fail with AADSTS130507.
  4. **ACG uses Temporary Access Pass (TAP)**: The session token has a limited TTL and cannot be renewed unattended.
- **Diagnostics**: See `docs/issues/2026-02-16-azure-sandbox-auth-failure-run-22049025221.md` for full log analysis.

## Current Technical Hurdle: Persistent WinRM 'true' Error in Vagrant Tests
- **Issue**: During Vagrant Test Kitchen 'converge' phase on Windows guest, received PowerShell error: "'The term true is not recognized as the name of a cmdlet...' at line 1, char 1".
- **Context**: Occurs after file transfer but before Ansible playbook starts.
- **Troubleshooting Steps (Unsuccessful)**:
  - Disabling `require_windows_support` in `.kitchen.yml`.
  - Disabling `setup_yml` in `.kitchen.yml`.
  - Setting `install_command: ''` in `.kitchen.yml`.
  - Forcing `ansible_winrm_shell_type: cmd` in `.kitchen.yml`.
  - Pinning `test-kitchen` to `~>3.1.0` in `Gemfile`.
  - Pinning `pywinrm` to `0.4.1` in `requirements.txt`.
- **Hypothesis**: The issue is deep-seated, likely within `kitchen-ansible`'s or `pywinrm`'s internal WinRM initial command execution, or a fundamental incompatibility with the current Ruby/gem versions.

## CI Workflow Structural Issues (2026-02-16)

### Dead / stub jobs
- **`azure_integration`** (line 297): Hard-disabled with `if: false`. Entire job (lines 291-423) is dead code.
- **`vagrant_integration`** (lines 425-446): Runs but only does `echo` + `exit 0`. Dead stub.
- **`vagrant_tests`** (line 457): Hardcoded to `refs/heads/merge-main-into-azure-dev` — becomes dead after branch merges.

### Structural debt
- **~160 lines of duplication**: Checkout + install steps repeated across all 4 active jobs. Should be a composite action.
- **Hardcoded user path**: `AZURE_CONFIG_DIR: /Users/cliang/.azure` (line 67).
- **Missing fork protection**: `vagrant_tests` job lacks the fork guard other jobs have.
- **No Azure cleanup**: No `if: always()` step to run `make test-azure-destroy` on failure.
- **Silent failure**: Dummy subscription `00000000...` fallback (line 343) should `exit 1` instead.
- **Ruby install inconsistency**: AWS uses retry pattern; other jobs don't.

### Proposed simplification
- Consolidate 5 jobs → 3: `lint`, `aws_integration`, `integration_test` (Azure attempt → Vagrant fallback → cleanup).
- See full TODO list: `docs/todos/2026-02-16-azure-sandbox-remediation.md` (TODO-9 through TODO-18).

## Vagrant Fallback Stabilization (Blocked)
- **Transport**: WinRM is standard. Tunings applied (MaxEnvelopeSizekb=16384, increased timeouts, 10s stabilization pause).
- **Execution Method**: Reverted to **direct `make vagrant-up`** for CI fallback. Test Kitchen (via `kitchen-vagrant`) encountered "unknown state" errors on the M2 runner, likely due to driver overhead or resource management bugs.
- **Verification**: Added manual `curl` check for Tomcat accessibility at port 8080.
- **Resource Management**: Unique disk naming, VBoxManage cleanup, mandatory Vagrant Cleanup job all in place.

## Current State Snapshot
- **Branch**: `merge-main-into-azure-dev` (Working on PR #20).
- **Status**: Azure integration blocked (no SP creds, stale subscription, expired TAP). Vagrant tests *blocked* by the persistent WinRM 'true' error.
- **Documentation**: Full findings in `docs/issues/2026-02-16-azure-sandbox-auth-failure-run-22049025221.md`.

## Key Architectural Finding (2026-02-16)
- **`auth_source: cli` is NOT applicable** — The Azure test path (`make test-azure-provision-tomcat`) uses raw `az` CLI commands in the Makefile for all Azure resource management (vm create, nsg rules, run-command). Ansible only talks to the VM over WinRM, never through `azure.azcollection` modules. The auth failure is entirely at the `az` CLI level.
- **Implication**: Fixes must target the `az` session/credentials, not Ansible auth settings.
- **Future option**: Migrating Makefile `az` calls to Ansible `azure.azcollection` modules would enable `auth_source: cli` but is a significant refactor.

## Immediate Next Actions
- **TODO-1**: Create new ACG sandbox and run `make sync-secrets` to refresh Azure credentials. Confirm SP vs TAP-only.
- **TODO-2**: Fix dead-code `&&` bugs in `azure_integration` (ci.yml:294) and `vagrant_integration` (ci.yml:427) job conditions.
- **TODO-3**: Harden Azure availability detection — `az group list` can pass with a stale cached session while TAP is expired.
- **TODO-4**: Investigate `windows-base` WinRM ParseError — add retries or increase envelope size.
- Push the latest state to `merge-main-into-azure-dev`.
- See full remediation plan: `docs/todos/2026-02-16-azure-sandbox-remediation.md`

## Recent Activity
1.  **Analyzed Run #22049025221** (2026-02-16): Identified 3 cascading Azure auth failures and 2 CI workflow logic bugs.
2.  **Documented findings**: Created `docs/issues/2026-02-16-azure-sandbox-auth-failure-run-22049025221.md`.
3.  **Reverted SSH Experiment**: Restored WinRM as the primary transport for Windows provisioning.
4.  **Hardened WinRM**: Increased envelope size and timeouts to mitigate "no element found" errors on macOS hosts.
5.  **Unique Resource IDs**: Switched to timestamped VDI names in Vagrant to support concurrent or rapid-succession CI runs.
6.  **Consolidated Azure Logic**: Simplified the `azure_integration` job in `ci.yml` to handle both SP and Session modes more gracefully.
7.  **Ruled out `auth_source: cli`** (2026-02-16): Confirmed Azure test path uses raw `az` CLI, not Ansible Azure modules. `auth_source: cli` is irrelevant to current architecture. Documented in todo and activeContext.
8.  **CI workflow review** (2026-02-16): Identified 2 dead jobs, 1 temp-branch-hardcoded job, ~160 lines of duplication, missing fork protection on `vagrant_tests`, no Azure resource cleanup, silent dummy subscription fallback. Proposed consolidation from 5 jobs to 3. See TODO-9 through TODO-18.
