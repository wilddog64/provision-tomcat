# Rocky Linux ARM64 Vagrant Box Plan (Apple Silicon)

## Goal
Build a “rockylinux/9” ARM64 box that works with VirtualBox on Apple Silicon and register it locally for Vagrant/Kitchen.

## Prerequisites
- macOS on M-series (
- Homebrew packages: `packer`, `qemu`, `wget`, `coreutils`
- VirtualBox 7.0+
- Vagrant 2.4+

## Steps Overview
1. Use Packer with the `qemu` builder (HVF acceleration) to install the Rocky Linux 9 aarch64 Minimal ISO.
2. Automate install with a kickstart file (create vagrant:vagrant, enable sshd, set up sudo access).
3. After Packer boots the VM, run provisioners to install VirtualBox Guest Additions (ARM version), cloud-init style tweaks, and clean up.
4. Convert the resulting disk/VM into a VirtualBox VM and package it via `vagrant package`.
5. `vagrant box add rockylinux/9-arm64 boxes/rockylinux9-arm64.box`.
6. Update `.kitchen.yml` or `Vagrantfile` to point to the new box for the Rockylinux platform.

Detailed instructions with commands pending proof-of-concept.
