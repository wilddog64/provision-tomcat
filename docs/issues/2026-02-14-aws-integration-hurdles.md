# AWS Integration Hurdles and Resolutions (2026-02-14)

> **Related**: See `docs/plans/archive/AWS-SANDBOX-STABILIZATION.md` for the broader stabilization plan.

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

## 5. AZ Physical Constraints (us-east-1e)
- **Issue**: Attempting to use `t3.medium` instances in the `us-east-1e` availability zone resulted in creation failures.
- **Error**: `Your requested instance type (t3.medium Windows) is not supported in your requested Availability Zone (us-east-1e).`
- **Root Cause**: `us-east-1e` is a legacy AZ that does not support newer Nitro-based instance types.
- **Resolution**: Switched AWS platforms to use the `t2` family (e.g., `t2.medium`, `t2.micro`) which is physically supported in that zone.

## 6. Sandbox Session Expiration
- **Issue**: AWS credentials expired mid-workflow, leading to "UnauthorizedOperation" errors.
- **Resolution**: User manually extended the sandbox session. Documented the need for periodic credential refreshes via `make sync-aws` during long-running integration tasks.
