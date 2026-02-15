# pywinrm and urllib3 Compatibility Issue

## Problem

When running Ansible playbooks against Windows hosts using WinRM, you may encounter one of these errors:

### Error 1: Module not found
```
fatal: [default]: FAILED! => {"msg": "winrm or requests is not installed: No module named 'winrm'"}
```

### Error 2: NoneType attribute error
```
An exception occurred during task execution. To see the full traceback, use -vvv.
The error was: AttributeError: 'NoneType' object has no attribute 'group'
fatal: [default]: FAILED! => {"changed": false}
```

## Root Cause

### Error 1
The `vagrant-winrm` Vagrant plugin (Ruby) is installed, but Ansible requires the Python `pywinrm` package. These are two separate dependencies:

| Package | Language | Purpose |
|---------|----------|---------|
| `vagrant-winrm` | Ruby | Vagrant plugin for WinRM communication with VMs |
| `pywinrm` | Python | Ansible's WinRM connection plugin dependency |

### Error 2
The `pywinrm` package has compatibility issues with `urllib3` version 2.x. The NTLM authentication module fails to parse responses correctly, resulting in the `'NoneType' object has no attribute 'group'` error.

## Solution

Install `pywinrm` with `urllib3` pinned to version 1.x:

```bash
pip install pywinrm "urllib3<2"
```

Or use the project's requirements.txt which has the correct pins:

```bash
pip install -r requirements.txt
```

### requirements.txt

Ensure your `requirements.txt` includes:

```
pywinrm
requests-ntlm
urllib3<2
ansible
```

## Verification

After installation, verify the packages are correctly installed:

```bash
pip show pywinrm urllib3
```

Expected output should show:
- `pywinrm` installed
- `urllib3` version 1.x (e.g., 1.26.18)

## References

- [pywinrm GitHub Issues](https://github.com/diyan/pywinrm/issues)
- [Ansible WinRM Connection Plugin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/winrm_connection.html)
