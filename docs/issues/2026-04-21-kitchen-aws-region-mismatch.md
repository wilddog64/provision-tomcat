# Issue: Test Kitchen AWS suites ignore `Makefile` region and default to `us-east-1`

## Summary

`make test-aws-provision-tomcat` discovers AWS resources in `us-west-2`, but Test Kitchen still creates the EC2 instance in `us-east-1` because the AWS suite in `.kitchen.yml` hardcodes `region: us-east-1`.

This creates an invalid cross-region configuration where the suite tries to launch an instance in `us-east-1` using a subnet, security group, availability zone, and AMI discovered from `us-west-2`.

## What was tested

Command run by user:

```bash
make test-aws-provision-tomcat
```

Observed output:

```text
=== Checking AWS Credentials ===
AWS Credentials are valid.
AWS_SUBNET_ID=subnet-0c56bee2aa62163a8
AWS_SECURITY_GROUP_ID=sg-06398afdf210e4f58
AWS_SECURITY_GROUP_IDS=["sg-06398afdf210e4f58"]
AWS_AMI_ID=ami-0b15fb428fbc526fe
AWS_AZ=us-west-2a
AWS_REGION=us-west-2
=== Detecting AWS Environment ===
Using Account: 761200394237
Using Region: us-west-2
-----> Starting Test Kitchen (v3.1.1)
-----> Destroying <default-aws-minimal-win-disk>...
       Finished destroying <default-aws-minimal-win-disk> (0m0.00s).
-----> Test Kitchen is finished. (0m1.04s)
-----> Starting Test Kitchen (v3.1.1)
-----> Creating <default-aws-minimal-win-disk>...
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Failed to complete #create action: [The image id '[ami-0b15fb428fbc526fe]' does not exist in the specified region us-east-1. Please check this AMI is available in this region.] on default-aws-minimal-win-disk
>>>>>> ----------------------
>>>>>> Please see .kitchen/logs/kitchen.log for more details
>>>>>> Also try running `kitchen diagnose --all` for configuration
```

## Root cause

The AWS suites in `.kitchen.yml` define a fixed region:

```yaml
driver:
  name: ec2
  region: us-east-1
```

At the same time, the suite reads `AWS_AZ`, `AWS_SUBNET_ID`, `AWS_SECURITY_GROUP_IDS`, and `AWS_AMI_ID` from environment variables populated for `us-west-2`.

The `Makefile` already computes an `AWS_REGION` value and allows environment override, but `.kitchen.yml` does not consume that value.

## Fix

- Replace the hardcoded Kitchen AWS region with `ENV.fetch('AWS_REGION', 'us-east-1')`.
- Export `AWS_REGION` from `Makefile` so Test Kitchen subprocesses inherit the resolved value.

## Recommended follow-up

- Consider exporting the full discovered AWS variable set from `Makefile` or passing them explicitly into the `kitchen` commands to reduce shell/session drift.
