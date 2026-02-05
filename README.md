# Provision Tomcat Role

![Demo](docs/recordings/provision-tmcat.gif)
*More recordings [here](docs/recordings/README.md)*

This Ansible role installs Apache Tomcat on Windows hosts by downloading the official Tomcat zip archive directly from Apache mirrors. It handles installation, upgrades, Windows service configuration, and firewall rules.

## Requirements

- Control node: Python 3.9+, Ansible 2.14+, and the `ansible.windows` and `community.windows` collections
- Target node: Windows accessible over WinRM with admin rights
- Java must be installed first (use the `provision-java` role)

## Role Variables

Default variables (`defaults/main.yml`):

| Variable | Default | Description |
| --- | --- | --- |
| `tomcat_version` | `'9.0.115'` | Tomcat version to install |
| `tomcat_major_version` | `'9'` | Major version (used for service name and paths) |
| `tomcat_service_name` | `"Tomcat{{ tomcat_major_version }}"` | Windows service name (e.g., `Tomcat9`) |
| `tomcat_install_dir` | `'C:/Tomcat'` | Base installation directory |
| `tomcat_symlink_name` | `'current'` | Symlink name pointing to active version |
| `tomcat_download_url` | `"https://dlcdn.apache.org/tomcat/tomcat-{{ tomcat_major_version }}/v{{ tomcat_version }}/bin/apache-tomcat-{{ tomcat_version }}-windows-x64.zip"` | Apache mirror download URL |
| `tomcat_checksum` | `'sha512:...'` | SHA-512 checksum for download validation |
| `tomcat_temp_dir` | `'C:/temp'` | Temporary directory for downloads |
| `tomcat_auto_start` | `true` | Whether to start Tomcat service automatically after installation |
| `tomcat_keep_versions` | `10` | Number of old Tomcat versions to keep (0 = keep all) |
| `tomcat_http_port` | `8080` | Primary HTTP connector + firewall port |
| `tomcat_shutdown_port` | `8005` | Shutdown port used by the main Tomcat service |
| `tomcat_candidate_enabled` | `false` | Enable side-by-side candidate installs for zero downtime |
| `tomcat_candidate_port` | `9080` | HTTP port used by the temporary candidate service |
| `tomcat_service_account_username` | `LocalSystem` | Windows service account for Tomcat (LocalSystem is default) |

The Tomcat installation uses a symlink structure:

```
C:/Tomcat/
├── apache-tomcat-9.0.112/    # Actual installation
├── apache-tomcat-9.0.115/    # After upgrade
└── current -> apache-tomcat-9.0.115/  # Symlink (always points to active version)
```

## Features

### Direct Download Installation
- Downloads Tomcat directly from Apache mirrors (no dependency on Chocolatey)
- **Security**: Verifies download integrity using SHA-512 checksums.
- Extracts to configured installation directory
- Installs Windows service using Tomcat's `service.bat` script
- Automatically configures Windows Firewall

### Automatic Upgrades
The role automatically detects and handles Tomcat upgrades using symlinks, allowing for safe version transitions and easy rollbacks.

### Version Retention Policy
The role automatically manages old Tomcat versions using the `tomcat_keep_versions` variable (default: 10).

## Infrastructure & Testing

This role uses Test Kitchen with Vagrant and AWS for automated testing.

### AWS Testing (AGC Sandbox)
The project utilizes a **Hybrid Zero-Touch Sync** strategy to handle ephemeral AWS sandboxes:
- Dynamic resource discovery for Subnets, SGs, and AMIs.
- Automated SG ingress gating restricted to the runner's public IP.
- Verified end-to-end on `aws-dev`.

### Azure Testing (CLI Workflow)
In restricted sandboxes where Test Kitchen drivers may fail, use the following self-contained targets. These require an active `az login`.

```bash
make test-azure-provision-tomcat   # Full provision test
make test-azure-upgrade-candidate # Zero-downtime upgrade test
make test-azure-destroy           # Teardown all resources
```

For troubleshooting common issues in the ACG Azure sandbox (Resource Group restrictions, MSI timeouts, etc.), see **[Azure Kitchen Integration Issues](docs/issues/AZURE-KITCHEN-INTEGRATION.md)**.

## Security

The project has undergone a comprehensive security audit. Key protections include:
- **Fork Protection**: Jobs only run on self-hosted runners if triggered from the original repository.
- **Network Hardening**: Dynamic SG rules and localhost-only shutdown ports.
- **Credential Safety**: Mandatory `no_log: true` for all sensitive tasks.

See **[CI/CD Security Architecture](docs/CI-SECURITY.md)** and **[Security Audit Report](docs/SECURITY-AUDIT.md)** for details.

## Troubleshooting

### GitHub Actions CI Errors
If you encounter "Repository not found" errors when checking out private dependencies:
- See **[GitHub Actions Multiple Deploy Keys](docs/issues/GITHUB-ACTIONS-MULTIPLE-DEPLOY-KEYS.md)** for the fix regarding ambiguous SSH keys.

### CI on Self-Hosted Runners
If you encounter crashes with Vagrant, Bundler conflicts, or "Command Not Found" errors in CI:
- See **[CI Robustness Fixes](docs/issues/2026-02-04-ci-robustness-fixes.md)** for details on the Vagrant wrapper, Python injection, and environment isolation.

<<<<<<< HEAD
### Known Issues
See the [docs/issues](docs/issues/) directory for detailed documentation on common problems.
=======
## Security

For details on how the CI/CD pipeline is secured on the self-hosted runner (including fork protection, SSH key management, and environment isolation), see **[CI/CD Security Architecture](docs/CI-SECURITY.md)**.
>>>>>>> 265921a (docs: add CI security architecture documentation)

## Dependencies

1. **provision-java role** - Must run before this role.
2. **Ansible collections:** `ansible.windows`, `community.windows`, `chocolatey.chocolatey`.

## License
[MIT](LICENSE)
