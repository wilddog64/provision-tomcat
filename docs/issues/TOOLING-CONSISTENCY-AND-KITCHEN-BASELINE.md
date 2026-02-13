# Tooling Consistency and Kitchen Baseline Notes

This note explains a small set of repository changes made to reduce local/CI drift and to avoid accidental execution of inactive Kitchen platform config.

## 1) Makefile now resolves Ansible tools from a consistent location

### What changed

- `Makefile` now derives `ansible`, `ansible-playbook`, and `ansible-galaxy` from the same directory as `ansible-lint` when `ansible-lint` is present.
- `lint`, `syntax`, and `deps` targets were updated to use these resolved binaries.

### Why

On developer machines and CI runners, `ansible-lint` may come from one Python environment while `ansible-playbook`/`ansible-galaxy` come from another. That can produce hard-to-debug failures due to version mismatches (especially `ansible-core` compatibility and plugin/module behavior).

Resolving all commands from one toolchain path makes checks more deterministic.

## 2) ansible-lint excludes Kitchen config files

### What changed

- Added `.ansible-lint`:
  - excludes `.kitchen.yml`
  - excludes `.kitchen-win.yml`

### Why

Kitchen files are not plain Ansible playbooks/inventories and include ERB templating (`<%= ... %>`). Linting them with `ansible-lint` can trigger false positives or parsing errors unrelated to playbook quality.

Excluding them keeps lint focused on real Ansible content.

## 3) `win11-baseline` block in `.kitchen.yml` is fully commented

### What changed

- The previously partially active `win11-baseline` block is now fully commented out.

### Why

This preserves the historical config for reference while clearly disabling that platform from active test flows. It avoids accidental use of a baseline definition that is currently not intended to run.

## 4) CI workflow newline-only normalization

### What changed

- `.github/workflows/ci.yml` now ends with a newline.

### Why

No behavioral change. This is standard formatting hygiene and avoids EOF newline warnings in some tooling.

## 5) Vagrant Box Caching and VirtualBox Stability in CI



### What changed



- Modified `bin/vagrant-wrapper` to preserve the `HOME` environment variable.

- Explicitly set `VAGRANT_HOME: /Users/cliang/.vagrant.d` in `.github/workflows/ci.yml`.

- Enhanced `bin/vbox-cleanup-disks` to aggressively power off and unregister any stale VMs starting with `kitchen-` or `windows-11-`.



### Why



1.  **Vagrant Box Re-downloads**: Every CI run was downloading the Windows 11 box from the internet because `vagrant-wrapper` used `env -i`, which stripped the `HOME` variable. This prevented Vagrant from finding the persistent box cache at `~/.vagrant.d`.

2.  **Appliance Import Failures**: `kitchen create` would frequently fail with `VERR_ALREADY_EXISTS` because stale VM registrations or VMDK files remained from previous failed or interrupted runs. Aggressive cleanup ensures a blank slate for every integration test run.
