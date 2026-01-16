# Rocky Linux 9 ARM64 Vagrant Box

VirtualBox on Apple Silicon can only run ARM guest OSes, but the official Rocky/Alma boxes on Vagrant Cloud only ship x86_64 builds. To get a Rocky 9 guest running under VirtualBox on arm64 hardware you need to build your own box. Use Packer with an HVF-accelerated QEMU build to install the aarch64 ISO and package it as a VirtualBox box.

## Requirements

- macOS on Apple Silicon
- VirtualBox 7.0+
- Packer >= 1.9
- QEMU installed (`brew install qemu`)

## Quick steps

1. Build the base VM via Packer (see `packer/rockylinux9-arm64.json`).
2. Convert the output into a Vagrant box (`vagrant package`).
3. Add it to Vagrant (`vagrant box add rockylinux/9-arm64 <path>`).

Once added, update `.kitchen.yml` to point your Rockylinux platform at the new box name.
