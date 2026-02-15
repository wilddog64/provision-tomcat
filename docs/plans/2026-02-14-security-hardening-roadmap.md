# Security Hardening Roadmap (2026-02-14)

Following the Red Team Security Audit (`docs/SECURITY-AUDIT.md`), this roadmap outlines the plan to remediate the identified vulnerabilities.

## Phase 1: Critical CI & Supply Chain Hardening
**Priority: Immediate**
Focuses on preventing RCE on runners and ensuring artifact integrity.

- **[HIGH-1] Tomcat Download Integrity:** Add SHA-512 checksum validation to `win_get_url` in `tasks/install-Windows-tomcat.yml`.
- **[HIGH-3] CI Fork Protection:** Implement the missing job-level `if` conditions in `ci.yml` to prevent unauthorized execution on self-hosted runners.
- **[HIGH-2] & [LOW-1] AWS SG Hardening:**
    - Restrict ingress CIDR to the runner's public IP in `ci.yml`.
    - Implement `aws ec2 revoke-security-group-ingress` in the mandatory cleanup step.

## Phase 2: Data & Transport Security
**Priority: High**
Focuses on protecting credentials and sensitive data.

- **[HIGH-5] Log Security (`no_log`):** Add `no_log: true` to all tasks handling `tomcat_service_account_password` and test account passwords.
- **[HIGH-4] WinRM HTTPS for AWS:**
    - Configure AMI or use a user-data script to enable WinRM HTTPS (5986).
    - Update `.kitchen.yml` to use `https` and port 5986 for AWS platforms.
- **[MED-4] Tomcat Shutdown Port:** Configure `server.xml` to bind the shutdown port to `127.0.0.1`.
- **[MED-5] Service Account Defaults:** Update `defaults/main.yml` with safer defaults or clearer warnings against `LocalSystem`.

## Phase 3: Infrastructure & Credential Hardening
**Priority: Medium/Low**
Focuses on least privilege and code quality.

- **[MED-1] CredSSP Delegation:** Restrict wildcard delegation in `windows-base` role.
- **[MED-6] CI `eval` Replacement:** Refactor Makefile output parsing in `ci.yml` to avoid `eval`.
- **[MED-3] GH_PAT Migration:** Audit PAT scope or migrate to SSH deploy keys for `provision-java`.
- **[MED-2] Test Passwords:** Move hardcoded test passwords to variables (even if defaults) and document the risk.
- **[LOW-2/3/4] Polish Items:** SSL API usage in lookup plugin, AWS resource ID fallbacks, and Vault root token usage.

## Discussion Points
1. **WinRM HTTPS:** Enabling HTTPS on AWS AMIs might require a pre-configured image or a slightly more complex bootstrap.
2. **Fork Protection:** This will effectively block external contributors from running CI until a maintainer merges/mirrors the PR.
3. **`no_log`:** Balancing debuggability vs. security in test environments.
