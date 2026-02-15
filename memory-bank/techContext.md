# Technical Context

## Repository Type
- Ansible role repository: `provision-tomcat`
- Main function: provision Apache Tomcat on Windows hosts, including upgrades and candidate-based rollout workflows.

## Primary Technologies
- **Configuration Management:** Ansible (min version noted in metadata: 2.14)
- **Target Platform:** Windows via WinRM
- **Test Harness:** Test Kitchen
- **Local Virtualization:** Vagrant + VirtualBox
- **Cloud Sandbox Path:** Azure CLI + Kitchen AzureRM driver + Make targets

## Structure at a Glance
- `tasks/`: role execution logic (entry + install/upgrade workflow)
- `defaults/`: operational knobs (ports, versions, candidate workflow, service account variables)
- `lookup_plugins/`: controller-side network/http checks
- `tests/`: playbooks for default, upgrade, downgrade scenarios
- `docs/`: setup, troubleshooting, candidate strategy, service-account guidance
- `Makefile`: operator interface for validation, kitchen flows, Azure provisioning/testing

## Runtime Variables (Selected)
- Version/paths:
  - `tomcat_version`, `tomcat_major_version`
  - `tomcat_install_dir`, `tomcat_symlink_name`, `tomcat_temp_dir`
- Service/ports:
  - `tomcat_service_name`, `tomcat_http_port`, `tomcat_shutdown_port`
  - Candidate: `tomcat_candidate_*` (enabled flag, service name, ports, delegate settings)
- Retention/behavior:
  - `tomcat_keep_versions`, `tomcat_auto_start`, `tomcat_candidate_manual_control`
- Identity/security:
  - `tomcat_service_account_username`, `tomcat_service_account_password`

## Validation Paths
- Static checks: `make lint`, `make syntax`, `make check`
- Kitchen suites: default/upgrade/downgrade/idempotence/no-autostart + baseline/candidate paths
- Azure end-to-end commands: `make test-azure-provision-tomcat`, `make test-azure-upgrade-candidate`, `make test-azure-destroy`

## Security Model Notes
- Expected secret injection via lookup plugins and external secret stores.
- HashiCorp Vault pattern is documented and should be preferred to satisfy `.clinerules`.
- No plaintext service credentials should be committed.

## Security Audit Status (2026-02-14)
- Full red-team audit completed: `docs/SECURITY-AUDIT.md`
- **15 findings**: 5 HIGH, 6 MEDIUM, 4 LOW
- Critical gaps: no download integrity checks, WinRM plaintext over internet, missing CI fork protection, no `no_log` usage, AWS SG wide-open during CI
- Positive: no secrets in repo, SSH deploy keys, good documentation, cleanup patterns

## Known Gaps / Guardrails
- `.clinerules` references k3s and ArgoCD architecture alignment, but this repo currently centers on Ansible role execution and Windows host provisioning.
- No direct k3s/ArgoCD manifests or controllers were detected in current repository scan.