# Direnv loaded a broken parent command and the AWS targets assumed `ansible` was already on PATH

## What was tested / attempted

- Investigated why `ansible` was not found after WinRM became reachable during the AWS candidate path.
- Inspected `direnv` state, the repo `.envrc`, the parent `.envrc`, and the `Makefile` Ansible call sites.
- Verified `direnv exec .` could resolve both `ansible` and `ansible-playbook` from the shared Python virtualenv even when the current shell had no RC loaded.

## Actual output

Observed before the fix:

```text
direnv: loading ~/src/gitrepo/personal/ansible/provision-tomcat/.envrc
direnv: loading ~/src/gitrepo/personal/ansible/.envrc
bash: /Users/cliang/.local/bin/sync-claude /Users/cliang/.claude: No such file or directory
direnv: export +AWS_PROFILE +VIRTUAL_ENV ~PATH
```

And later during the AWS target:

```text
=== Verifying Ansible Connectivity (win_ping) ===
/bin/bash: ansible: command not found
```

## Root cause

- The parent `../.envrc` invoked `sync-claude` with a single, incorrectly quoted argument string, producing a noisy but non-fatal shell error on every `direnv` load.
- The `Makefile` directly invoked `ansible` / `ansible-playbook` and assumed the caller shell had already imported the `direnv` environment.
- In shells where the `direnv` hook had not populated the environment yet, the AWS targets could reach WinRM successfully and still fail on the local control node because `ansible` was not on `PATH`.

## Resolution status

- Fixed the local parent `.envrc` invocation so `sync-claude` receives separate script and argument values.
- Updated `Makefile` to fall back to `direnv exec . ansible` / `direnv exec . ansible-playbook` when those commands are not already on `PATH`.
- Confirmed locally that `direnv exec .` resolves both Ansible commands from the shared virtualenv without the earlier shell error.

## Related

- AWS WinRM timeout blocker: `docs/issues/2026-04-23-aws-candidate-winrm-timeout-before-converge.md`
