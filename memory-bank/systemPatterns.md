# System Patterns

## 1) Role Execution Pattern

### Entry Point
- `tasks/main.yml` conditionally includes `install-Windows-tomcat.yml` only when target OS family is Windows.

### High-Level Flow
1. Assert Java prerequisites from upstream role facts (`java_home`).
2. Compute paths and inspect current install state.
3. Decide among:
   - no-op/idempotent run,
   - standard install,
   - upgrade path,
   - candidate-based upgrade path.
4. Ensure service, firewall, and HTTP reachability checks.

## 2) Versioned Install + Symlink Pattern
- Installation directory keeps explicit version folders (`apache-tomcat-x.y.z`).
- Stable runtime path uses a symlink (`current`) consumed by the main service.
- Benefits: cleaner upgrades, easier rollback, and stable service path.

## 3) Candidate Upgrade Pattern (Near Zero-Downtime)
- Candidate mode activates when `tomcat_candidate_enabled=true` **or** delegate settings imply candidate checks.
- Candidate service installs from new version dir on alternate ports (`9080` HTTP, `9005` shutdown by default).
- Candidate verification includes:
  - guest-local checks (`win_wait_for`, `win_uri`),
  - optional controller-side checks via custom lookups (`controller_port`, `controller_http`).
- Promotion sequence:
  - stop/uninstall old primary service,
  - repoint `current` symlink,
  - install/restart primary service on 8080,
  - remove candidate service and candidate firewall rule.
- Optional manual pause with `tomcat_candidate_manual_control=true` for human approval.

## 4) Controller-Side Verification Pattern
- Custom lookup plugins in `lookup_plugins/` run probes from controller context rather than via WinRM on guest:
  - `controller_port.py` for TCP reachability.
  - `controller_http.py` for HTTP status validation.
- This pattern better models external health checks/load balancer perspective.

## 5) Retention and Cleanup Pattern
- `tomcat_keep_versions` controls historical version retention.
- Older versioned directories are sorted and removed beyond retention threshold.

## 6) Test Orchestration Pattern
- Test Kitchen defines platforms/suites and per-suite networking.
- Makefile wraps common operations for:
  - lint/syntax checks,
  - local Vagrant lifecycle,
  - upgrade/candidate tests,
  - Azure sandbox create/provision/verify/destroy workflows.

## 7) Security & Secret Management Pattern
- Service account override variables:
  - `tomcat_service_account_username`
  - `tomcat_service_account_password`
- Documented best practice is dynamic secret lookup; avoid plaintext in repo.
- HashiCorp Vault is explicitly documented and aligns with `.clinerules` requirements.

## 8) Required Cross-Agent Documentation Pattern
- `memory-bank/` is the collaboration substrate across agents.
- `activeContext.md` must capture both **what changed** and **why decisions were made**.
- `progress.md` must maintain pending TODOs to prevent session-handoff loss.

## 9) Infrastructure & CI/CD Patterns

### Hybrid Zero-Touch Sync
To manage ephemeral AWS sandbox environments (such as AGC):
- **Manual Credential Sync**: `make sync-aws` remains a manual initial step performed locally by the user to refresh OAuth/session tokens and push them to GitHub Secrets. This acknowledges the hard constraint of dynamic credential updates on sandbox recreation.
- **Automatic Resource Discovery**: After manual credential sync, subsequent local `make` targets for AWS integration will dynamically discover resource IDs (subnet, security group, AMI) from the live sandbox using AWS APIs. These discovered IDs will then be used for the test run, automating the binding of ephemeral infrastructure to the CI configuration.
- **Benefits**: This hybrid approach balances security (explicit credential refresh) with automation (resource ID discovery), mitigating CI fragility due to infrastructure drift.

### Zero-Touch Secret Sync
To support rotating sandboxes without manual configuration:
- Local `.envrc` hooks detect active AWS/Azure sessions.
- `make sync-secrets` (via `gh` CLI) pushes current session credentials to GitHub Secrets.
- Ensures CI environment is always in parity with the developer's local sandbox.

### Conditional Integration Fallback
Optimizes runner usage and provides testing redundancy:
- CI attempts cloud-native integration first (AWS/Azure).
- Cloud availability is detected at runtime (`aws sts get-caller-identity`).
- If cloud resources are inaccessible, the pipeline falls back to `vagrant_integration` or local virtualization.

### Portable Role Management
Bypasses filesystem dependencies on self-hosted runners:
- Uses `actions/checkout` with `ssh-key` (via `DEPLOY_KEY` secrets) for all private roles.
- Eliminates the need for runner-specific symlinks or persistent filesystem state.

### Controlled CI Execution
To manage CI runs during discussion, documentation, or minor non-code changes:
- **Path Filtering**: Workflows will be configured with `paths:` filters to only trigger for changes in relevant code/config files, excluding documentation (`docs/`) or memory bank (`memory-bank/`) directories.
- **Draft Pull Requests**: Utilize Draft PRs to signal that a PR is not yet ready for full integration testing, allowing for lighter or conditional CI checks.

## 11) Security Implementation Patterns



### Supply Chain Integrity

- **Artifact Verification**: All binary downloads (e.g., Tomcat ZIP) must use `win_get_url` with explicit SHA-512 checksums defined in `defaults/main.yml`.

- **Version Pinning**: Versions and their corresponding hashes are updated in tandem to ensure repeatable and secure builds.



### CI/CD Hardening (Self-Hosted)

- **Fork Protection**: Job-level guards enforce that code only executes on self-hosted runners if it originates from the main repository or authorized manual dispatches.

- **Dynamic Network Gating**: AWS Security Groups are programmatically restricted to the CI runner's public IP (`RUNNER_IP/32`) at runtime and revoked immediately in an `always()` cleanup step.

- **Environment Isolation**: Runner IP is persisted in `$GITHUB_ENV` to ensure consistent revocation even if NAT/Proxy rotation occurs during the job.



### Data & Transport Protection

- **Credential Masking**: `no_log: true` is mandatory for all tasks handling passwords (service accounts, test users).

- **Service Hardening**: Network-facing ports that do not require external access (e.g., Tomcat Shutdown Port) are explicitly bound to `127.0.0.1`.

- **WinRM Security**: While port `5985` is currently used due to AMI limitations, access is strictly gated by IP-restricted Security Group rules.
