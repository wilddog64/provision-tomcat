# Security Audit Report: provision-tomcat

**Date:** 2026-02-14
**Auditor:** Red Team Review (Claude Code)
**Scope:** Full codebase - Ansible role, CI/CD, test infrastructure, lookup plugins, dependent roles
**Branch:** aws-dev

---

## Executive Summary

The `provision-tomcat` project demonstrates **good security awareness** overall: secrets are externalized, documentation covers secret injection patterns, and the CI security doc shows defensive thinking. However, the audit identified **5 HIGH**, **6 MEDIUM**, and **4 LOW** severity findings that should be addressed.

---

## Findings

### [HIGH-1] No Download Integrity Verification (Supply Chain Risk)

**Location:** `tasks/install-Windows-tomcat.yml:127-130`, `defaults/main.yml:10-11`

**Issue:** Tomcat is downloaded from `https://dlcdn.apache.org/...` via `win_get_url` with **no checksum validation**. If the Apache CDN mirror is compromised, a MITM intercepts the download, or an attacker gains control of a mirror, a trojanized Tomcat binary would be silently installed.

**Evidence:**
```yaml
- name: Download Tomcat zip
  ansible.windows.win_get_url:
    url: "{{ tomcat_download_url }}"
    dest: "{{ tomcat_temp_dir }}/apache-tomcat-{{ tomcat_version }}.zip"
  # No checksum or checksum_url parameter
```

**Recommendation:** Add `checksum` or `checksum_url` parameter to `win_get_url`. Apache publishes SHA-512 hashes at `https://downloads.apache.org/tomcat/tomcat-9/v{version}/bin/apache-tomcat-{version}-windows-x64.zip.sha512`. Example:
```yaml
checksum: "sha512:{{ tomcat_checksum }}"
# Or use checksum_url pointing to Apache's .sha512 file
```

**Severity:** HIGH - Supply chain compromise vector

---

### [HIGH-2] AWS Security Group Opened to 0.0.0.0/0

**Location:** `.github/workflows/ci.yml:179-183`

**Issue:** The CI workflow opens WinRM (5985) and Tomcat (8080, 9080) ports to **all internet traffic** (`0.0.0.0/0`) in the security group. WinRM over HTTP with NTLM on a public IP is particularly dangerous -- credential relay attacks are trivial.

**Evidence:**
```bash
aws ec2 authorize-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID \
  --protocol tcp --port 5985 --cidr 0.0.0.0/0 || true
aws ec2 authorize-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID \
  --protocol tcp --port 8080 --cidr 0.0.0.0/0 || true
aws ec2 authorize-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID \
  --protocol tcp --port 9080 --cidr 0.0.0.0/0 || true
```

**Recommendation:**
- Restrict CIDR to the runner's public IP: `$(curl -s https://checkip.amazonaws.com)/32`
- Revoke the ingress rules in the cleanup step (`if: always()`)
- Ideally use a VPC endpoint or SSM Session Manager instead of public WinRM

**Severity:** HIGH - Exposes WinRM to the internet during CI runs

---

### [HIGH-3] Missing CI Fork Protection

**Location:** `.github/workflows/ci.yml` (entire workflow)

**Issue:** The `CI-SECURITY.md` documents fork protection (`github.event.pull_request.head.repo.full_name == github.repository`), but the **actual `ci.yml` workflow does NOT implement this check**. The workflow triggers on `pull_request` events to protected branches without filtering out fork PRs. A malicious fork PR could execute arbitrary code on the self-hosted runner.

**Evidence:** The `ci.yml` has no fork protection condition. The documented condition from `CI-SECURITY.md`:
```yaml
if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
```
...is absent from the actual workflow.

**Recommendation:** Add fork protection to all jobs in `ci.yml`, especially those running on `self-hosted` runners. At minimum, add to the `lint` job (which all others depend on):
```yaml
if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
```

**Severity:** HIGH - Self-hosted runner RCE via fork PR

---

### [HIGH-4] WinRM Plaintext Transport (No Encryption)

**Location:** `.kitchen.yml:50,97-98`, `Vagrantfile:23-24`, `ansible.cfg:17`

**Issue:** All WinRM connections use **plaintext HTTP** (`basic` auth over port 5985, no SSL):
- `ansible_winrm_transport: basic`
- `ansible_winrm_scheme: http`
- `ssl: false`
- `winrm_transport: :plaintext`

Credentials (`vagrant/vagrant` for test, `Administrator` for AWS) are sent in cleartext. While acceptable for local Vagrant VMs, the **AWS instances use this same pattern over the public internet**.

**Evidence (AWS platform in .kitchen.yml):**
```yaml
ansible_winrm_transport: ntlm
ansible_winrm_scheme: http
ansible_winrm_server_cert_validation: ignore
ansible_port: 5985
```

**Recommendation:**
- For AWS: Use HTTPS (port 5986) with `ansible_winrm_scheme: https`
- Configure WinRM HTTPS listener with a self-signed cert on the AMI
- If not feasible, use SSM Session Manager tunneling instead
- Keep plaintext only for local Vagrant (isolated loopback)

**Severity:** HIGH - Credential exposure over public internet

---

### [HIGH-5] No `no_log` on Sensitive Operations

**Location:** `tasks/install-Windows-tomcat.yml` (entire file), `tests/playbook.yml:48-58`

**Issue:** Zero uses of `no_log: true` anywhere in the codebase. Operations that handle `tomcat_service_account_password` will log the password value in plaintext in Ansible output, CI logs, and any log aggregator.

The test playbook also creates accounts with hardcoded passwords (`Password123!`) without `no_log`, which is less critical but demonstrates the pattern gap.

**Evidence:**
```bash
$ grep -r no_log tasks/ defaults/ tests/ # returns empty
```

**Recommendation:** Add `no_log: true` to any task that references `tomcat_service_account_password` or creates user accounts with passwords. At minimum:
- Service install tasks that pass credentials
- User creation tasks in test playbooks
- Any future tasks that handle secrets

**Severity:** HIGH - Password exposure in logs

---

### [MED-1] CredSSP Wildcard Delegation

**Location:** `.ansible/roles/windows-base/defaults/main.yml:107`, `.ansible/roles/windows-base/tasks/credssp.yml:11-14`

**Issue:** CredSSP client delegation is configured with `credssp_delegate_computers: "*"`, which means the Windows host will delegate credentials to **any server** requesting them. This is a credential relay/theft vector -- if an attacker controls any host the target connects to, they receive the delegated credentials.

**Evidence:**
```yaml
credssp_delegate_computers: "*"
```
```powershell
Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
```

**Recommendation:** Restrict to specific hostnames, IPs, or domain patterns (e.g., `*.internal.domain`). Never use `*` in production.

**Severity:** MEDIUM - Credential delegation to arbitrary hosts

---

### [MED-2] Hardcoded Test Credentials in Repository

**Location:** `tests/playbook.yml:50`, `tests/playbook-upgrade.yml:33`, `.kitchen.yml:79,126,172,421`

**Issue:** Multiple hardcoded credentials:
- `Password123!` for test service accounts (svcTomcat, svclabbuild, svcjenkins)
- `vagrant/vagrant` for WinRM connections
- These are committed to the repository

While these are test-only credentials, they establish weak-password patterns and could be reused. The `Password123!` password is a well-known default that appears in credential spray dictionaries.

**Recommendation:**
- Consider generating random passwords for test accounts
- Document explicitly that these are test-only and must never be used in production
- For Vagrant `vagrant/vagrant` -- this is standard Vagrant convention and acceptable for local dev

**Severity:** MEDIUM - Weak test credentials

---

### [MED-3] GH_PAT Fallback Pattern

**Location:** `.github/workflows/ci.yml:74,197,280`

**Issue:** The provision-java checkout uses a fallback pattern: `token: ${{ secrets.GH_PAT || github.token }}`. If `GH_PAT` is a broadly-scoped Personal Access Token, it grants more access than needed. The fallback to `github.token` is good, but the PAT itself may have excessive scope.

**Evidence:**
```yaml
token: ${{ secrets.GH_PAT || github.token }}
```

**Recommendation:**
- Audit the scope of `GH_PAT` -- it should be limited to `repo` read access for `wilddog64/provision-java` only
- Consider using SSH deploy keys for all private repos (consistent with how `windows-base` and `provision-windows-security` are handled)
- Fine-grained tokens are preferred over classic PATs

**Severity:** MEDIUM - Potential excessive token scope

---

### [MED-4] Tomcat Shutdown Port Exposed

**Location:** `defaults/main.yml:16`, `tasks/install-Windows-tomcat.yml:199-204`

**Issue:** The Tomcat shutdown port (`8005` primary, `9005` candidate) listens on the default configuration, which typically binds to all interfaces. An attacker with network access can send the shutdown command string to port 8005 and stop Tomcat.

**Recommendation:**
- Configure `server.xml` to bind the shutdown port to `127.0.0.1` only (Tomcat `<Server address="127.0.0.1">`)
- Or change the default `SHUTDOWN` command string to a random value
- Add a firewall rule to block external access to 8005/9005

**Severity:** MEDIUM - Remote service disruption

---

### [MED-5] Tomcat Running as LocalSystem by Default

**Location:** `defaults/main.yml:37-38`

**Issue:** The default service account is `LocalSystem`, which is the highest-privilege Windows account. If Tomcat is compromised (e.g., via a deployed webapp RCE), the attacker has full SYSTEM-level access to the Windows host.

**Evidence:**
```yaml
tomcat_service_account_username: LocalSystem
tomcat_service_account_password: ''
```

The `SERVICE-ACCOUNTS.md` documents how to override this, but the default is dangerously permissive.

**Recommendation:**
- Consider making the default a low-privilege local service account
- At minimum, add a warning in `defaults/main.yml` comments
- Production playbooks should always override this

**Severity:** MEDIUM - Privilege escalation via Tomcat compromise

---

### [MED-6] `eval` of Make Target Output in CI

**Location:** `.github/workflows/ci.yml:170`

**Issue:** The CI workflow uses `eval "$(make discover-aws-resources --silent)"` which evaluates the stdout of a make target as shell commands. If the make target's output is manipulated (e.g., via compromised AWS API responses or a supply chain attack on the Makefile), arbitrary commands execute in the CI context.

**Evidence:**
```bash
eval "$(make discover-aws-resources --silent)"
```

**Recommendation:** Instead of `eval`, parse the output line-by-line and validate each `KEY=VALUE` pair before exporting. Or have the make target write to a file and source it after validation.

**Severity:** MEDIUM - Command injection via make output

---

### [LOW-1] No Ingress Rule Cleanup After CI

**Location:** `.github/workflows/ci.yml:177-183` vs `241-246`

**Issue:** The "Authorize Security Group Ingress" step opens ports but the "Mandatory Cleanup" step only destroys Kitchen instances -- it does **not** revoke the security group ingress rules. These 0.0.0.0/0 rules persist after the CI run.

**Recommendation:** Add cleanup step:
```bash
aws ec2 revoke-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID --protocol tcp --port 5985 --cidr 0.0.0.0/0 || true
aws ec2 revoke-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 || true
aws ec2 revoke-security-group-ingress --group-id $AWS_SECURITY_GROUP_ID --protocol tcp --port 9080 --cidr 0.0.0.0/0 || true
```

**Severity:** LOW (amplifies HIGH-2)

---

### [LOW-2] `ssl._create_unverified_context()` in Lookup Plugin

**Location:** `lookup_plugins/controller_http.py:39-40`

**Issue:** The `controller_http` lookup plugin uses `ssl._create_unverified_context()` when `validate_certs=False`. While this is a configurable option (off by default), using the private `ssl._create_unverified_context()` API is a code smell and disables all certificate validation.

**Recommendation:** This is acceptable for test environments but should log a warning when used. Ensure production usage always has `validate_certs=True`.

**Severity:** LOW - TLS bypass (opt-in)

---

### [LOW-3] Hardcoded AWS Resource IDs as Fallbacks

**Location:** `.kitchen.yml:182-184`, `Makefile:106,110,114`

**Issue:** Hardcoded subnet IDs, security group IDs, and AMI IDs serve as fallbacks. These could become stale or point to unintended resources. More importantly, if the dynamic discovery fails silently, the CI may run against unexpected infrastructure.

**Evidence:**
```ruby
subnet_id: <%= ENV.fetch('AWS_SUBNET_ID', 'subnet-023f40afbc9e46c37') %>
security_group_ids: <%= ENV.fetch('AWS_SECURITY_GROUP_IDS', '["sg-0210845b571c6a0e1"]') %>
```

**Recommendation:** Fail hard instead of falling back to hardcoded IDs. This prevents accidental use of wrong resources.

**Severity:** LOW - Stale resource reference

---

### [LOW-4] Vault Root Token Retrieval in Shell Library

**Location:** `bin/_lib.sh:12-19`

**Issue:** The `get_vault_token` function retrieves the Vault **root token** from a Kubernetes secret. Root tokens have unlimited access. Best practice is to use scoped tokens.

**Evidence:**
```bash
get_vault_token() {
    local ns="${VAULT_NS:-vault}"
    local token
    token=$(kubectl get secret vault-root -n "$ns" \
        -o jsonpath='{.data.root_token}' 2>/dev/null | base64 -d)
```

**Recommendation:** Use AppRole or Kubernetes auth instead of the root token. If root token is needed for bootstrapping, add a comment explaining the scope limitation.

**Severity:** LOW - Excessive Vault privilege

---

## Summary Table

| ID | Severity | Finding | Location | Status |
|----|----------|---------|----------|--------|
| HIGH-1 | **HIGH** | No download checksum verification | tasks/install-Windows-tomcat.yml | **FIXED** |
| HIGH-2 | **HIGH** | Security group opened to 0.0.0.0/0 | .github/workflows/ci.yml | **FIXED** |
| HIGH-3 | **HIGH** | Missing CI fork protection | .github/workflows/ci.yml | **FIXED** |
| HIGH-4 | **HIGH** | WinRM plaintext over public internet | .kitchen.yml (AWS platforms) | DEFERRED |
| HIGH-5 | **HIGH** | No `no_log` on password operations | tasks/, tests/ | **FIXED** |
| MED-1 | **MEDIUM** | CredSSP wildcard delegation | windows-base role | OPEN |
| MED-2 | **MEDIUM** | Hardcoded test passwords | tests/playbook.yml | **FIXED** |
| MED-3 | **MEDIUM** | GH_PAT broad scope risk | .github/workflows/ci.yml | **FIXED** |
| MED-4 | **MEDIUM** | Shutdown port exposed | defaults/main.yml | **FIXED** |
| MED-5 | **MEDIUM** | LocalSystem as default service account | defaults/main.yml | **FIXED** |
| MED-6 | **MEDIUM** | `eval` of make output in CI | .github/workflows/ci.yml | **FIXED** |
| LOW-1 | **LOW** | SG ingress rules not revoked after CI | .github/workflows/ci.yml | **FIXED** |
| LOW-2 | **LOW** | Private SSL API usage | lookup_plugins/controller_http.py | **FIXED** |
| LOW-3 | **LOW** | Hardcoded AWS resource ID fallbacks | .kitchen.yml, Makefile | **FIXED** |
| LOW-4 | **LOW** | Vault root token usage | bin/_lib.sh | **FIXED** |

---

## Positive Security Observations

1. **Secret externalization** -- No plaintext production secrets in the repo
2. **SSH deploy keys** over PATs for private dependencies (windows-base, provision-windows-security)
3. **Documentation** -- CI-SECURITY.md, SERVICE-ACCOUNTS.md show security awareness
4. **HTTPS download URL** for Tomcat (just missing checksum)
5. **Mandatory cleanup** pattern in CI (`if: always()`)
6. **Path filtering** excludes docs/memory-bank from triggering CI
7. **Concurrency control** prevents parallel CI runs
8. **Draft PR gating** prevents unnecessary cloud resource usage
9. **Branch protection tooling** (bin/enforce-branch-protection)
10. **.gitignore** properly excludes .vagrant/, .kitchen/, .direnv/, scratch/
