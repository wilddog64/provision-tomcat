# Plan: CI Stabilization, Azure, and Vagrant WinRM Issue Resolution

**Overall Goal:** Establish a robust CI workflow for Ansible Tomcat provisioning on Windows by:
1.  Unblocking and, if feasible, reviving Azure integration.
2.  Resolving the persistent "true" error currently blocking Vagrant Test Kitchen runs.
3.  Improving the overall structure, efficiency, and security of the CI workflow.

---

**Phase 1: Immediate CI Unblocking & Azure Re-evaluation**

**Objective:** Unblock current CI failures and gather necessary information to proceed with Azure integration.

*   **Step 1.1: Address Claude's TODO-2: Fix dead-code `&&` in CI job conditions.**
    *   **Reasoning:** Claude identified a logical error (`&&` used instead of `||` or split conditions) in the `if:` clauses of the `azure_integration` and `vagrant_integration` jobs (lines 294 and 427 in `ci.yml`). This prevents them from executing correctly even when intended. Fixing this is a fundamental structural correction.
    *   **Proposed Action:** Modify `ci.yml` to ensure these conditions accurately reflect the desired job triggering logic. This might involve replacing `&&` with `||` or breaking complex conditions into simpler ones.
*   **Step 1.2: Temporarily Disable `vagrant_tests` job.**
    *   **Reasoning:** The persistent "true" error is a complete blocker for this job, leading to repeated CI failures. Temporarily disabling it will unblock the overall CI pipeline, allowing other jobs (like `lint`) to pass cleanly while we investigate the root cause of the "true" error without constant re-running of a failing job.
    *   **Proposed Action:** Modify `ci.yml` to set the `if:` condition of the `vagrant_tests` job to `if: false`.
*   **Step 1.3: User Action: Refresh ACG Sandbox Credentials (Claude's TODO-1).**
    *   **Reasoning:** Claude's analysis confirmed the Azure integration is blocked by expired/unavailable credentials due to ACG's shift to a TAP-only model. Fresh credentials are prerequisite for any further Azure debugging.
    *   **Proposed Action:** I will instruct you on how to perform the `make sync-secrets` command after refreshing the ACG sandbox, or if ACG no longer offers SP credentials, how to proceed with a TAP.
*   **Step 1.4: Harden Azure Availability Detection (Claude's TODO-3).**
    *   **Reasoning:** The current `az group list` check for Azure availability can give a false positive with stale cached sessions, leading to misleading CI behavior.
    *   **Proposed Action:** Modify `ci.yml` within the `azure_integration` job (once re-enabled) to replace or supplement the `az group list` check with a more robust management API probe that fails fast if the TAP is expired or invalid, possibly by targeting a specific subscription with a shorter timeout.

---

**Phase 2: Resolving the Persistent WinRM "true" Error in Vagrant Tests**

**Objective:** Diagnose and fix the "The term 'true' is not recognized" error that is blocking `kitchen test default-win11`.

*   **Step 2.1: Revert Debugging Changes for WinRM Issue.**
    *   **Reasoning:** Previous attempts to fix the "true" error by changing `install_command`, `ansible_winrm_shell_type`, and pinning `test-kitchen`/`pywinrm` versions were unsuccessful. To maintain a clean state and avoid introducing new variables, these debugging changes should be reverted before a deeper investigation.
    *   **Proposed Action:** Revert modifications to `Gemfile` (unpin `test-kitchen`), `requirements.txt` (unpin `pywinrm`), and `.kitchen.yml` (remove `install_command` and `ansible_winrm_shell_type: cmd`). Run `bundle install` and `pip install` to ensure dependencies are reset.
*   **Step 2.2: Detailed Log Analysis.**
    *   **Reasoning:** The error occurs at a very low level, deep within the WinRM communication stack. The `.kitchen/logs/default-win11.log` and `kitchen.log` files are critical to pinpointing the exact command or script that is failing.
    *   **Proposed Action:** I will request that you provide the content of these log files from a local failed `kitchen test default-win11` run. This is crucial for pinpointing the exact command causing the error.
*   **Step 2.3: Investigate `kitchen-ansible` / `pywinrm` Interaction (Claude's TODO-4, adapted).**
    *   **Reasoning:** The persistent "true" error, despite extensive configuration changes, indicates a fundamental issue with how `kitchen-ansible` or its underlying `pywinrm` library initiates command execution on the Windows guest via WinRM. Claude's TODO-4 mentions "WinRM ParseError," which aligns with general WinRM communication issues.
    *   **Proposed Action:**
        *   **Increase `MaxEnvelopeSizekb`:** If logs suggest truncation, increasing `MaxEnvelopeSizekb` further (e.g., to 32768) might help if the error is a symptom of incomplete data.
        *   **Source Code Review:** If logs are inconclusive, I will need to inspect the source code of the `kitchen-ansible` gem to understand its internal WinRM client setup for Windows hosts, specifically looking for any hardcoded initial commands or scripts that might be sending a bare `true` to the shell. This may require setting up a local Ruby debugging environment.
        *   **Targeted `pywinrm` Debugging:** Explore `pywinrm`'s documentation or known issues for similar "command not recognized" errors during initial connection.

---

**Phase 3: Broader CI Workflow Improvements (Claude's Remaining TODOs)**

**Objective:** Enhance CI robustness, maintainability, and security. (These will be prioritized and tackled after Phase 1 and 2 blockers are addressed).

*   **Cleanup Dead/Stub Jobs:** Remove or revive `azure_integration` (TODO-9), `vagrant_integration` (TODO-10), and generalize `vagrant_tests` (TODO-11).
*   **DRY Principle:** Extract shared setup into a composite action to reduce duplication (TODO-12).
*   **Security & Correctness:**
    *   Replace hardcoded `AZURE_CONFIG_DIR` (TODO-13).
    *   Add fork protection to `vagrant_tests` job (TODO-14).
    *   Add Azure resource cleanup step (TODO-15).
    *   Implement fail-fast on dummy subscription fallback (TODO-16).
    *   Standardize Ruby install across jobs (TODO-17).
*   **Consolidation:** Consolidate to 3 jobs (`lint`, `aws_integration`, `integration_test`) (TODO-18).
