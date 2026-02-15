# WinRM Port Forwarding with Vagrant

## Problem

Ansible fails to connect to Windows VM with WinRM errors like:

```
fatal: [baseline-win11-baseline]: UNREACHABLE! => {
  "msg": "basic: HTTPConnectionPool(host='127.0.0.1', port=5985): Max retries exceeded..."
}
```

Or:

```
fatal: [baseline-win11-baseline]: UNREACHABLE! => {
  "msg": "basic: HTTPConnectionPool(host='baseline-win11-baseline', port=5986)...
   Failed to establish a new connection: [Errno 8] nodename nor servname provided"
}
```

## Root Cause

Vagrant's WinRM communicator automatically forwards the guest WinRM port with a **50000 offset**:

| Guest Port | Host Port | Protocol |
|------------|-----------|----------|
| 5985 | **55985** | WinRM HTTP |
| 5986 | **55986** | WinRM HTTPS |

This is visible in Vagrant output:

```
==> default: Forwarding ports...
    default: 5985 (guest) => 55985 (host) (adapter 1)
    default: 5986 (guest) => 55986 (host) (adapter 1)
```

Kitchen's WinRM transport handles this correctly (reads from Vagrant state), but **Ansible extra_vars may override with wrong values**.

## Solution

### For kitchen-ansible-push

Configure the correct host and port in `.kitchen.yml` extra_vars:

```yaml
provisioner:
  name: ansible_push
  extra_vars:
    ansible_connection: winrm
    ansible_host: 127.0.0.1      # Always localhost for port forwarding
    ansible_port: 55985          # Host port (5985 + 50000)
    ansible_winrm_transport: basic
    ansible_winrm_scheme: http
    ansible_winrm_server_cert_validation: ignore
    ansible_user: vagrant
    ansible_password: vagrant
```

### Key Points

1. **ansible_host must be `127.0.0.1`** - Not the inventory hostname
2. **ansible_port must be `55985`** - The forwarded host port, not guest port 5985
3. **Kitchen transport vs Ansible** - Kitchen's transport config (`transport.port: 5985`) is for Kitchen's internal WinRM connection. Ansible needs the forwarded port.

### Verification

Check the Kitchen state file to see the actual port:

```bash
cat .kitchen/upgrade-baseline-win11-baseline.yml
```

Output:
```yaml
---
hostname: 127.0.0.1
port: '55985'
username: vagrant
password: vagrant
```

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| `ansible_port: 5985` | Connection refused | Use `55985` |
| No `ansible_host` | DNS lookup failure for inventory hostname | Add `ansible_host: 127.0.0.1` |
| `ansible_port: 5986` | Connection refused (HTTPS not configured) | Use `55985` for HTTP |

## For GitHub Actions CI

In the workflow, patch `.kitchen.yml` dynamically:

```yaml
- name: Run Test
  run: |
    python3 - <<'EOF'
    import re
    with open('.kitchen.yml', 'r') as f: content = f.read()
    # Ensure correct port
    content = re.sub(r'ansible_port:.*', 'ansible_port: 55985', content)
    with open('.kitchen.yml', 'w') as f: f.write(content)
    EOF
```

## Related

- [pywinrm urllib3 Compatibility](pywinrm-urllib3-compatibility.md)
- [Vagrant Bundler Conflict](VAGRANT-BUNDLER-CONFLICT.md)
