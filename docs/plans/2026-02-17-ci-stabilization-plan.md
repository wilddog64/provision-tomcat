# Plan: CI Stabilization, Azure, and Vagrant WinRM Issue Resolution

**Overall Goal:** Establish a robust CI workflow for Ansible Tomcat provisioning on Windows by:
1.  Unblocking and, if feasible, reviving Azure integration.
2.  Resolving the persistent "true" error currently blocking Vagrant Test Kitchen runs.
3.  Improving the overall structure, efficiency, and security of the CI workflow.

**Supersedes:** `docs/plans/2026-02-16-stabilize-vagrant-tests.md` (that plan's Step 1 — creating the `vagrant_tests` job — is already implemented in `ci.yml`).

---

**Phase 1: Immediate CI Unblocking & Azure Re-evaluation**

**Objective:** Unblock current CI failures and gather necessary information to proceed with Azure integration.

*   **Step 1.1: User Action: Refresh ACG Sandbox Credentials (TODO-1).**
    *   **Reasoning:** The Azure integration is blocked by expired/unavailable credentials due to ACG's shift to a TAP-only model. Fresh credentials are prerequisite for any further Azure debugging.
    *   **Proposed Action:** Create a new ACG sandbox and run `make sync-secrets` to push fresh `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, and credentials to GitHub Secrets. Confirm whether ACG still offers SP credentials or TAP-only.
*   **Step 1.2: Harden Azure Availability Detection (TODO-3).**
    *   **Reasoning:** The current `az group list` check for Azure availability can give a false positive with stale cached sessions, leading to misleading CI behavior.
    *   **Proposed Action:** Modify `ci.yml` within the `azure_integration` job (once re-enabled) to replace or supplement the `az group list` check with a more robust management API probe that fails fast if the TAP is expired or invalid, possibly by targeting a specific subscription with a shorter timeout.

*   ~~**Step 1.1 (original): Fix dead-code `&&` in CI job conditions (TODO-2).**~~
    **RESOLVED (2026-02-16):** Review of current `ci.yml` confirmed:
    - `azure_integration` (line 297): `if: false` — the original `&&` condition is never evaluated (dead code).
    - `vagrant_integration` (line 436): condition was already rewritten to use `||` correctly.
    TODO-2 is no longer applicable to the current file state.

*   ~~**Step 1.2 (original): Temporarily Disable `vagrant_tests` job.**~~
    **DROPPED:** Adding another `if: false` job increases dead code. The job already only runs on `merge-main-into-azure-dev`. The correct approach is to fix the underlying "true" error (Phase 2), not suppress it.

---

**Phase 2: Resolving the Persistent WinRM "true" Error in Vagrant Tests**

**Objective:** Diagnose and fix the "The term 'true' is not recognized" error that is blocking `kitchen test default-win11`.

**Root Cause Analysis:**

The error `"The term 'true' is not recognized as the name of a cmdlet"` occurs because `kitchen-ansible` (or `kitchen-ansiblepush`) sends the POSIX shell no-op command `true` over WinRM to PowerShell as a readiness/health check. PowerShell does not have a `true` command — the equivalent is `$true` (a boolean literal, not a command) or `cmd /c exit 0`.

This is NOT a WinRM transport issue (MaxEnvelopeSizekb, timeouts, etc.) — it's a **shell mismatch** at the provisioner level. The provisioner assumes a Unix-like shell but the target is PowerShell.

**Debugging leftovers still in the codebase:**
- `.kitchen.yml:20`: `install_command: ''` (debugging attempt, still present)
- `.kitchen.yml:31`: `ansible_winrm_shell_type: cmd` (debugging attempt, still present)
- `Gemfile:5`: `test-kitchen` pinned to `~> 3.1.0` (debugging pin, still present)
- `requirements.txt:1`: `pywinrm==0.4.1` (debugging pin, still present)

*   **Step 2.1: Revert Debugging Changes.**
    *   **Proposed Action:** Revert the 4 debugging changes listed above to restore a clean baseline:
        - `.kitchen.yml`: Remove `install_command: ''` and `ansible_winrm_shell_type: cmd`
        - `Gemfile`: Unpin `test-kitchen` (remove version constraint or use `>= 3.0`)
        - `requirements.txt`: Unpin `pywinrm` (remove `==0.4.1`)
    *   Run `bundle install` and `pip install -r requirements.txt` to reset dependencies.

*   **Step 2.2: Investigate the provisioner's shell command.**
    *   **Proposed Action:**
        - Inspect `kitchen-ansible` / `kitchen-ansiblepush` gem source code for the specific method that sends the initial readiness command. Look for bare `true`, `test`, or similar Unix-isms sent before playbook execution.
        - Check if the provisioner has a config option to override the readiness command or specify a Windows-compatible alternative.
        - Review `.kitchen/logs/default-win11.log` from a local failed run to confirm the exact command being sent.

*   **Step 2.3: Apply targeted fix.**
    *   **Likely fixes (in order of preference):**
        1. **Provisioner config**: If `kitchen-ansiblepush` has a `ready_command` or similar option, set it to `cmd /c exit 0` or `powershell -Command "exit 0"`.
        2. **Shell type config**: Ensure the provisioner is told the target is `cmd` or `powershell`, not `sh`/`bash`. The `ansible_winrm_shell_type: cmd` extra_var tells Ansible but may not affect the provisioner's own pre-playbook commands.
        3. **Patch/fork the gem**: If no config option exists, a targeted monkey-patch or fork of the provisioner gem may be needed to replace the `true` command.
        4. **Switch provisioner**: If `kitchen-ansiblepush` is unmaintained, consider switching to `kitchen-ansible` (pull mode) which may handle Windows differently.

*   **Step 2.4: Validate fix.**
    *   Run `bundle exec kitchen converge default-win11` locally to confirm the "true" error is resolved.
    *   Run full `make test-win11` and `make test-upgrade-win11` to confirm end-to-end pass.

---

**Phase 3: Broader CI Workflow Improvements (TODO-9 through TODO-18)**

**Objective:** Enhance CI robustness, maintainability, and security. (Prioritized after Phase 1 and 2 blockers are addressed).

*   **Cleanup Dead/Stub Jobs:** Remove or revive `azure_integration` (TODO-9), `vagrant_integration` (TODO-10), and generalize `vagrant_tests` (TODO-11).
*   **DRY Principle:** Extract shared setup into a composite action to reduce duplication (TODO-12).
*   **Security & Correctness:**
    *   Replace hardcoded `AZURE_CONFIG_DIR` (TODO-13).
    *   Add fork protection to `vagrant_tests` job (TODO-14).
    *   Add Azure resource cleanup step (TODO-15).
    *   Implement fail-fast on dummy subscription fallback (TODO-16).
    *   Standardize Ruby install across jobs (TODO-17).
*   **Consolidation:** Consolidate to 3 jobs (`lint`, `aws_integration`, `integration_test`) (TODO-18).

See full TODO details: `docs/todos/2026-02-16-azure-sandbox-remediation.md`
