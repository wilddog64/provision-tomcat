# Provision Tomcat Role

This Ansible role installs Apache Tomcat on Windows hosts via Chocolatey. It assumes the `windows-base` role has already installed/configured Chocolatey in a known location.

## Requirements

- Control node: Python 3.9+, Ansible 2.14+, and the `chocolatey.chocolatey` collection.
- Target node: Windows accessible over WinRM with admin rights.
- Chocolatey present on the target (run the `windows-base` role first).

## Role Variables

Default variables (`defaults/main.yml`):

| Variable | Default | Description |
| --- | --- | --- |
| `tomcat_package_name` | `tomcat` | Chocolatey package to install. |
| `tomcat_service_name` | `Tomcat9` | Windows service name to manage. |
| `tomcat_state` | `present` | Chocolatey package state: `present` (install if not present) or `latest` (install and upgrade to newest version). |
| `tomcat_version` | `null` | (Optional) Specific version to install (e.g., `9.0.113`). **Note:** Only works if that version is available in the Chocolatey repository. |
| `tomcat_choco_args` | `[]` | Additional Chocolatey arguments (list). |

## Behavior

The role is designed to be **idempotent** and **production-safe**:

1. **Checks if Tomcat is already installed** - Queries the Windows service to see if Tomcat exists
2. **Installs or upgrades based on `tomcat_state`:**
   - `tomcat_state: present` (default) - Installs if not present, skips if service already exists
   - `tomcat_state: latest` - Installs if not present, upgrades to newest version if available
3. **Ensures service is running** - After installation/upgrade, ensures the Tomcat service is started
4. **Verifies and reports** - Displays service status and provides access information

**Default behavior (`tomcat_state: present`):**
- Initial install: Installs Tomcat
- Subsequent runs: Skips installation (service exists), only ensures it's running
- No automatic upgrades unless explicitly requested

**Upgrade behavior (`tomcat_state: latest`):**
- Runs `win_chocolatey` with `state: latest`
- Chocolatey checks for newer versions and upgrades if available
- Service is restarted after upgrade

**Version pinning (`tomcat_version: "x.y.z"`):**
- When `tomcat_version` is set, the role attempts to install that specific version
- Overrides `tomcat_state` behavior - uses the version you specify
- **Note:** The Chocolatey community repository may only keep the latest version available. To verify available versions, run:
  ```powershell
  choco search tomcat --all-versions
  ```
- If only the latest version is available, version pinning won't work as expected
- For true version pinning, consider:
  - Using an internal Chocolatey repository with multiple versions cached
  - Using a different installation method (e.g., downloading specific Tomcat archives directly)

This design avoids unnecessary reinstalls that could cause downtime in production.

## Upgrade Procedures

Both Tomcat and Java can be upgraded using the same pattern. Since Tomcat typically requires a compatible Java version, it's common to upgrade both together.

### Related Variables

**Tomcat Upgrade Variables:**

| Variable | Default | Description |
| --- | --- | --- |
| `tomcat_state` | `present` | Set to `latest` to upgrade Tomcat to the newest version available in Chocolatey repository |
| `tomcat_version` | `null` | Set to a specific version (e.g., `"9.0.95"`) to install/upgrade to that exact version (if available in repository) |

**Java Upgrade Variables:**

| Variable | Default | Description |
| --- | --- | --- |
| `java_state` | `present` | Set to `latest` to upgrade Java to the newest version available in Chocolatey repository |
| `java_version` | `21` | Major Java version (e.g., `11`, `17`, `21`) - changes the package name to `microsoft-openjdk-{version}` |
| `java_package_version` | `null` | Set to a specific version (e.g., `"21.0.5"`) to install/upgrade to that exact version (if available in repository) |
| `java_install_dir` | `c:\java` | Installation directory - remains consistent across upgrades |

### Upgrade Scenarios

#### Scenario 1: Upgrade Both Tomcat and Java to Latest Versions

**Recommended for:** Development/testing environments, scheduled maintenance windows

**Playbook:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    java_state: latest
    tomcat_state: latest
  roles:
    - windows-base
    - provision-java
    - provision-tomcat
```

**What happens:**
1. Checks current Java installation
2. If newer Java version available, upgrades in-place
3. Updates `JAVA_HOME` and PATH
4. Checks current Tomcat installation
5. If newer Tomcat version available, upgrades in-place
6. Restarts Tomcat service with new versions

**Command:**
```bash
ansible-playbook -i inventory playbook.yml --extra-vars "java_state=latest tomcat_state=latest"
```

#### Scenario 2: Upgrade Only Tomcat (Keep Java as-is)

**Recommended for:** Tomcat security patches, when Java version is stable

**Playbook:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_state: latest
    # java_state defaults to 'present' - no Java upgrade
  roles:
    - windows-base
    - provision-java    # Ensures Java is present, no upgrade
    - provision-tomcat  # Upgrades Tomcat
```

**Command:**
```bash
ansible-playbook -i inventory playbook.yml --extra-vars "tomcat_state=latest"
```

#### Scenario 3: Upgrade Only Java (Keep Tomcat as-is)

**Recommended for:** Java security patches, when Tomcat version is stable

**Playbook:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    java_state: latest
    # tomcat_state defaults to 'present' - no Tomcat upgrade
  roles:
    - windows-base
    - provision-java    # Upgrades Java
    - provision-tomcat  # Ensures Tomcat is present, no upgrade
```

**Command:**
```bash
ansible-playbook -i inventory playbook.yml --extra-vars "java_state=latest"
```

#### Scenario 4: Upgrade to Specific Versions

**Recommended for:** Production environments requiring specific tested versions

**Playbook:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    java_version: 21
    java_package_version: "21.0.5"  # Specific Java build (if available)
    tomcat_version: "9.0.95"        # Specific Tomcat version (if available)
  roles:
    - windows-base
    - provision-java
    - provision-tomcat
```

**Important Notes:**
- Chocolatey community repository typically only keeps the latest version
- Verify versions are available first:
  ```powershell
  choco search microsoft-openjdk-21 --all-versions
  choco search tomcat --all-versions
  ```
- For true version pinning, use an internal Chocolatey repository with cached versions

**Command:**
```bash
ansible-playbook -i inventory playbook.yml \
  --extra-vars "java_version=21 java_package_version=21.0.5 tomcat_version=9.0.95"
```

#### Scenario 5: Major Java Version Upgrade (e.g., Java 17 → Java 21)

**Recommended for:** Planned major upgrades, after compatibility testing

**Playbook:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    java_version: 21          # Change major version
    java_state: latest        # Get latest build of Java 21
    tomcat_state: latest      # Upgrade Tomcat to ensure compatibility
  roles:
    - windows-base
    - provision-java
    - provision-tomcat
```

**What happens:**
1. Installs `microsoft-openjdk-21` (different package from `microsoft-openjdk-17`)
2. Updates `JAVA_HOME` to point to new Java 21 installation
3. Upgrades Tomcat to latest version (ensures compatibility with Java 21)
4. Restarts Tomcat with new Java version

**Command:**
```bash
ansible-playbook -i inventory playbook.yml \
  --extra-vars "java_version=21 java_state=latest tomcat_state=latest"
```

### Verification After Upgrade

After running upgrades, verify the versions:

**Check Java version:**
```bash
vagrant ssh -c "powershell.exe -Command 'java -version'"
```

**Check Tomcat version:**
```bash
vagrant ssh -c "powershell.exe -Command 'choco list tomcat --local-only'"
```

**Check services are running:**
```bash
vagrant ssh -c "powershell.exe -Command 'Get-Service Tomcat9'"
```

**Check Tomcat is accessible:**
```bash
curl http://localhost:8080
```

### Upgrade Best Practices

1. **Test in non-production first** - Always test upgrades in development/staging before production
2. **Check compatibility** - Verify Java and Tomcat versions are compatible (Tomcat 9 requires Java 8+, Tomcat 10 requires Java 11+)
3. **Backup configuration** - Although roles preserve configuration, backup `server.xml` and webapps before major upgrades
4. **Monitor logs** - Check Tomcat logs after upgrade: `C:\Program Files\Apache Software Foundation\Tomcat 9.0\logs\`
5. **Version pinning for production** - Use specific versions in production rather than `state: latest`
6. **Coordinate Java/Tomcat upgrades** - When upgrading Java, consider upgrading Tomcat too for compatibility

### Rollback Procedure

If an upgrade causes issues:

**Option 1: Re-run with previous versions**
```bash
ansible-playbook -i inventory playbook.yml \
  --extra-vars "java_package_version=21.0.3 tomcat_version=9.0.90"
```

**Option 2: Manual rollback via Chocolatey**
```powershell
# On the Windows host
choco uninstall tomcat --yes
choco install tomcat --version=9.0.90 --yes

choco uninstall microsoft-openjdk-21 --yes
choco install microsoft-openjdk-21 --version=21.0.3 --yes
```

**Option 3: Restore from VM snapshot** (if using Vagrant/VirtualBox)
```bash
vagrant snapshot list
vagrant snapshot restore <snapshot-name>
```

## Known Issues

### Chocolatey Tomcat Package Bug

The Chocolatey `tomcat` package (v9.0.113 and possibly other versions) has a bug in its installation script (`chocolateyInstall.ps1`) that can cause installation failures:

**Symptom:**
```
ERROR: The running command stopped because the preference variable "ErrorActionPreference"
or common parameter is set to Stop: The system cannot find the file specified.

(32) The process cannot access the file because it is being used by another process:
[\\?\C:\choco\lib\Tomcat\.chocolateyPending]
```

**Root Cause:**
During installation, the Chocolatey package attempts to:
1. Remove any existing Tomcat9 service
2. Install new files
3. Register the service again

However, when reinstalling over an existing installation, the package's cleanup logic can create file locks (specifically the `.chocolateyPending` file) that prevent the installation from completing.

**Workaround:**
This role avoids triggering the bug by:
- Detecting if Tomcat is already installed (service exists)
- Skipping the Chocolatey install step if Tomcat is present
- Only running installation on fresh systems (no existing Tomcat service)

For forced upgrades, use `tomcat_force_install: true`, but be aware this may trigger the bug if the existing installation is in a certain state.

### How Chocolatey Handles Tomcat Upgrades

**Normal Chocolatey Upgrade Behavior:**
```powershell
choco upgrade tomcat
```

Chocolatey should perform an in-place upgrade:
1. Download the new version
2. Stop the Tomcat service
3. Replace binaries in `C:\Program Files\Apache Software Foundation\Tomcat 9.0\`
4. Update service configuration if needed
5. Start the service

**The Problem with Tomcat Package:**
The Tomcat Chocolatey package's `chocolateyInstall.ps1` script attempts to:
1. **Remove the Windows service** (`sc delete Tomcat9`)
2. Extract new files
3. **Re-register the service**

This remove/re-register approach (instead of an in-place upgrade) is what triggers the file lock bug, especially when:
- The service is running
- Files are in use
- Previous installations left orphaned state

**Upgrade Strategies with This Role:**

**Option 1: Use `tomcat_state: latest` (Recommended for Automation)**
```yaml
# In your playbook
- hosts: windows
  vars:
    tomcat_state: latest
  roles:
    - provision-tomcat
```

Setting `tomcat_state: latest` tells the role to ensure the latest version:
- Checks if Tomcat is installed
- If not installed: Downloads and installs the latest version
- If installed: Checks for newer version and upgrades if available
- Always ensures service is running

**How it works:**
1. The role checks if Tomcat service exists
2. Runs `win_chocolatey` with `state: latest`
3. Chocolatey checks if a newer version exists on the repository
4. If yes, downloads and upgrades in-place
5. Service is restarted after upgrade

**Note:** This may still trigger the package bug during upgrade since the Chocolatey package removes/re-registers the service. Test in a non-production environment first.

**Option 2: Manual Upgrade (Safest for Production)**
```bash
# SSH into the Windows VM
vagrant ssh

# On the Windows machine
powershell.exe
Stop-Service Tomcat9
choco upgrade tomcat --yes
Start-Service Tomcat9
```

**Option 3: Uninstall/Reinstall (Causes Downtime)**
```yaml
# First playbook: Uninstall
- hosts: windows
  tasks:
    - name: Uninstall Tomcat
      win_chocolatey:
        name: tomcat
        state: absent

# Second run: Install new version
- hosts: windows
  roles:
    - provision-tomcat
```

**Recommendation:**
- **Development/Testing:** Use `tomcat_state: latest` for automated upgrades
- **Production:** Manual upgrades give you more control and allow testing before/after
- **CI/CD:** Consider the uninstall/reinstall approach for predictable state

**Clean Recovery from Corrupted State:**
If you encounter this error, the cleanest solution is:
```bash
vagrant destroy -f
vagrant up
```

Alternatively, manually clean the VM:
```powershell
# On the Windows VM
Stop-Service Tomcat9 -Force -ErrorAction SilentlyContinue
choco uninstall tomcat --yes --force
Remove-Item -Path "C:\choco\lib\Tomcat" -Recurse -Force -ErrorAction SilentlyContinue
```

## Tasks Overview

`tasks/install-Windows-tomcat.yml` performs the following steps:

1. **Verify Java is installed** - Checks that `java_home` fact exists (from `provision-java` role)
2. **Check for existing Tomcat** - Queries Windows service to see if Tomcat is already installed
3. **Install Tomcat** - Runs `win_chocolatey` to install Tomcat (only if not already present or if `tomcat_force_install: true`)
4. **Wait for service** - After installation, waits for the Tomcat service to exist
5. **Ensure service is started** - Starts the Tomcat service with retries
6. **Verify and report status** - Displays the final service state

The tasks only run when `ansible_facts.os_family == 'Windows'`.

## Example Playbook

**Basic Installation (default behavior):**
```yaml
---
- hosts: windows
  gather_facts: yes
  roles:
    - windows-base        # Installs Chocolatey
    - provision-java      # Installs Java (required dependency)
    - provision-tomcat    # Installs Tomcat (state: present)
```

**With Automatic Upgrades:**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_state: latest  # Ensure latest version is installed
  roles:
    - windows-base
    - provision-java
    - provision-tomcat
```

**With Specific Version (if available in repository):**
```yaml
---
- hosts: windows
  gather_facts: yes
  vars:
    tomcat_version: "9.0.113"  # Install specific version (if available)
  roles:
    - windows-base
    - provision-java
    - provision-tomcat
```

**Note:** Check available versions first with `choco search tomcat --all-versions` to ensure the version exists in the repository.

**With Verification:**
```yaml
---
- hosts: windows
  gather_facts: yes
  roles:
    - windows-base
    - provision-java
    - provision-tomcat

# Verify Tomcat is accessible from the host machine
- name: Verify Tomcat accessibility
  hosts: localhost
  connection: local
  gather_facts: no
  tasks:
    - name: Check Tomcat HTTP response
      shell: curl -s -o /dev/null -w "%{http_code}" http://localhost:8080
      register: http_check
      failed_when: false

    - name: Report status
      debug:
        msg: "Tomcat HTTP status: {{ http_check.stdout | default('no response') }}"
```

**Note:** Tomcat requires Java to be installed first. Always include the `provision-java` role before `provision-tomcat`.

## Local Testing

This role uses Test Kitchen with the Vagrant driver for automated testing.

### Test Suites

Three test suites are available:

1. **default** - Tests basic installation with `tomcat_state: present`
   - Verifies Tomcat service is running
   - Verifies Tomcat responds on port 8080
   - Confirms idempotent behavior (no changes on second run)

2. **latest** - Tests automatic upgrades with `tomcat_state: latest`
   - Installs/upgrades to latest version
   - Verifies service is running
   - Checks installed version matches Chocolatey repository

3. **idempotence** - Tests that the role is truly idempotent
   - Runs playbook twice (via `idempotency_test: true`)
   - Verifies service remains running
   - Ensures no changes on second run

**Note on version pinning tests:**
Version pinning (`tomcat_version: "x.y.z"`) is not included in automated tests because the Chocolatey community repository typically only keeps the latest version. To test version pinning:
1. Set up an internal Chocolatey repository with multiple cached versions
2. Modify the test suite to use your repository
3. Add a suite with `tomcat_version` set to a known available version

### Running Tests

**Run all suites:**
```bash
kitchen test
```

**Run specific suite:**
```bash
kitchen test default-win11
kitchen test latest-win11
kitchen test idempotence-win11
```

**Step-by-step testing:**
```bash
kitchen create default-win11    # Create VM
kitchen converge default-win11  # Run Ansible
kitchen verify default-win11    # Run tests
kitchen destroy default-win11   # Clean up
```

**Using Make targets:**
```bash
# Test all suites on Windows 11
make test-all-win11

# Test specific suite
make test-default-win11
make test-latest-win11
make test-idempotence-win11

# Step-by-step
make converge-win11           # Run Ansible provisioning
make verify-win11             # Run verification tests
make destroy-win11            # Destroy all win11 instances

# See all available targets
make help
```

**On Windows PowerShell:**
```powershell
$env:KITCHEN_YAML=".kitchen-win.yml"
make test-all-win11
```

## License

Apache-2.0 (see `LICENSE`).
