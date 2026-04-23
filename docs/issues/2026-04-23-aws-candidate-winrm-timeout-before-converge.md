# AWS candidate test timed out waiting for WinRM before converge

## What was tested / attempted

- Ran the AWS candidate upgrade path and failed before Ansible converge began.
- The run reached Test Kitchen instance creation, then waited for WinRM on port `5985`.
- The target exited at the pre-converge wait loop and then attempted cleanup.

## Actual output

```text
Timeout waiting for WinRM
=== Cleaning up... ===
-----> Starting Test Kitchen (v3.1.1)
/Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/vendor/bundle/ruby/4.0.0/gems/winrm-2.3.9/lib/winrm/psrp/fragment.rb:35: warning: redefining 'object_id' may cause serious problems
/Users/cliang/src/gitrepo/personal/ansible/provision-tomcat/vendor/bundle/ruby/4.0.0/gems/winrm-2.3.9/lib/winrm/psrp/message_fragmenter.rb:29: warning: redefining 'object_id' may cause serious problems
-----> Destroying <upgrade-candidate-aws-disk-aws-minimal-win-disk>...
$$$$$$ Received The instance ID 'i-0fc675435f066fef3' does not exist, instance was probably already destroyed. Ignoring
       EC2 instance <i-0fc675435f066fef3> destroyed.
       Removing automatic key pair kitchen-upgradecandidateawsdiskawsminimalwindisk-cliang-m4airlocal-2026-04-23T03:44:50Z-st4bh5hv
       Finished destroying <upgrade-candidate-aws-disk-aws-minimal-win-disk> (0m1.10s).
-----> Test Kitchen is finished. (0m2.02s)
Revoking ingress for runner IP: 216.9.30.23
make: *** [test-aws-upgrade-candidate] Error 1
```

## Root cause

- Not yet confirmed.
- The failure occurs before Ansible converge or candidate verification, so this does not currently point to Tomcat upgrade logic.
- The cleanup phase reports that EC2 instance `i-0fc675435f066fef3` no longer exists, which suggests the instance was already terminated or otherwise unavailable by the time cleanup ran.
- The current wait loop only probes `host:5985` with `nc` and does not record EC2 instance state, instance status checks, or refreshed public endpoint data during the wait.

## Recommended follow-up

- Inspect the failed AWS create path with instance-state-aware diagnostics before changing upgrade logic.
- Capture EC2 instance state, system status, and instance status while waiting for WinRM.
- Confirm whether the discovered AMI, subnet, and security group still produce a Windows host that reaches WinRM consistently.
- Improve the pre-converge wait diagnostics so future failures distinguish between:
  - slow WinRM startup,
  - blocked ingress,
  - stale hostname/IP data, and
  - instance termination during boot.

## Resolution status

- Implemented an instance-aware AWS WinRM wait path in `Makefile`.
- The wait loop now refreshes public endpoint data from EC2, surfaces instance/system status during the wait, and fails early if the instance enters a terminal state before WinRM is reachable.
- Live AWS re-validation is still pending.

## Related

- Local WinRM ingress parity: `docs/issues/2026-04-22-local-aws-winrm-blocked-by-default-sg.md`
- AWS latest-version live findings: `docs/issues/2026-04-22-aws-candidate-latest-version-live-test.md`
- Historical promotion helper failure: `docs/issues/2026-04-22-aws-candidate-promotion-helper-error-127.md`
