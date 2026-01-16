# Rocky Linux ARM64 Vagrant Box Plan (Apple Silicon)

## Goal
Build a “rockylinux/9” ARM64 box that works with VirtualBox on Apple Silicon and register it locally for Vagrant/Kitchen.

## Prerequisites
- macOS on M-series (
- Homebrew packages: `packer`, `qemu`, `wget`, `coreutils`
- VirtualBox 7.0+
- Vagrant 2.4+

## Steps Overview
1. Use Packer (`packer/rockylinux9-arm64.pkr.hcl`) with the `qemu` builder (HVF) to install the Rocky Linux 9 aarch64 Minimal ISO.
2. The kickstart in `packer/http/kickstart.cfg` creates the `vagrant` user, injects the insecure SSH key, enables sudo, and configures DHCP.
3. A shell provisioner applies basic tweaks (installs sudo/python/cloud-utils, disables firewalld, cleans caches).
4. The Vagrant post-processor emits `boxes/rockylinux9-arm64.box` directly.
5. Register the box locally: `vagrant box add rockylinux/9-arm64 boxes/rockylinux9-arm64.box`.
6. Update `.kitchen.yml` / `Vagrantfile` to refer to `rockylinux/9-arm64` for the Rocky platform.

## Usage

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/packer qemu wget coreutils

cd packer
packer init rockylinux9-arm64.pkr.hcl
PACKER_LOG=1 packer build rockylinux9-arm64.pkr.hcl
cd ..

vagrant box add rockylinux/9-arm64 boxes/rockylinux9-arm64.box
```

You can now reference the new box in `.kitchen.yml` or any Vagrantfile on Apple Silicon.
