# Testing Tomcat and Java Upgrades

This document explains how to test upgrade and downgrade scenarios for the provision-tomcat and provision-java roles.

## Overview

The roles support:
- **Upgrade**: Installing a newer version over an existing installation
- **Downgrade**: Installing an older version over a newer installation
- **Version retention**: Keeping multiple versions with automatic cleanup
- **Symlink management**: `C:/Tomcat/current` and `C:/java/current` always point to the active version

## Quick Start

### Option 1: Using Makefile (Recommended)

Test a complete upgrade scenario on Windows 11:

```bash
make test-upgrade-win11
```

This will:
1. Install Tomcat 9.0.112 with Java 21
2. Upgrade to Tomcat 9.0.113 (same Java version)
3. Verify both installations work correctly

Cleanup when done:
```bash
make upgrade-cleanup-win11
```

### Option 2: Using Kitchen Directly

**Step 1: Install initial version (9.0.112)**
```bash
rbenv exec kitchen create upgrade-win11
rbenv exec kitchen converge upgrade-win11
rbenv exec kitchen verify upgrade-win11
```

**Step 2: Upgrade to newer version (9.0.113)**
```bash
rbenv exec kitchen converge upgrade-win11 --provisioner-extra-vars="upgrade_step=2"
rbenv exec kitchen verify upgrade-win11
```

**Step 3: Inspect or cleanup**
```bash
# Login to inspect the VM
rbenv exec kitchen login upgrade-win11

# Or destroy it
rbenv exec kitchen destroy upgrade-win11
```

### Option 3: Using the Test Script

Run the interactive test script:

```bash
./test-upgrade.sh
```

## What Gets Tested

### Upgrade Scenario

1. **Initial Install (Step 1)**:
   - Installs Tomcat 9.0.112
   - Installs Java 21
   - Creates symlinks: `C:/Tomcat/current` → `C:/Tomcat/apache-tomcat-9.0.112`
   - Creates symlinks: `C:/java/current` → `C:/java/jdk-21`
   - Installs and starts Windows service

2. **Upgrade (Step 2)**:
   - Stops existing Tomcat service
   - Uninstalls old service registration
   - Removes old symlink
   - Downloads and extracts Tomcat 9.0.113
   - Creates new symlink: `C:/Tomcat/current` → `C:/Tomcat/apache-tomcat-9.0.113`
   - Reinstalls service with new version
   - Starts service
   - Both versions kept (9.0.112 and 9.0.113)

### Version Retention

The roles keep the 10 most recent versions by default (configurable via `tomcat_keep_versions` and `java_keep_versions`). Older versions are automatically deleted.

## Manual Testing

### Test Different Version Combinations

You can test specific version combinations:

```bash
# Test downgrade: 9.0.113 → 9.0.112
rbenv exec kitchen converge upgrade-win11 -e tomcat_version=9.0.113
rbenv exec kitchen converge upgrade-win11 -e tomcat_version=9.0.112

# Test Java version changes
rbenv exec kitchen converge upgrade-win11 -e jdk_version=21
rbenv exec kitchen converge upgrade-win11 -e jdk_version=17  # Not recommended but supported
```

### Verify Installation

After each converge, check:

```bash
# Login to the VM
rbenv exec kitchen login upgrade-win11

# On the Windows VM:
# 1. Check Tomcat version
cd C:\Tomcat\current
type RELEASE-NOTES

# 2. Check Java version
C:\java\current\bin\java.exe -version

# 3. Check service status
sc query Tomcat9

# 4. Check HTTP access
curl http://localhost:8080

# 5. List all installed versions
dir C:\Tomcat
dir C:\java

# 6. Check symlinks
dir C:\Tomcat\current
dir C:\java\current
```

## Troubleshooting

### Service Won't Start After Upgrade

The upgrade process should:
1. Stop the old service
2. Uninstall it
3. Install the new service
4. Start it

If the service doesn't start, check:

```powershell
# Check service status
sc query Tomcat9

# Check service configuration
sc qc Tomcat9

# View Tomcat logs
type C:\Tomcat\current\logs\catalina.*.log
```

### Symlink Issues

Symlinks require Administrator privileges. Ensure the test runs with elevated permissions (which Test Kitchen does automatically for Windows).

Check symlink status:

```powershell
# Should show "SYMLINKD"
dir C:\Tomcat
dir C:\java
```

### Old Versions Not Cleaned Up

The cleanup only runs when `tomcat_keep_versions` or `java_keep_versions` is set and exceeded. Check:

```yaml
# In defaults/main.yml
tomcat_keep_versions: 10  # Keep 10 versions
java_keep_versions: 10    # Keep 10 versions
```

## Test Suites

The `.kitchen.yml` defines several test suites:

- `default`: Fresh installation with latest version
- `upgrade`: Two-step upgrade test (9.0.112 → 9.0.113)
- `idempotence`: Runs converge twice to verify idempotency
- `no-autostart`: Tests installation without auto-starting the service

## Platform Support

Upgrade testing is currently configured for:
- ✅ Windows 11
- 🔄 Ubuntu 24.04 (Linux support planned)
- 🔄 Rocky Linux 9 (Linux support planned)

## Files

- `.kitchen.yml`: Test Kitchen configuration with upgrade suite
- `tests/playbook-upgrade.yml`: Ansible playbook for upgrade scenarios
- `Makefile`: Targets for automated testing
- `test-upgrade.sh`: Interactive test script

## Next Steps

After testing upgrades, consider:
1. Testing with different Tomcat major versions (8 → 9, 9 → 10)
2. Testing Java major version upgrades (17 → 21)
3. Testing rollback scenarios
4. Automating upgrade tests in CI/CD
