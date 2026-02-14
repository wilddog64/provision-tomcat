# AWS Integration Hurdles and Resolutions (2026-02-14)

## 1. WinRM Transport Conflict
- **Issue**: Setting `winrm_transport: :basic` in `.kitchen.yml` (parity with Azure) caused the `#create` action to fail.
- **Error**: `Invalid transport 'basic' specified, expected: ssl, negotiate, kerberos, plaintext.`
- **Root Cause**: The `kitchen-ec2` driver has a restricted set of allowed transports compared to other drivers.
- **Resolution**: Reverted to `negotiate` for AWS platforms.

## 2. Dynamic Hostname Resolution
- **Issue**: Ansible attempted to connect to the internal Kitchen instance name (`aws-minimal-win`) instead of the actual EC2 public DNS, resulting in `UNREACHABLE`.
- **Error**: `Failed to resolve 'aws-minimal-win' ([Errno 8] nodename nor servname provided, or not known)`
- **Resolution**: 
    - Updated `Makefile` to capture the dynamic IP from Kitchen and export it as `ANSIBLE_HOST_OVERRIDE`.
    - Updated `.kitchen.yml` to use `<%= ENV['ANSIBLE_HOST_OVERRIDE'] %>` for the `ansible_host` variable.

## 3. Active Directory Service Account Resolution
- **Issue**: Security tasks in `windows-base` attempted to apply ACLs for domain accounts (`PACIFIC\svclabbuild`) that do not exist in the standalone AWS sandbox.
- **Error**: `account_name PACIFIC\svclabbuild is not a valid account, cannot get SID.`
- **Resolution**: Updated `.kitchen.yml` to override `security_service_account` to `""` and `security_jenkins_accounts` to `[]` for AWS suites, triggering conditional skips in the role.

## 4. Ansible Collection Resolution
- **Issue**: The `community.windows.win_unzip` module could not be found during execution, even after being added to `requirements.yml`.
- **Error**: `ERROR! couldn't resolve module/action 'community.windows.win_unzip'.`
- **Root Cause**: Collections installed via `make deps` (local path) were not being correctly picked up by the `ansible_push` provisioner in the CI environment.
- **Resolution**: 
    - Updated `ci.yml` to explicitly run `ansible-galaxy collection install -r requirements.yml` to ensure default path installation.
    - Verified `requirements.yml` contained the `collections` key.

## 5. CI Portability
- **Issue**: Runner-specific paths for roles prevented the pipeline from running on different hardware.
- **Resolution**: Finalized the transition to `actions/checkout` with `ssh-key` (via GitHub Secrets) for all private roles, removing all local symlink dependencies in CI.
