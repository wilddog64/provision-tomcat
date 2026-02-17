# To-Do: Remediate ACG Azure Sandbox Access Issues

**Date Identified:** 2026-02-16

**Problem:**
The Azure integration tests are currently disabled due to authentication failures when attempting to interact with the ACG (Azure Cloud Governance) sandbox environment.

*   **Error Code:** `AADSTS130507`
*   **Root Cause:** An ACG platform shift to a TAP (Temporary Access Pass)/User Account model has been implemented. This change fundamentally blocks the creation of Service Principals (SPs) for automated authentication in the traditional manner, resulting in "Insufficient privileges" errors.
*   **Impact:** Automated Azure integration tests using Service Principals are currently infeasible, leading to the temporary disabling of the `azure_integration` CI job to unblock overall CI progress.

**Current Status:**
*   `azure_integration` job in `.github/workflows/ci.yml` is set to `if: false`.
*   Focus has shifted to stabilizing Vagrant-based Test Kitchen tests.

**Key Technical Finding (2026-02-16 analysis):**

The Azure test path (`make test-azure-provision-tomcat`) does **not** use Ansible Azure modules (`azure.azcollection`). All Azure resource management is done via raw `az` CLI commands in the Makefile (vm create, nsg rule create, vm run-command invoke, vm show). Ansible only connects to the provisioned VM over WinRM. Therefore, Ansible-level fixes like `auth_source: cli` are **irrelevant** — the auth problem is entirely at the `az` CLI session level.

**Auth failure chain:**
1. `ci.yml:306` — `AZURE_CLIENT_ID` is empty (no SP creds) → SP login skipped
2. `ci.yml:310` — `az group list` passes (stale cached session) → `AZURE_AVAILABLE=true`
3. `Makefile:386` — `az group show --name "$RG"` → `AADSTS130507` (TAP expired)

---

**Remediation Plan (ranked by priority):**

### Immediate (unblock CI now)
- [ ] **TODO-1: Refresh ACG sandbox + sync secrets** — Create new ACG sandbox, run `make sync-secrets` to push fresh `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID`, and credentials to GitHub Secrets. Confirm whether ACG still offers SP credentials or TAP-only.
- [ ] **TODO-2: Fix dead-code `&&` in CI job conditions** — `ci.yml:294` (`azure_integration`) and `ci.yml:427` (`vagrant_integration`) have impossible `event_name == 'pull_request' && event_name == 'workflow_dispatch'`. Change to `||` or split into separate sub-conditions.
- [ ] **TODO-3: Harden Azure availability detection** — Replace or supplement the `az group list` check with a lightweight management API probe that fails fast when TAP is expired (e.g., add `--subscription` targeting or a tighter timeout).

### Short-term (resilience)
- [ ] **TODO-4: Strengthen Vagrant fallback** — WinRM `ParseError` in `windows-base` blocks the fallback path. Options: add `retries: 3` / `delay: 10` to failing tasks, increase `MaxEnvelopeSizekb` further (32768), or investigate the specific PowerShell operations that produce oversized responses.
- [ ] **TODO-5: Document TAP TTL constraints** — If ACG is TAP-only, document the window between sandbox creation and CI trigger. Consider adding a `workflow_dispatch` input for manual token pass-through.

### Future (strategic)
- [ ] **TODO-6: Migrate Makefile `az` CLI calls to Ansible `azure.azcollection` modules** — This would allow `auth_source: cli` to work, centralizing all Azure auth into Ansible and eliminating the split between `az` CLI (Makefile) and Ansible (WinRM). Significant refactor but aligns with IaC principles.
- [ ] **TODO-7: Explore Workload Identity Federation** — If the self-hosted runner can use GitHub's OIDC provider to authenticate to Azure without secrets, this bypasses the SP/TAP problem entirely. Requires ACG platform support.
- [ ] **TODO-8: Evaluate `kitchen-azure` replacement** — The current `kitchen-azure` gem (0.1.0) is ancient. If Azure testing is revived, evaluate modern alternatives or direct Makefile-based provisioning (which is already the de facto approach).

**Priority:** TODO-1 through TODO-3 are blockers. TODO-4 is needed for CI resilience. TODO-5 through TODO-8 are strategic.

---

## CI Workflow Cleanup (identified 2026-02-16)

Full review of `.github/workflows/ci.yml` (515 lines, 5 jobs) revealed structural debt beyond the Azure auth issue.

### Dead / stub jobs to resolve
- [ ] **TODO-9: Remove or revive `azure_integration` job** — Hard-disabled with `if: false` (line 297). The entire job (lines 291-423) is dead code including detection logic, login, Vagrant fallback, and cleanup. Either delete it or re-enable with the fixes from TODO-1/2/3.
- [ ] **TODO-10: Remove or revive `vagrant_integration` job** — The job (lines 425-446) evaluates its condition but only runs `echo` + `exit 0`. Another dead stub.
- [ ] **TODO-11: Generalize `vagrant_tests` job** — Currently hardcoded to `refs/heads/merge-main-into-azure-dev` (line 457). This is a temporary branch — once merged, the job becomes dead. Should be generalized to trigger on `azure-dev`, `vagrant-dev`, or as a fallback when cloud tests are unavailable.

### Structural improvements
- [ ] **TODO-12: Extract shared setup into composite action** — Checkout (provision-tomcat + 3 dependent roles), venv creation, pip install, Ruby deps, `make deps` are duplicated across all 4 active jobs (~40 lines x 4 = ~160 lines of duplication). Extract into `.github/actions/setup/action.yml`.
- [ ] **TODO-13: Replace hardcoded `AZURE_CONFIG_DIR`** — Line 67: `AZURE_CONFIG_DIR: /Users/cliang/.azure` is tied to a specific user. Use `$HOME/.azure` or resolve dynamically in the step that needs it.
- [ ] **TODO-14: Add fork protection to `vagrant_tests` job** — `lint`, `aws_integration`, and `vagrant_integration` all guard against fork PRs (`github.event.pull_request.head.repo.full_name == github.repository`). `vagrant_tests` (line 454) lacks this guard — a fork PR could access deploy keys.
- [ ] **TODO-15: Add Azure resource cleanup step** — The `azure_integration` job has `Vagrant Cleanup` but no `Azure Cleanup` with `if: always()`. If `make test-azure-provision-tomcat` creates a VM and fails, Azure resources (VM, NIC, public IP, NSG) are leaked. Add `make test-azure-destroy` as a mandatory cleanup step (like AWS's `Mandatory Cleanup`).
- [ ] **TODO-16: Fail fast on dummy subscription fallback** — Line 343 falls back to `00000000-0000-0000-0000-000000000000` and continues, causing cryptic downstream errors. Should `exit 1` with a clear message instead.
- [ ] **TODO-17: Standardize Ruby install across jobs** — AWS job (line 264) uses `bundle install || gem install bundler && bundle install` (retry). All other jobs just do `bundle install`. Standardize (ideally via the composite action from TODO-12).

### Proposed job consolidation (future)
- [ ] **TODO-18: Consolidate to 3 jobs** — Current 5 jobs (`lint`, `aws_integration`, `azure_integration`, `vagrant_integration`, `vagrant_tests`) can be reduced to 3: `lint`, `aws_integration`, and `integration_test` (single job with cloud detection → Azure attempt → Vagrant fallback → cleanup for both). This eliminates the dead jobs and the duplicate Vagrant logic.

**Priority:** TODO-9/10/11 are cleanup (remove dead code). TODO-12 is high-value DRY improvement. TODO-14 is a security gap. TODO-15/16 are correctness. TODO-13/17/18 are quality-of-life.
