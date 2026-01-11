# Test Kitchen Guide

This guide explains how to use Test Kitchen for testing the provision-tomcat Ansible role.

## Overview

Test Kitchen is a test harness that allows you to execute your infrastructure code on one or more platforms in isolation. This project uses:

- **Test Kitchen** - Test framework
- **Vagrant Driver** - Creates VMs via Vagrant/VirtualBox
- **Ansible Provisioner** - Runs Ansible playbooks
- **Shell Verifier** - Validates installation

## Quick Reference

### Common Commands

```bash
# List all test instances
kitchen list

# Create a VM (without provisioning)
kitchen create <instance>

# Run Ansible provisioning
kitchen converge <instance>

# Run verification tests
kitchen verify <instance>

# SSH into VM
kitchen login <instance>

# Destroy VM
kitchen destroy <instance>

# Full test cycle (create + converge + verify + destroy)
kitchen test <instance>
```

### Using Makefile Shortcuts

The project includes a Makefile with convenient shortcuts:

```bash
# Quick test on Windows 11 (default suite)
make test-win11

# Test specific suite
make test-upgrade-win11
make test-idempotence-win11
make test-no-autostart-win11

# Step-by-step testing
make converge-win11    # Provision
make verify-win11      # Verify
make destroy-win11     # Cleanup

# List all available targets
make help
```

## Test Suites

The project defines multiple test suites in `.kitchen.yml`:

### 1. Default Suite

**Purpose**: Basic installation with auto-start enabled

**Usage**:
```bash
kitchen test default-win11
# or
make test-win11
```

**What it tests**:
- Fresh Tomcat installation
- Service auto-start
- HTTP accessibility on port 8080
- Firewall configuration

**Variables**:
- `tomcat_version: "9.0.113"`
- `tomcat_auto_start: true`

### 2. Upgrade Suite

**Purpose**: Multi-step upgrade testing (9.0.112 → 9.0.113)

**Usage**:
```bash
make test-upgrade-win11
```

**What it tests**:
- Step 1: Install Tomcat 9.0.112
- Step 2: Upgrade to 9.0.113
- Symlink management during upgrades
- Service restart during upgrades
- Version retention policy

**Configuration**: Uses `tests/playbook-upgrade.yml` with `upgrade_step` variable

See [TESTING-UPGRADES.md](TESTING-UPGRADES.md) for detailed upgrade testing documentation.

### 3. Idempotence Suite

**Purpose**: Verify role is idempotent (no changes on second run)

**Usage**:
```bash
kitchen test idempotence-win11
# or
make test-idempotence-win11
```

**What it tests**:
- First run: installs Tomcat
- Second run: should make no changes
- Ensures role is production-safe

**Configuration**: Sets `idempotency_test: true` in provisioner

### 4. No-Autostart Suite

**Purpose**: Test installation without starting service

**Usage**:
```bash
kitchen test no-autostart-win11
# or
make test-no-autostart-win11
```

**What it tests**:
- Tomcat installs successfully
- Service is NOT started automatically
- Service CAN be started manually

**Variables**:
- `tomcat_version: "9.0.113"`
- `tomcat_auto_start: false`

## Platforms

The `.kitchen.yml` defines three platforms:

### Windows 11 (Primary)

```yaml
- name: win11
  driver_config:
    box: stromweld/windows-11
    communicator: winrm
```

**Features**:
- WinRM communication (port 5985)
- Ansible push provisioner
- Port forwarding: 8080 → host
- Primary target for Tomcat testing

**Example**:
```bash
kitchen test default-win11
```

### Ubuntu 24.04 (Linux)

```yaml
- name: ubuntu-2404
  driver_config:
    box: hashicorp-education/ubuntu-24-04
```

**Features**:
- SSH communication
- Ansible playbook provisioner
- Future Linux support planned

**Example**:
```bash
kitchen test default-ubuntu-2404
```

### Rocky Linux 9 (RHEL-based)

```yaml
- name: rockylinux9
  driver_config:
    box: rockylinux/9
```

**Features**:
- SSH communication
- Enterprise Linux testing
- Future RHEL/CentOS support

**Example**:
```bash
kitchen test default-rockylinux9
```

## Instance Naming

Test Kitchen instances are named: `<suite>-<platform>`

Examples:
- `default-win11` - Default suite on Windows 11
- `upgrade-win11` - Upgrade suite on Windows 11
- `idempotence-ubuntu-2404` - Idempotence suite on Ubuntu
- `no-autostart-rockylinux9` - No-autostart suite on Rocky Linux

## Workflow Examples

### Basic Testing Workflow

**Scenario**: Test a change on Windows 11

```bash
# 1. Create VM
kitchen create default-win11

# 2. Make changes to Ansible code
vim tasks/install-Windows-tomcat.yml

# 3. Apply changes
kitchen converge default-win11

# 4. Verify it works
kitchen verify default-win11

# 5. Login to inspect (optional)
kitchen login default-win11

# 6. Clean up
kitchen destroy default-win11
```

### Rapid Iteration Workflow

**Scenario**: Debugging a failing task

```bash
# Keep VM running, repeatedly converge
kitchen create default-win11

# Edit, converge, repeat
vim tasks/install-Windows-tomcat.yml
kitchen converge default-win11

# Check logs on VM
kitchen login default-win11
# On VM: Check C:\Tomcat\logs\

# Fix and retry
vim tasks/install-Windows-tomcat.yml
kitchen converge default-win11

# When done
kitchen destroy default-win11
```

### Full Test Suite

**Scenario**: Test all suites before committing

```bash
# Test all suites on Windows 11
make test-all-win11

# Or individually
make test-default-win11
make test-upgrade-win11
make test-idempotence-win11
make test-no-autostart-win11
```

### Parallel Testing

**Scenario**: Test multiple platforms simultaneously

```bash
# Start tests in parallel (different terminals)
kitchen test default-win11 &
kitchen test default-ubuntu-2404 &
kitchen test default-rockylinux9 &

# Or use parallel command
parallel kitchen test ::: default-win11 default-ubuntu-2404 default-rockylinux9
```

## Configuration Files

### .kitchen.yml

Main configuration file defining:
- Driver settings (Vagrant/VirtualBox)
- Provisioner settings (Ansible)
- Platform definitions (Windows, Ubuntu, Rocky)
- Suite definitions (default, upgrade, etc.)
- Verifier settings (shell commands)

**Location**: Project root

**Example snippet**:
```yaml
driver:
  name: vagrant
  driver: virtualbox

provisioner:
  name: ansible_playbook
  playbook: tests/playbook.yml
  roles_path: ..

platforms:
  - name: win11
    # ... platform config

suites:
  - name: default
    # ... suite config
```

### .kitchen.local.yml (Optional)

Override settings for local development:

**Example**:
```yaml
---
driver:
  customize:
    memory: 8192
    cpus: 4
```

**Note**: This file is gitignored and used for temporary overrides.

### tests/playbook.yml

Default test playbook that:
1. Includes `windows-base` role (Windows prerequisites)
2. Includes `provision-java` role (Java installation)
3. Includes `provision-tomcat` role (Tomcat installation)

**Location**: `tests/playbook.yml`

### tests/playbook-upgrade.yml

Upgrade test playbook that:
1. Uses `upgrade_step` variable to control versions
2. Installs old version (step 1)
3. Upgrades to new version (step 2)

**Location**: `tests/playbook-upgrade.yml`

See [TESTING-UPGRADES.md](TESTING-UPGRADES.md) for details.

## Debugging

### View Logs

**Kitchen logs**:
```bash
# Main log
cat .kitchen/logs/kitchen.log

# Instance-specific log
cat .kitchen/logs/<instance>.log
```

**Ansible verbose output**:
```bash
# Converge with debug output
kitchen converge default-win11 -l debug
```

### SSH/WinRM into VM

**Windows (WinRM)**:
```bash
kitchen login default-win11

# On Windows VM:
cd C:\Tomcat\current
type logs\catalina*.log
```

**Linux (SSH)**:
```bash
kitchen login default-ubuntu-2404

# On Linux VM:
cd /opt/tomcat
cat logs/catalina.out
```

### Check VM Status

```bash
# Kitchen status
kitchen list

# Vagrant status
cd .kitchen
vagrant status

# VirtualBox VMs
VBoxManage list runningvms
```

### Common Issues

#### VM Won't Start

**Symptom**: `Error: VBoxManage returned an error code`

**Solutions**:
```bash
# Check VirtualBox is running
VBoxManage --version

# Check for conflicting VMs
VBoxManage list vms

# Destroy and retry
kitchen destroy <instance>
kitchen create <instance>
```

#### WinRM Connection Timeout

**Symptom**: `Waiting for WinRM... timeout`

**Solutions**:
```bash
# Check port forwarding
vagrant port

# Verify WinRM is enabled in box
kitchen login <instance>  # Should work after VM boots

# Increase timeout in .kitchen.yml
provisioner:
  connection_timeout: 600
```

#### Converge Fails Mid-Run

**Symptom**: Ansible task fails, VM is partially configured

**Solutions**:
```bash
# Fix the issue in Ansible code
vim tasks/...

# Re-run converge (idempotent)
kitchen converge <instance>

# Or start fresh
kitchen destroy <instance>
kitchen test <instance>
```

#### Out of Disk Space

**Symptom**: VM creation fails with disk space error

**Solutions**:
```bash
# Remove old VMs
kitchen destroy --all

# Clean up Vagrant boxes
vagrant box prune

# Check VirtualBox VMs
VBoxManage list vms
# Delete orphaned VMs
VBoxManage unregistervm <uuid> --delete
```

## Advanced Usage

### Custom Variables

Pass extra variables to Ansible:

**Using Kitchen**:
```bash
kitchen converge default-win11 --provisioner-extra-vars="tomcat_version=9.0.120"
```

**Using Makefile override**:
```bash
# Edit Makefile or create .kitchen.local.yml
echo "suites:" > .kitchen.local.yml
echo "  - name: default" >> .kitchen.local.yml
echo "    provisioner:" >> .kitchen.local.yml
echo "      extra_vars:" >> .kitchen.local.yml
echo "        tomcat_version: 9.0.120" >> .kitchen.local.yml

kitchen converge default-win11
```

### Running Specific Tasks

Use Ansible tags:

```bash
# .kitchen.yml provisioner section
provisioner:
  ansible_extra_flags: --tags tomcat-install

# Or via command line (not directly supported, edit .kitchen.yml)
```

### Saving VM State

Use Vagrant snapshots for faster testing:

```bash
# Create VM and snapshot
kitchen create default-win11
kitchen converge default-win11
cd .kitchen/default-win11
vagrant snapshot save baseline

# Restore to snapshot
vagrant snapshot restore baseline

# List snapshots
vagrant snapshot list
```

### Testing with Different Ansible Versions

```bash
# Install specific Ansible version
pip install ansible==2.14.0

# Run tests
kitchen test default-win11

# Restore latest
pip install --upgrade ansible
```

## Performance Tips

### Speed Up Tests

1. **Pre-download Vagrant boxes**:
   ```bash
   vagrant box add stromweld/windows-11
   vagrant box add hashicorp-education/ubuntu-24-04
   vagrant box add rockylinux/9
   ```

2. **Increase VM resources** (edit `.kitchen.yml`):
   ```yaml
   driver:
     customize:
       memory: 4096
       cpus: 2
   ```

3. **Use local box cache**:
   ```bash
   export VAGRANT_HOME=~/.vagrant.d
   ```

4. **Keep VMs running** during development:
   ```bash
   # Don't destroy, just converge repeatedly
   kitchen create default-win11
   # Edit, converge, edit, converge...
   kitchen converge default-win11
   # When done
   kitchen destroy default-win11
   ```

5. **Run tests in parallel** (different suites/platforms):
   ```bash
   # Terminal 1
   kitchen test default-win11

   # Terminal 2
   kitchen test idempotence-win11
   ```

### Reduce Ansible Output

Edit `ansible.cfg`:
```ini
[defaults]
stdout_callback = yaml  # More concise than default
# or
stdout_callback = minimal  # Very concise
```

Or in `.kitchen.yml`:
```yaml
provisioner:
  ansible_verbosity: 0  # 0=normal, 1=verbose, 2=very verbose
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Test Kitchen

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest  # VirtualBox support

    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          brew install rbenv vagrant virtualbox
          rbenv install
          bundle install

      - name: Run tests
        run: |
          kitchen test default-ubuntu-2404
```

**Note**: Windows testing requires nested virtualization, typically not available in CI environments.

## Cleanup

### Remove All Test VMs

```bash
# Using Kitchen
kitchen destroy --all

# Using Makefile
make destroy-win11
make destroy-ubuntu-2404
make destroy-rockylinux9

# Or destroy all manually
cd .kitchen
vagrant destroy -f
cd ..
```

### Clean Kitchen State

```bash
# Remove Kitchen state
rm -rf .kitchen/

# Remove Vagrant state
rm -rf .vagrant/

# Start fresh
kitchen list
```

### Clean Old Boxes

```bash
# List boxes
vagrant box list

# Remove specific box
vagrant box remove stromweld/windows-11

# Prune old versions
vagrant box prune
```

## Best Practices

1. **Always test on clean VMs** - Run `kitchen test` (not just `converge`) to ensure reproducibility

2. **Use appropriate suites** - Test specific scenarios (upgrade, idempotence) when making relevant changes

3. **Commit test changes** - Update `tests/playbook.yml` when adding role features

4. **Document test failures** - If a test fails, note it in issue/PR for investigation

5. **Test on target platform** - Windows is the primary platform, always test on `win11` first

6. **Keep VMs clean** - Destroy VMs regularly to avoid state accumulation

7. **Use version control** - Don't commit `.kitchen/` or `.kitchen.local.yml`

8. **Verify before destroying** - Run `kitchen verify` to catch issues before cleanup

## See Also

- **[Development Setup](DEVELOPMENT-SETUP.md)** - Initial environment setup
- **[Testing Upgrades](TESTING-UPGRADES.md)** - Upgrade and downgrade testing procedures
- **[README.md](../README.md)** - Role documentation and usage
- **[Test Kitchen Docs](https://kitchen.ci/)** - Official Test Kitchen documentation
