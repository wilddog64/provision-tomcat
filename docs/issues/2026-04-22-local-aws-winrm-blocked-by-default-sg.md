# Local AWS WinRM blocked by fallback default security group

## What was tested / attempted

- Ran `make sync-aws` locally to refresh AWS credentials into GitHub Actions secrets.
- Ran `make test-aws-provision-tomcat` locally from `aws-dev`.
- Inspected the local AWS discovery path in `Makefile` and the CI workflow in `.github/workflows/ci.yml`.
- Queried the discovered AWS security group in `us-west-2`.

## Actual output

User terminal output before the local test:

```text
Syncing AWS credentials to GitHub Secrets...
direnv: ([/opt/homebrew/bin/direnv export zsh]) is taking a while to execute. Use CTRL-C to give up.
✓ Set Actions secret AWS_ACCESS_KEY_ID for wilddog64/provision-tomcat
✓ Set Actions secret AWS_SECRET_ACCESS_KEY for wilddog64/provision-tomcat
------------------------------------------------------------
Successfully updated GitHub Secrets!
Your GitHub Actions can now access the current AGC sandbox.
------------------------------------------------------------
direnv: export +AWS_PROFILE +VIRTUAL_ENV ~PATH

╭─   ~/sr/g/p/an/provision-tomcat on   aws-dev ⇡3 *1
╰─❯ make test-aws-provision-tomcat
```

Local AWS discovery output:

```text
=== Checking AWS Credentials ===
AWS Credentials are valid.
AWS_SUBNET_ID=subnet-05669d2be3e64c533
AWS_SECURITY_GROUP_ID=sg-0d89881a3d8fd4fdb
AWS_SECURITY_GROUP_IDS=["sg-0d89881a3d8fd4fdb"]
AWS_AMI_ID=ami-0b15fb428fbc526fe
AWS_AZ=us-west-2a
AWS_REGION=us-west-2
```

Security group inspection output:

```json
{
    "SecurityGroups": [
        {
            "GroupId": "sg-0d89881a3d8fd4fdb",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "UserIdGroupPairs": [],
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": []
                }
            ],
            "VpcId": "vpc-0600fc941cadaace0",
            "SecurityGroupArn": "arn:aws:ec2:us-west-2:339712884159:security-group/sg-0d89881a3d8fd4fdb",
            "OwnerId": "339712884159",
            "GroupName": "default",
            "Description": "default VPC security group",
            "IpPermissions": [
                {
                    "IpProtocol": "-1",
                    "UserIdGroupPairs": [
                        {
                            "UserId": "339712884159",
                            "GroupId": "sg-0d89881a3d8fd4fdb"
                        }
                    ],
                    "IpRanges": [],
                    "Ipv6Ranges": [],
                    "PrefixListIds": []
                }
            ]
        }
    ]
}
```

Tagged test security group lookup in `us-west-2` returned no rows.

## Root cause

- Local `make test-aws-provision-tomcat` does not authorize inbound `5985`, `8080`, or `9080` before waiting for WinRM.
- CI does authorize those ports first in `.github/workflows/ci.yml`.
- In `us-west-2`, discovery currently falls back to the VPC `default` security group because no tagged test security group exists.
- That default security group only allows self-referenced inbound traffic, so WinRM from the developer laptop cannot reach the instance.
- `make sync-aws` only refreshes GitHub Actions secrets; it does not change local security group ingress.

## Recommended follow-up

- Add a local pre-test step that mirrors CI and authorizes `5985`, `8080`, and `9080` for the caller's public IP.
- Add matching cleanup to revoke those rules after the local test.
- Consider creating or requiring a tagged test security group in `us-west-2` so discovery does not fall back to `default`.
- Keep the implementation separate from this documentation-only commit.

## Status update

- Implemented in `Makefile`: local `test-aws-provision-tomcat` and `test-aws-upgrade-candidate` now authorize ingress for the caller IP before create/wait, and revoke it during shell exit cleanup.
- Cleanup now also destroys the Kitchen instance on failure unless `KEEP_AWS_VM` is set, matching the intent of the CI workflow more closely.
- Live AWS verification is still pending.
