# Development Environment Setup

This guide explains how to set up a local development environment for testing and contributing to the provision-tomcat Ansible role.

## Overview

The development environment uses:
- **Test Kitchen** - Test harness for infrastructure code
- **Vagrant** - VM provisioning
- **VirtualBox** - Hypervisor for running test VMs
- **Ansible** - Configuration management
- **rbenv** - Ruby version management
- **direnv** - Environment variable management

## Prerequisites

### Required Software

1. **VirtualBox** (7.0 or later)
   - macOS: `brew install --cask virtualbox`
   - Linux: Download from https://www.virtualbox.org/
   - Windows: Download installer from https://www.virtualbox.org/

2. **Vagrant** (2.4 or later)
   - macOS: `brew install vagrant`
   - Linux: Download from https://www.vagrantup.com/
   - Windows: Download installer from https://www.vagrantup.com/

3. **rbenv** (for Ruby version management)
   - macOS: `brew install rbenv ruby-build`
   - Linux:
     ```bash
     git clone https://github.com/rbenv/rbenv.git ~/.rbenv
     git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
     ```
   - Add to your shell profile:
     ```bash
     echo 'eval "$(rbenv init -)"' >> ~/.bashrc  # or ~/.zshrc
     ```

4. **Python 3.9+** with pip
   - macOS: `brew install python`
   - Linux: Usually pre-installed, or `apt install python3 python3-pip`
   - Windows: Download from https://www.python.org/

5. **direnv** (optional but recommended)
   - macOS: `brew install direnv`
   - Linux: `apt install direnv` or download from https://direnv.net/
   - Add to shell profile:
     ```bash
     eval "$(direnv hook bash)"  # or zsh
     ```

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd provision-tomcat
```

### 2. Install Ruby

The project requires Ruby 4.0.0 (specified in `.ruby-version`):

```bash
# Install Ruby 4.0.0
rbenv install 4.0.0

# Set it as the local version for this project
rbenv local 4.0.0

# Verify installation
ruby --version  # Should show ruby 4.0.0
```

### 3. Install Ruby Dependencies

```bash
# Install bundler
gem install bundler

# Install project gems
bundle install
```

This installs:
- `test-kitchen` - Test framework
- `kitchen-ansible` - Ansible provisioner for Kitchen
- `kitchen-ansiblepush` - Push-based Ansible provisioning (for Windows)
- `kitchen-vagrant` - Vagrant driver for Kitchen
- `kitchen-inspec` - InSpec verifier
- `winrm-elevated` - Elevated WinRM support for Windows

### 4. Install Python Dependencies

```bash
# Create virtual environment (optional but recommended)
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install Ansible and dependencies
pip install -r requirements.txt
```

This installs:
- `ansible` - Latest Ansible
- `pywinrm` - Python WinRM library for Windows management

### 5. Install Ansible Collections

```bash
# Install required Ansible collections
ansible-galaxy collection install ansible.windows community.windows
```

### 6. Allow direnv (Optional)

If using direnv:

```bash
direnv allow .
```

This automatically:
- Activates the Python virtual environment
- Sets up environment variables
- Configures paths

## Verification

Verify your setup is complete:

```bash
# Check Ruby
ruby --version
# Expected: ruby 4.0.0...

# Check Kitchen
kitchen version
# Expected: Test Kitchen version X.X.X

# Check Ansible
ansible --version
# Expected: ansible [core 2.X.X]

# Check Python dependencies
python -c "import winrm; print('pywinrm OK')"
# Expected: pywinrm OK

# List Kitchen instances
kitchen list
# Expected: Should show win11, ubuntu-2404, rockylinux9 instances
```

## Running Tests

Once setup is complete, you can run tests:

```bash
# Quick test on Windows 11
make test-win11

# Manual step-by-step
kitchen create default-win11
kitchen converge default-win11
kitchen verify default-win11
kitchen destroy default-win11

# Or all at once
kitchen test default-win11
```

## Common Setup Issues

### VirtualBox Not Working

**Symptom**: VMs fail to start with permission errors

**Solution (macOS)**:
1. Go to System Settings → Privacy & Security
2. Allow Oracle VirtualBox extensions
3. Restart your Mac

**Solution (Linux)**:
```bash
# Add your user to vboxusers group
sudo usermod -aG vboxusers $USER
# Logout and login again
```

### Vagrant Can't Find VirtualBox

**Symptom**: `No usable default provider could be found`

**Solution**:
```bash
# Verify VirtualBox is installed
VBoxManage --version

# Set default provider
export VAGRANT_DEFAULT_PROVIDER=virtualbox
```

### WinRM Connection Failures

**Symptom**: Kitchen can't connect to Windows VMs

**Solution**:
1. Check VM network: `vagrant port`
2. Verify WinRM is enabled in the box
3. Check `.kitchen.yml` WinRM settings (port 5985, plaintext transport)

### Ruby Version Mismatch

**Symptom**: `Your Ruby version is X.X.X, but your Gemfile specified 4.0.0`

**Solution**:
```bash
rbenv local 4.0.0
rbenv rehash
```

### Bundle Install Fails

**Symptom**: Native extension build failures

**Solution** (macOS):
```bash
# Install Xcode command line tools
xcode-select --install

# Then retry
bundle install
```

**Solution** (Linux):
```bash
# Install build essentials
sudo apt install build-essential ruby-dev

# Then retry
bundle install
```

## Directory Structure

After setup, your directory structure should include:

```
provision-tomcat/
├── .kitchen/           # Kitchen working directory (gitignored)
├── .vagrant/           # Vagrant VM state (gitignored)
├── .venv/             # Python virtual env (gitignored)
├── .ruby-version      # Ruby version specification
├── Gemfile            # Ruby dependencies
├── Gemfile.lock       # Locked Ruby dependencies
├── requirements.txt   # Python dependencies
├── .kitchen.yml       # Kitchen configuration
├── Makefile          # Test shortcuts
└── docs/             # Documentation
    ├── DEVELOPMENT-SETUP.md  # This file
    └── TESTING-UPGRADES.md   # Upgrade testing guide
```

## Development Workflow

1. **Make changes** to Ansible roles/tasks
2. **Update tests** if needed (tests/playbook.yml)
3. **Run quick test**: `make converge-win11`
4. **Verify changes**: `make verify-win11`
5. **Full test**: `make test-win11` (creates fresh VM)
6. **Cleanup**: `make destroy-win11`

## Environment Variables

The project uses these environment variables (managed by direnv):

- `DISABLE_BUNDLER_SETUP=1` - Prevents Bundler auto-setup
- `KITCHEN_YAML` - Path to Kitchen config (defaults to `.kitchen.yml`)
- `RBENV_VERSION` - Ruby version (from `.ruby-version`)

## Performance Tips

### Speed Up VM Creation

1. **Pre-download boxes**:
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

3. **Use snapshots** for iterative testing:
   ```bash
   vagrant snapshot save <name>
   vagrant snapshot restore <name>
   ```

### Reduce Ansible Output

Edit `ansible.cfg`:
```ini
[defaults]
stdout_callback = yaml  # or minimal
```

## Next Steps

- Read [TESTING-UPGRADES.md](TESTING-UPGRADES.md) for upgrade testing procedures
- Review [README.md](../README.md) for role documentation
- Check `Makefile` for available test targets
- Explore `.kitchen.yml` for test suite configurations

## Getting Help

If you encounter issues:

1. Check logs: `.kitchen/logs/kitchen.log`
2. Run with verbose output: `kitchen converge <instance> -l debug`
3. SSH into VM: `kitchen login <instance>`
4. Destroy and retry: `kitchen destroy <instance>` then `kitchen test <instance>`

## Contributing

When contributing:

1. Ensure all tests pass on your platform
2. Test on at least Windows 11 (primary target)
3. Update documentation if adding features
4. Follow existing code style and conventions
