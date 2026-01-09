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
| `tomcat_force_install` | `false` | When true, add `--force` to the Chocolatey call (service is stopped regardless). |
| `tomcat_choco_args` | `[]` | Additional Chocolatey arguments (list). |

The role always stops the Tomcat service (if present) before running Chocolatey and starts it afterward. Set `tomcat_force_install: true` (optionally with extra `tomcat_choco_args`) when you want to force a reinstall/upgrade; otherwise Chocolatey will skip if the package is already present.

## Tasks Overview

`tasks/install-Windows-tomcat.yml` executes a single block:

1. `win_chocolatey` installs Tomcat with the configured package name/args.
2. Registers `tomcat_installation` so downstream roles can inspect change status.

The block only runs when `ansible_facts.os_family == 'Windows'`.

## Example Playbook

```yaml
---
- hosts: windows
  gather_facts: yes
  roles:
    - windows-base
    - provision-tomcat
```

## Local Testing

Use the repo’s Make targets (which wrap Test Kitchen + Vagrant):

```
make test-win11
# On Windows PowerShell
set KITCHEN_YAML=.kitchen-win.yml
make test-win11
```

## License

Apache-2.0 (see `LICENSE`).
