# Tomcat Upgrade/Downgrade Testing Guide

This guide explains how to test the upgrade and downgrade functionality for both Tomcat and Java.

## Prerequisites

- Test Kitchen configured
- Vagrant with VirtualBox
- Windows 11 VM box available

## Test Scenarios

### Scenario 1: Tomcat Upgrade (9.0.113 → 9.0.120)

**Step 1: Create VM and install old version**
```bash
# Destroy any existing instance
rbenv exec kitchen destroy default-win11

# Create and converge with old version
rbenv exec kitchen create default-win11
rbenv exec kitchen converge default-win11
```

This installs Tomcat 9.0.113 (defined in `.kitchen.yml`)

**Step 2: Verify initial installation**
```bash
# Login to VM
rbenv exec kitchen login default-win11

# Check installed version
ls C:\Tomcat

# Should see:
# - apache-tomcat-9.0.113/
# - current -> apache-tomcat-9.0.113

# Check symlink
cmd /c dir C:\Tomcat

# Check service
Get-Service Tomcat9

# Check CATALINA_HOME
[Environment]::GetEnvironmentVariable("CATALINA_HOME", "Machine")
# Should be: C:/Tomcat/current

# Exit VM
exit
```

**Step 3: Upgrade to new version**
```bash
# Edit .kitchen.yml and change tomcat_version from "9.0.113" to "9.0.120"
sed -i '' 's/tomcat_version: "9.0.113"/tomcat_version: "9.0.120"/' .kitchen.yml

# Run converge again
rbenv exec kitchen converge default-win11
```

**Step 4: Verify upgrade**
```bash
# Login to VM
rbenv exec kitchen login default-win11

# Check installed versions (should see both)
ls C:\Tomcat

# Should see:
# - apache-tomcat-9.0.113/  (old version kept)
# - apache-tomcat-9.0.120/  (new version)
# - current -> apache-tomcat-9.0.120  (symlink updated)

# Verify symlink points to new version
cmd /c dir C:\Tomcat

# Verify service is running with new version
Get-Service Tomcat9
curl http://localhost:8080

# Check Tomcat version
type C:\Tomcat\current\RELEASE-NOTES
# Should show version 9.0.120

# Exit VM
exit
```

**Step 5: Test version retention (install 11+ versions)**

If you want to test that old versions get cleaned up after 10 versions:

```bash
# Repeatedly change version and converge:
# 9.0.113 -> 9.0.115 -> 9.0.117 -> ... (11 different versions)

# After 11th version, the oldest should be removed
# Only the 10 most recent versions should remain
```

### Scenario 2: Tomcat Downgrade (9.0.120 → 9.0.113)

**Continuing from Scenario 1:**

```bash
# Edit .kitchen.yml and change back to "9.0.113"
sed -i '' 's/tomcat_version: "9.0.120"/tomcat_version: "9.0.113"/' .kitchen.yml

# Run converge
rbenv exec kitchen converge default-win11

# Login and verify
rbenv exec kitchen login default-win11

ls C:\Tomcat
# Should see:
# - apache-tomcat-9.0.113/
# - apache-tomcat-9.0.120/
# - current -> apache-tomcat-9.0.113  (symlink points back to old version)

# Verify service
Get-Service Tomcat9
curl http://localhost:8080

exit
```

### Scenario 3: Java Upgrade (21 → 17 or vice versa)

**Note**: Java upgrade testing requires updating the provision-java role in the test roles directory.

**Step 1: Install Java 21**
```bash
# In tests/playbook.yml, set jdk_version: 21
# Then converge
rbenv exec kitchen converge default-win11

# Login and check
rbenv exec kitchen login default-win11

ls C:\java
# With symlink approach:
# - jdk-21/
# - current -> jdk-21/

# Without symlink (current version):
# Just java files directly

java -version
# Should show 21.x.x

exit
```

**Step 2: Upgrade/Downgrade to Java 17**
```bash
# Edit tests/playbook.yml, change jdk_version: 21 to jdk_version: 17
# Run converge
rbenv exec kitchen converge default-win11

# Login and verify
rbenv exec kitchen login default-win11

java -version
# Should show 17.x.x

exit
```

## Cleanup

```bash
# Destroy the test VM
rbenv exec kitchen destroy default-win11

# Reset .kitchen.yml to default version
sed -i '' 's/tomcat_version: ".*"/tomcat_version: "9.0.113"/' .kitchen.yml
```

## Expected Behaviors

### Tomcat Upgrade
✅ Old version directory remains (for rollback)
✅ New version directory is created
✅ Symlink `current` points to new version
✅ Service is restarted with new version
✅ CATALINA_HOME always points to `C:/Tomcat/current`
✅ Old versions beyond retention limit (10) are removed

### Tomcat Downgrade
✅ Old version directory is reused (no re-download)
✅ Symlink `current` points back to old version
✅ Service is restarted with old version

### Java Upgrade (with symlink)
✅ Old JDK directory remains
✅ New JDK directory is created
✅ Symlink `current` points to new JDK
✅ JAVA_HOME always points to `C:/java/current`
✅ Old JDKs beyond retention limit (10) are removed

### Java Upgrade (without symlink - current behavior)
✅ Old JDK is uninstalled
✅ New JDK is installed
✅ JAVA_HOME is updated to new path
