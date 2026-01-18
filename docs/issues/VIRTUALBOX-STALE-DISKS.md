# VirtualBox Stale Disk Registry Issue

## Problem

When using VirtualBox with Vagrant to create secondary disks (e.g., D: drive), you may encounter this error:

```
VBoxManage: error: Failed to create medium
VBoxManage: error: Could not create the medium storage unit '/path/to/.vagrant/data_disk.vdi'.
VBoxManage: error: VDI: cannot create image '/path/to/.vagrant/data_disk.vdi' (VERR_ALREADY_EXISTS)
```

This happens because VirtualBox maintains an internal registry of all disks, separate from the actual files on disk. When a disk file is deleted (manually or by a failed operation), VirtualBox may still have a stale entry in its registry, preventing creation of a new disk at the same path.

## Symptoms

- `vagrant up` fails with `VERR_ALREADY_EXISTS` error
- `make vagrant-build-baseline-minimal` fails
- The `.vdi` file doesn't exist on disk, but VirtualBox thinks it does

## Solution

### Automatic Cleanup (Recommended)

The following Make targets automatically clean up stale disks before running:

- `make vagrant-up`
- `make vagrant-build-baseline`
- `make vagrant-build-baseline-minimal`

### Manual Cleanup

Run the cleanup script directly:

```bash
# Dry run - see what would be cleaned up
./bin/vbox-cleanup-disks.sh --dry-run

# Actually clean up stale disks
./bin/vbox-cleanup-disks.sh

# Or via Make
make vbox-cleanup-disks
```

### Manual VirtualBox Commands

If the script doesn't work (e.g., disk is attached to a running VM), use these commands:

```bash
# List all registered disks
VBoxManage list hdds

# Find the UUID of the stale disk, then close it
VBoxManage closemedium disk <UUID> --delete

# If the disk is attached to a VM, detach it first
VBoxManage storageattach "<VM-NAME>" --storagectl "SATA Controller" --port 1 --device 0 --medium none

# Then close the medium
VBoxManage closemedium disk <UUID> --delete
```

## Prevention

The Vagrantfile includes automatic cleanup logic that:

1. Checks if the disk file exists on disk
2. If not, queries VirtualBox registry for stale entries
3. Removes any stale registration before creating the new disk

This handles most cases automatically. Edge cases (like a running VM with the disk attached) still require manual intervention.

## Related Files

- `bin/vbox-cleanup-disks.sh` - Cleanup script
- `Vagrantfile` - Contains automatic cleanup logic in the disk creation block

## See Also

- [Development Environment Setup](../DEVELOPMENT-SETUP.md)
- [Test Kitchen Guide](../TEST-KITCHEN.md)
