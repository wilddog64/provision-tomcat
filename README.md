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

<<<<<<< HEAD
For troubleshooting common issues in the ACG Azure sandbox (Resource Group restrictions, MSI timeouts, etc.), see **[Azure Kitchen Integration Issues](docs/issues/AZURE-KITCHEN-INTEGRATION.md)**.
=======
### Upgrade Java and Tomcat Together

```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    java_version: 21
    tomcat_version: "9.0.120"
  roles:
    - provision-java
    - provision-tomcat
```

### Zero-Downtime Candidate Testing

If you need to run the new Tomcat/Java build side-by-side before switching the `current` symlink, see `docs/ZERO-DOWNTIME-UPGRADES.md`. It describes how to install a temporary service on an alternate port, run smoke tests from both inside the VM and from the controller, and promote (or roll back) entirely within Ansible. For recurring problems we have hit during this process (candidate tasks skipping, controller waits failing, or port 9080 never opening), refer to `docs/CANDIDATE-TROUBLESHOOTING.md`.

For a one-command automated test run (including cleanup), execute `bin/test-upgrade-candidate` from the repo root. It chains together `make candidate-cleanup-win11` and `make test-upgrade-candidate-stack` so step 1, step 2, and teardown all happen sequentially.

### Verification After Upgrade

```bash
# Check Tomcat service status
ansible windows -m ansible.windows.win_service_info -a "name=Tomcat9"

# Test HTTP accessibility
# Replace 8080 with tomcat_http_port if you override the default
curl http://localhost:8080
```

## Verification

The role includes built-in verification tasks:

1. Verifies Java is installed (checks `java_home` fact from `provision-java` role)
2. Confirms Tomcat files are extracted correctly
3. Verifies Windows service is installed
4. Checks service status
5. Tests HTTP accessibility on port 8080 (200 or 404 response)

The test playbook (`tests/playbook.yml`) includes additional verification from the host machine.

## Makefile Targets

Run `make help` for all available targets:

### Validation

```bash
make setup          # Verify and setup development environment
make lint           # Run ansible-lint
make syntax         # Check playbook syntax
make check          # Run all validation checks
```

### Utilities

```bash
make deps             # Install Ansible collections
make list-kitchen-instances  # List kitchen instances
make destroy-all      # Destroy all kitchen instances
```

## Local Testing

This role uses Test Kitchen with Vagrant for automated testing.

**Documentation**:
- **[AWS AGC Integration Plan](docs/plans/aws/kitchen-aws-integration.md)** - Plan for AWS-based testing
- **[Development Environment Setup](docs/DEVELOPMENT-SETUP.md)** - First-time setup and prerequisites
- **[Test Kitchen Guide](docs/TEST-KITCHEN.md)** - Using Test Kitchen for testing
- **[Testing Upgrades](docs/TESTING-UPGRADES.md)** - Upgrade and downgrade testing procedures
- **[Zero-Downtime Upgrades](docs/ZERO-DOWNTIME-UPGRADES.md)** - Candidate workflow details
- **[Candidate Troubleshooting](docs/CANDIDATE-TROUBLESHOOTING.md)** - Common issues and fixes while exercising the candidate workflow
- **[VirtualBox Stale Disks](docs/issues/VIRTUALBOX-STALE-DISKS.md)** - Fix for `VERR_ALREADY_EXISTS` errors when creating disks
- **[Controller Lookup Plugins](docs/plugins/CONTROLLER-LOOKUP-PLUGINS.md)** - How the controller-side port/HTTP checks work

### Test Suites

| Suite | Description |
| --- | --- |
| `default` | Basic installation with auto-start enabled |
| `upgrade` | Tests upgrade from one version to another |
| `idempotence` | Verifies role is idempotent (no changes on second run) |
| `no-autostart` | Tests installation with `tomcat_auto_start: false` |

### D: Drive Installation

Install Tomcat and Java on D: drive instead of C: drive. This requires a baseline box with a pre-formatted D: drive.

#### Build the D: Drive Baseline Box

```bash
# Build minimal box with D: drive only (no Tomcat/Java)
make vagrant-build-baseline-minimal

# Add the box to Vagrant
vagrant box add windows11-disk boxes/windows11-disk.box
```

#### Test with D: Drive

```bash
# Test Kitchen with D: drive
make test-win11-disk

# Or with Vagrant
JDK_VERSION=21 install_drive=D: vagrant up
vagrant provision --provision-with disk_setup
vagrant provision
```

#### Ansible Variables for D: Drive

Set `install_drive` to change the installation path:

```yaml
# In playbook or extra_vars
install_drive: "D:"
# This sets:
#   java_install_base_dir: D:/java
#   tomcat_install_dir: D:/Tomcat
#   java_temp_dir: D:/temp
#   tomcat_temp_dir: D:/temp
```

Or set paths individually:

```bash
ansible-playbook -i inventory playbook.yml \
  -e 'java_install_base_dir=D:/java' \
  -e 'tomcat_install_dir=D:/Tomcat' \
  -e 'tomcat_temp_dir=D:/temp'
```

### Quick Testing Commands

```bash
# List all test instances
make list-kitchen-instances

# Test default suite on Windows 11
make test-win11

# Test specific suite
make test-default-win11
make test-upgrade-win11
make test-upgrade-baseline-win11
make test-idempotence-win11
make test-no-autostart-win11

# Test all suites
make test-all-win11

# Step-by-step testing
make converge-win11    # Run Ansible provisioning
make verify-win11      # Run verification
make destroy-win11     # Clean up
```

### Vagrant Candidate Helper

For a direct Vagrant workflow (outside Test Kitchen), use `bin/vagrant-port-check`. It:

1. Brings up the Windows 11 guest without provisioning.
2. Runs step 1 of the upgrade playbook (Tomcat 9.0.112 / Java 17).
3. Runs step 2 with `tomcat_candidate_manual_control=true`, which leaves the candidate service running on port 9080.
4. Verifies ports 8080/9080 from the controller and waits for user confirmation.
5. After you press Enter, reruns step 2 with `tomcat_candidate_manual_control=false` to promote and clean up.

Ensure port forwarding for 8080 and 9080 is available in `Vagrantfile` (already defined) before running the script.

#### Pre-built baseline box (optional)

If you want to skip the "install Tomcat 9.0.112 / Java 17" phase entirely, run `bin/vagrant-build-baseline`. It provisions the stock Windows 11 box with step 1 of the upgrade playbook and packages it into `boxes/windows11-tomcat9.0.112-java17.box`. You can then `vagrant box add windows11-tomcat112 boxes/windows11-tomcat9.0.112-java17.box` and point your Vagrantfile to that box for demos where you only want to exercise the upgrade/candidate workflow.

#### Upgrade-only script

Once the baseline box is installed (`windows11-tomcat112`), `bin/vagrant-upgrade-demo` drives the rest of the demo using `Vagrantfile-upgrade`:

1. Brings the baseline box up (no provisioning).
2. Runs the candidate prepare pass (manual control enabled).
3. Verifies ports 8080/9080.
4. Promotes/cleans up after you press Enter.
5. Destroys the VM unless you pass `--keep`.

Run it directly or via `make vagrant-upgrade-demo`. You can keep the VM running by invoking either `make vagrant-upgrade-demo KEEP` (or `KEEP=1 make vagrant-upgrade-demo`) or by running the script with `--keep`.

### Manual Testing

```bash
# Create VM
kitchen create default-win11

# Run provisioning
kitchen converge default-win11

# Run verifier
kitchen verify default-win11

# Destroy VM
kitchen destroy default-win11

# Or do all at once
kitchen test default-win11
```

### Supported Platforms

- Windows 11 (`win11`)
- Ubuntu 24.04 (`ubuntu-2404`)
- Rocky Linux 9 (`rockylinux9`)

Note: Tomcat installation is currently implemented for Windows only.

## Architecture

### Installation Flow

1. **Verify Java** - Checks that Java is installed via `provision-java` role
2. **Check existing installation** - Looks for existing Tomcat directories
3. **Determine action** - Install new, upgrade existing, or skip
4. **Download** (if needed) - Downloads Tomcat zip from Apache mirror
5. **Extract** - Unzips to installation directory
6. **Configure environment** - Sets `CATALINA_HOME` variable
7. **Install service** - Uses `service.bat` with environment variables
8. **Configure firewall** - Creates Windows Firewall rule for port 8080
9. **Start service** - Starts Tomcat (if `tomcat_auto_start: true`)
10. **Verify** - Confirms service is running and accessible

### Service Installation

The role uses Tomcat's native `service.bat install` command with the `environment` parameter to ensure `CATALINA_HOME` is set correctly:

```yaml
- name: Install Tomcat Windows service
  ansible.windows.win_command: '"{{ tomcat_home }}/bin/service.bat" install'
  environment:
    CATALINA_HOME: "{{ tomcat_home }}"
```

This approach is more stable than PowerShell-based service installation.

## Troubleshooting

### Port 8080 Not Accessible

The role automatically configures the Windows Firewall, but verify:

1. **Check firewall rule exists:**
   ```powershell
   Get-NetFirewallRule -DisplayName "Tomcat Server"
   ```

2. **Check service is running:**
   ```powershell
   Get-Service Tomcat9
   ```

3. **Test from inside VM:**
   ```powershell
   curl http://localhost:8080
   ```

4. **Check port forwarding** (if using Vagrant):
   ```bash
   vagrant port
   ```

### Service Won't Start

Check the Tomcat logs:
```
C:/Tomcat/Tomcat/apache-tomcat-{version}/logs/
```

Common issues:
- Java not installed or `JAVA_HOME` not set
- Port 8080 already in use
- Insufficient permissions

### Upgrade Issues

If an upgrade fails:

1. **Check backup exists:**
   ```powershell
   Get-ChildItem C:/Tomcat/Tomcat -Filter "*.bak.*"
   ```

2. **Manual rollback:**
   ```powershell
   Stop-Service Tomcat9
   Remove-Item "C:/Tomcat/Tomcat/apache-tomcat-{new-version}" -Recurse
   Rename-Item "C:/Tomcat/Tomcat/apache-tomcat-{old-version}.bak.{timestamp}" `
               "C:/Tomcat/Tomcat/apache-tomcat-{old-version}"
   # Re-run Ansible with old version
   ```

3. **Clean install:**
   - Set `tomcat_version` to desired version
   - Destroy and recreate VM
   - Re-run playbook

### VirtualBox Disk Errors

If you see `VERR_ALREADY_EXISTS` when creating VMs with D: drive:

```bash
# Clean up stale disk registrations
make vbox-cleanup-disks
```

See **[VirtualBox Stale Disks](docs/issues/VIRTUALBOX-STALE-DISKS.md)** for details.

### GitHub Actions CI Errors

If you encounter "Repository not found" errors when checking out private dependencies:

- See **[GitHub Actions Multiple Deploy Keys](docs/issues/GITHUB-ACTIONS-MULTIPLE-DEPLOY-KEYS.md)** for the fix regarding ambiguous SSH keys.

### CI on Self-Hosted Runners

If you encounter crashes with Vagrant, Bundler conflicts, or "Command Not Found" errors in CI:

- See **[CI Robustness Fixes](docs/issues/2026-02-04-ci-robustness-fixes.md)** for details on the Vagrant wrapper, Python injection, and environment isolation.
>>>>>>> 6bdb856 (docs(aws): link AWS integration plan and issues in README)

### Known Issues

See the [docs/issues](docs/issues/) directory for detailed documentation on common problems:

| Issue | Description |
|-------|-------------|
| **[pywinrm urllib3 Compatibility](docs/issues/pywinrm-urllib3-compatibility.md)** | AttributeError with urllib3 2.x - pin to `urllib3<2` |
| **[Vagrant Bundler Conflict](docs/issues/VAGRANT-BUNDLER-CONFLICT.md)** | Vagrant crashes due to rbenv/Bundler environment pollution |
| **[WinRM Port Forwarding](docs/issues/WINRM-PORT-FORWARDING.md)** | Ansible connection fails - use port 55985 not 5985 |
| **[provision-java Regex Crash](docs/issues/PROVISION-JAVA-REGEX-CRASH.md)** | NoneType error parsing Java version |
| **[Candidate Mode Port](docs/issues/CANDIDATE-MODE-PORT.md)** | Candidate mode uses 9080 during testing; final verify must hit 8080 post-promotion |
| **[GitHub workflow_run Limitation](docs/issues/GITHUB-WORKFLOW-RUN-LIMITATION.md)** | workflow_run only works from default branch |
| **[VirtualBox Stale Disks](docs/issues/VIRTUALBOX-STALE-DISKS.md)** | VERR_ALREADY_EXISTS when creating disks |
| **[Multiple Deploy Keys](docs/issues/GITHUB-ACTIONS-MULTIPLE-DEPLOY-KEYS.md)** | SSH key ambiguity with multiple private repos |
| **[AWS Kitchen Integration](docs/issues/AWS-KITCHEN-INTEGRATION.md)** | Region mismatches, WinRM connectivity, and hostname resolution issues |

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
