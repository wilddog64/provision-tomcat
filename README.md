# Provision Tomcat Role

This Ansible role installs Apache Tomcat on Windows hosts by downloading the official Tomcat zip archive directly from Apache mirrors. It handles installation, upgrades, Windows service configuration, and firewall rules.

## Requirements

- Control node: Python 3.9+, Ansible 2.14+, and the `ansible.windows` and `community.windows` collections
- Target node: Windows accessible over WinRM with admin rights
- Java must be installed first (use the `provision-java` role)

## Role Variables

Default variables (`defaults/main.yml`):

| Variable | Default | Description |
| --- | --- | --- |
| `tomcat_version` | `'9.0.113'` | Tomcat version to install |
| `tomcat_major_version` | `'9'` | Major version (used for service name and paths) |
| `tomcat_service_name` | `"Tomcat{{ tomcat_major_version }}"` | Windows service name (e.g., `Tomcat9`) |
| `tomcat_install_dir` | `'C:/Tomcat'` | Base installation directory |
| `tomcat_symlink_name` | `'current'` | Symlink name pointing to active version |
| `tomcat_download_url` | `"https://dlcdn.apache.org/tomcat/tomcat-{{ tomcat_major_version }}/v{{ tomcat_version }}/bin/apache-tomcat-{{ tomcat_version }}-windows-x64.zip"` | Apache mirror download URL |
| `tomcat_temp_dir` | `'C:/temp'` | Temporary directory for downloads |
| `tomcat_auto_start` | `true` | Whether to start Tomcat service automatically after installation |
| `tomcat_keep_versions` | `10` | Number of old Tomcat versions to keep (0 = keep all) |
| `tomcat_http_port` | `8080` | Primary HTTP connector + firewall port |
| `tomcat_shutdown_port` | `8005` | Shutdown port used by the main Tomcat service |
| `tomcat_candidate_enabled` | `false` | Enable side-by-side candidate installs for zero downtime (automatically flips on when `tomcat_candidate_delegate` is set) |
| `tomcat_candidate_port` | `9080` | HTTP port used by the temporary candidate service |
| `tomcat_candidate_shutdown_port` | `9005` | Shutdown port used by the temporary candidate service |
| `tomcat_candidate_service_name` | `Tomcat{{ tomcat_major_version }}Candidate` | Windows service name for the candidate instance |
| `tomcat_candidate_delegate` | `null` | Controller host to run port checks from; also forces candidate workflow when defined |
| `tomcat_candidate_delegate_connection` | `'local'` | Connection plugin used for delegated checks (set to `ssh`, `paramiko`, `winrm`, etc. when needed) |
| `tomcat_candidate_delegate_python` | `null` | Optional Python interpreter path for the delegate (useful for non-default controllers) |
| `tomcat_candidate_delegate_status_codes` | `[200, 404]` | HTTP status codes that count as success for controller-side checks |
| `tomcat_candidate_manual_control` | `false` | Leave the candidate service running on port 9080 (skip promotion/cleanup) so you can promote later |
| `tomcat_service_account_username` | `LocalSystem` | Windows service account for Tomcat service (set to domain/user to override) |
| `tomcat_service_account_password` | `''` | Password for the custom service account (ignored for LocalSystem) |

The Tomcat installation uses a symlink structure:

```
C:/Tomcat/
├── apache-tomcat-9.0.113/    # Actual installation
├── apache-tomcat-9.0.120/    # After upgrade
└── current -> apache-tomcat-9.0.120/  # Symlink (always points to active version)
```

The Tomcat service points to: `C:/Tomcat/current/`

## Features

### Direct Download Installation

- Downloads Tomcat directly from Apache mirrors (no dependency on Chocolatey)
- Extracts to configured installation directory
- Installs Windows service using Tomcat's `service.bat` script
- Automatically configures Windows Firewall to allow port `tomcat_http_port` (8080 by default)

### Automatic Upgrades

The role automatically detects and handles Tomcat upgrades using symlinks:

1. **Detects existing installation** - Finds any `apache-tomcat-*` directory
2. **Checks if upgrade needed** - Compares existing version to `tomcat_version` variable
3. **Performs upgrade safely**:
   - Stops Tomcat service
   - Uninstalls old service
   - Removes old symlink
   - Downloads and extracts new version to `apache-tomcat-{{ tomcat_version }}/`
   - Creates new symlink: `current -> apache-tomcat-{{ tomcat_version }}/`
   - Installs new service pointing to `C:/Tomcat/current/`
   - Starts new service

**Benefits of symlink approach**:
- Clean upgrades without renaming directories
- Easy rollback (just repoint symlink)
- Multiple versions can coexist
- Service always points to same path (`C:/Tomcat/current/`)

### Version Retention Policy

The role automatically manages old Tomcat versions using the `tomcat_keep_versions` variable:

- **Default retention**: Keeps the 10 most recent versions
- **Automatic cleanup**: Removes older versions beyond the retention limit during installation/upgrade
- **Sorting**: Versions are sorted by modification time (newest first)
- **Disable cleanup**: Set `tomcat_keep_versions: 0` to keep all versions

**Example:**
- You have versions: 9.0.100, 9.0.105, 9.0.110, 9.0.113, 9.0.115, 9.0.117, 9.0.119, 9.0.120 (8 versions)
- You upgrade to 9.0.125 (9 versions total)
- Next upgrade to 9.0.130 (10 versions total)
- Next upgrade to 9.0.135 (11 versions) - oldest version (9.0.100) is automatically removed
- Result: You always have the current version plus 9 previous versions for rollback

This ensures you have recent versions available for rollback while preventing unlimited disk usage growth.

### Service Management

- Uses batch commands (not PowerShell) for reliability
- Sets `CATALINA_HOME` environment variable during service installation
- Supports auto-start control via `tomcat_auto_start` variable
- Provides Ansible tags for selective execution

### Firewall Configuration

- Automatically creates Windows Firewall rule named "Tomcat Server"
- Allows inbound TCP connections on `tomcat_http_port` (8080 default)
- Ensures Tomcat is accessible from host machine via port forwarding

## Behavior

The role is designed to be **idempotent** and **production-safe**:

1. **First installation:**
   - Downloads Tomcat zip from Apache mirror
   - Extracts to installation directory
   - Sets `CATALINA_HOME` environment variable
   - Installs Windows service
   - Configures firewall rule
   - Starts service (if `tomcat_auto_start: true`)

2. **Subsequent runs (same version):**
   - Detects existing installation
   - Skips download/extract
   - Ensures service is running (if `tomcat_auto_start: true`)
   - No changes made

3. **Upgrade runs (different version):**
   - Detects version mismatch
   - Stops existing service
   - Backs up old installation
   - Downloads new version
   - Installs new service
   - Starts new service

## Ansible Tags

The role supports these tags for selective task execution:

| Tag | Description |
| --- | --- |
| `tomcat-install` | Installation and upgrade tasks |
| `tomcat-service` | Service management tasks |
| `tomcat-restart` | Restart Tomcat service |
| `tomcat-verify` | Verification tasks |

**Examples:**
```bash
# Only install/upgrade Tomcat
ansible-playbook playbook.yml --tags tomcat-install

# Only restart Tomcat
ansible-playbook playbook.yml --tags tomcat-restart

# Skip installation, only verify
ansible-playbook playbook.yml --skip-tags tomcat-install
```

## Example Playbooks

### Basic Installation

```yaml
---
- hosts: windows
  gather_facts: yes
  roles:
    - provision-java      # Installs Java (required)
    - provision-tomcat    # Installs Tomcat
```

### Install Specific Version

```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_version: "9.0.120"
  roles:
    - provision-java
    - provision-tomcat
```

### Install Without Auto-Start

```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_version: "9.0.113"
    tomcat_auto_start: false
  roles:
    - provision-java
    - provision-tomcat
```

### Upgrade to New Version

```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_version: "9.0.120"  # Change to new version
  roles:
    - provision-java
    - provision-tomcat
```

When you change `tomcat_version`, the role will:
1. Detect the version mismatch
2. Stop the old service
3. Backup the old installation (e.g., `apache-tomcat-9.0.113.bak.1736549230`)
4. Install the new version
5. Start the new service

## Upgrade Procedures

### Simple Version Upgrade

To upgrade Tomcat to a new version:

```bash
ansible-playbook -i inventory playbook.yml --extra-vars "tomcat_version=9.0.120"
```

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

For a one-command automated test run (including cleanup), execute `bin/test-upgrade-candidate.sh` from the repo root. It chains together `make candidate-cleanup-win11` and `make test-upgrade-candidate-stack` so step 1, step 2, and teardown all happen sequentially.

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

## Local Testing

This role uses Test Kitchen with Vagrant for automated testing.

**Documentation**:
- **[Development Environment Setup](docs/DEVELOPMENT-SETUP.md)** - First-time setup and prerequisites
- **[Test Kitchen Guide](docs/TEST-KITCHEN.md)** - Using Test Kitchen for testing
- **[Testing Upgrades](docs/TESTING-UPGRADES.md)** - Upgrade and downgrade testing procedures
- **[Zero-Downtime Upgrades](docs/ZERO-DOWNTIME-UPGRADES.md)** - Candidate workflow details
- **[Candidate Troubleshooting](docs/CANDIDATE-TROUBLESHOOTING.md)** - Common issues and fixes while exercising the candidate workflow
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

For a direct Vagrant workflow (outside Test Kitchen), use `bin/vagrant-port-check.sh`. It:

1. Brings up the Windows 11 guest without provisioning.
2. Runs step 1 of the upgrade playbook (Tomcat 9.0.112 / Java 17).
3. Runs step 2 with `tomcat_candidate_manual_control=true`, which leaves the candidate service running on port 9080.
4. Verifies ports 8080/9080 from the controller and waits for user confirmation.
5. After you press Enter, reruns step 2 with `tomcat_candidate_manual_control=false` to promote and clean up.

Ensure port forwarding for 8080 and 9080 is available in `Vagrantfile` (already defined) before running the script.

#### Pre-built baseline box (optional)

If you want to skip the "install Tomcat 9.0.112 / Java 17" phase entirely, run `bin/vagrant-build-baseline.sh`. It provisions the stock Windows 11 box with step 1 of the upgrade playbook and packages it into `boxes/windows11-tomcat9.0.112-java17.box`. You can then `vagrant box add windows11-tomcat112 boxes/windows11-tomcat9.0.112-java17.box` and point your Vagrantfile to that box for demos where you only want to exercise the upgrade/candidate workflow.

#### Upgrade-only script

Once the baseline box is installed (`windows11-tomcat112`), `bin/vagrant-upgrade-demo.sh` drives the rest of the demo using `Vagrantfile-upgrade`:

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

## Dependencies

This role requires:

1. **provision-java role** - Must run before this role to install Java and set `java_home` fact
2. **Ansible collections:**
   - `ansible.windows`
   - `community.windows`

Install collections:
```bash
ansible-galaxy collection install ansible.windows community.windows
```

## License

MIT-0 (see `LICENSE`).

## Author

Created for automated Tomcat deployment on Windows environments.
- Supports custom service accounts via `tomcat_service_account_username` / `tomcat_service_account_password`
- **[Service Accounts](docs/SERVICE-ACCOUNTS.md)** - How to provide Windows service credentials securely
