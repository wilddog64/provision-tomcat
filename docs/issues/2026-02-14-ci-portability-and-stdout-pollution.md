# CI Portability and Stdout Pollution Issues (2026-02-14)

## 1. Portability Issue: Hardcoded Absolute Path in `.kitchen.yml`

### Problem
The `.kitchen.yml` file contained a hardcoded absolute path for a Vagrantfile override:
```yaml
vagrantfiles:
  - /Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/vagrant/Vagrantfile-disk.rb
```
This made the configuration fragile and non-portable, as it relied on a specific directory structure on a specific user's machine. It would fail on any other runner or developer machine.

### Solution
Replaced the absolute path with a relative ERB expression that resolves based on the location of the `.kitchen.yml` file:
```yaml
vagrantfiles:
  - <%= File.join(File.dirname(__FILE__), 'vagrant', 'Vagrantfile-disk.rb') %>
```
This ensures the configuration is portable across all environments, adhering to the **Zero-Touch Portability** mandate.

## 2. CI Failure: Stdout Pollution in `make discover-aws-resources`

### Problem
The `make discover-aws-resources` target was being called in CI via `eval "$(make discover-aws-resources --silent)"`. However, the `check-aws-credentials` prerequisite was printing diagnostic messages like `=== Checking AWS Credentials ===` to `stdout`.

Because these messages were not valid shell export commands, the `eval` command failed with:
`error: Process completed with exit code 127.`
`Discover Dynamic AWS Resources: /Users/cliang/tomcat-runner/_work/_temp/8cf853c8-3f97-4978-9aef-b57eeb1d31e6.sh: line 2: ===: command not found`

### Solution
Updated the `Makefile` to redirect all diagnostic and informational messages in the `check-aws-credentials` and `discover-aws-resources` targets to `stderr` (`>&2`).

```makefile
check-aws-credentials:
    @echo "=== Checking AWS Credentials ===" >&2
    @if aws sts get-caller-identity > /dev/null 2>&1; then 
        echo "AWS Credentials are valid." >&2; 
    ...
```

This ensures that only the intended shell export variables are sent to `stdout`, allowing the `eval` command in CI to function correctly while still providing visibility into the credential check process via the CI logs (which capture both stdout and stderr).

## Related Documents
- `memory-bank/activeContext.md`
- `Makefile`
- `.kitchen.yml`
- `.github/workflows/ci.yml`
